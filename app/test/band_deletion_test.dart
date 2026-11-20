import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Deleting bands in the app (ADR-0044): who may, and what devices learn.
void main() {
  late AppDatabase db;
  late FakeSyncBackend backend;
  late BandService service;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeSyncBackend(user: _ann);
    service = BandService(db, backend);
    backend.addOrganization('o1', 'School', admin: _ann);
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addBand('b2', 'Jazz', admin: _ann, organizationId: 'o1');
    backend.addMember('b1', _bob, BandRole.admin);
  });
  tearDown(() => db.close());

  test('only organization admins may delete a band', () async {
    await service.refresh();
    final ann = await service.watchBands('ann').first;
    final bob = await service.watchBands('bob').first;
    expect(ann.firstWhere((b) => b.id == 'b1').canDeleteBand, isTrue);
    // Bob leads the band but is no organization admin.
    final rock = bob.firstWhere((b) => b.id == 'b1');
    expect(rock.canManageBand, isTrue);
    expect(rock.canDeleteBand, isFalse);
    expect(ann.first.canDeleteBand, isFalse, reason: 'the local library');
  });

  test('deleting hides the band, restoring brings it back', () async {
    await service.refresh();
    await service.deleteBand('b2');
    final names = [
      for (final b in await service.watchBands('ann').first) b.name,
    ];
    expect(names, isNot(contains('Jazz')));
    final trash = await service.deletedBands('o1');
    expect(trash.single.name, 'Jazz');

    await service.restoreBand('b2');
    expect([
      for (final b in await service.watchBands('ann').first) b.name,
    ], contains('Jazz'));
    expect(await service.deletedBands('o1'), isEmpty);
  });

  test('refresh reports bands that are gone, once', () async {
    expect(await service.refresh(), isEmpty);
    backend.bands['b2']!.deletedAt = DateTime.now().toUtc();
    backend.bands['b1']!.deletedAt = DateTime.now().toUtc();
    expect(await service.refresh(), ['Jazz', 'Rock']);
    expect(await service.refresh(), isEmpty);
  });

  test('a sync tells which bands are gone', () async {
    final engine = SyncEngine(db, backend, service);
    expect((await engine.sync()).goneBands, isEmpty);
    backend.bands['b2']!.deletedAt = DateTime.now().toUtc();
    expect((await engine.sync()).goneBands, ['Jazz']);
    expect((await engine.sync()).goneBands, isEmpty);
  });
}
