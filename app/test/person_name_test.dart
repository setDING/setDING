import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/lineup.dart';
import 'package:setding/data/person_name.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// First name, last name and nickname of people (ADR-0062, #1039).
void main() {
  const andi = PersonName(
    firstName: 'Andreas',
    lastName: 'Boss',
    nickname: 'Andi',
  );
  const anna = PersonName(firstName: 'Anna', lastName: 'Zoller');
  const legacy = PersonName(fallback: 'Bob');

  test('every format, with fallbacks', () {
    expect(
      [for (final f in NameFormat.values) andi.format(f)],
      ['Andi', 'Andreas Boss', 'Boss Andreas', 'Andreas Boss (Andi)'],
    );
    // Without a nickname every format shows the full name.
    expect(
      [for (final f in NameFormat.values) anna.format(f)],
      ['Anna Zoller', 'Anna Zoller', 'Zoller Anna', 'Anna Zoller'],
    );
    // Older servers or accounts before the split: the single name.
    expect({for (final f in NameFormat.values) legacy.format(f)}, {'Bob'});
    expect(
      const PersonName(nickname: 'Cleo').format(NameFormat.lastFirst),
      'Cleo',
    );
    expect(const PersonName().isEmpty, isTrue);
    expect(
      personLabel(const PersonName(), NameFormat.nickname, email: 'x@y.test'),
      'x@y.test',
    );
  });

  test('search matches first name, last name and nickname', () {
    for (final q in ['andi', 'Andreas', 'boss', 'andreas boss', 'BOSS andi']) {
      expect(andi.matches(q), isTrue, reason: q);
    }
    expect(andi.matches('zoller'), isFalse);
    expect(andi.matches(''), isTrue);
    expect(legacy.matches('bo'), isTrue);
  });

  test('last name first sorts by last name', () {
    final people = [
      andi,
      anna,
      const PersonName(firstName: 'Zoe', lastName: 'Amrein'),
    ];
    List<String> sorted(NameFormat f) => [
      for (final p in sortedPeople(
        people,
        f,
        role: (_) => '',
        person: (p) => p,
      ))
        p.format(f),
    ];
    expect(sorted(NameFormat.firstLast), [
      'Andreas Boss',
      'Anna Zoller',
      'Zoe Amrein',
    ]);
    expect(sorted(NameFormat.lastFirst), [
      'Amrein Zoe',
      'Boss Andreas',
      'Zoller Anna',
    ]);
  });

  test(
    'an account lacks a full name only when the server knows the fields',
    () {
      const old = AuthUser(id: 'a', email: 'a@b.test', name: 'Ann');
      expect(old.needsFullName, isFalse);
      const migrated = AuthUser(
        id: 'a',
        email: 'a@b.test',
        name: 'Ann',
        firstName: '',
        lastName: '',
        nickname: 'Ann',
      );
      expect(migrated.needsFullName, isTrue);
      const complete = AuthUser(
        id: 'a',
        email: 'a@b.test',
        name: 'Ann',
        firstName: 'Ann',
        lastName: 'Muster',
      );
      expect(complete.needsFullName, isFalse);
    },
  );

  testWidgets('an account without a full name is asked for it once signed '
      'in and cannot skip it', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en'},
      user: const AuthUser(
        id: 'u1',
        email: 'ann@example.test',
        name: 'Ann',
        firstName: '',
        lastName: '',
        nickname: 'Ann',
      ),
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Add your full name'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    // Not dismissed by going back.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Add your full name'), findsOneWidget);
    // The nickname is filled in already.
    expect(find.widgetWithText(TextFormField, 'Ann'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('account-first-name')), 'Ann');
    await tester.tap(find.byKey(const Key('account-name-save')));
    await tester.pumpAndSettle();
    expect(find.text('Required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('account-last-name')),
      'Muster',
    );
    await tester.tap(find.byKey(const Key('account-name-save')));
    await tester.pumpAndSettle();
    expect(find.text('Add your full name'), findsNothing);
    expect(app.backend.user!.needsFullName, isFalse);
    expect(app.backend.user!.name, 'Ann');
    await app.dispose(tester);
  });

  group('shown names follow the setting', () {
    const ann = AuthUser(
      id: 'ann',
      email: 'ann@example.test',
      name: 'Andi',
      firstName: 'Ann',
      lastName: 'Zoller',
      nickname: 'Andi',
    );
    const bob = AuthUser(
      id: 'bob',
      email: 'bob@example.test',
      name: 'Bob Amrein',
      firstName: 'Bob',
      lastName: 'Amrein',
    );

    Future<TestApp> start(WidgetTester tester, NameFormat format) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': 'en',
          'currentBandId': 'b1',
          'nameFormat': format.name,
        },
        user: ann,
      );
      app.backend.addBand('b1', 'Rock', admin: ann, organizationId: 'o1');
      app.backend.addMember('b1', bob, BandRole.admin);
      await tester.runAsync(() => BandService(app.db, app.backend).refresh());
      return app;
    }

    testWidgets('band members with the full name under the nickname', (
      tester,
    ) async {
      final app = await start(tester, NameFormat.nickname);
      await tester.pumpWidget(app.build(home: const BandScreen(bandId: 'b1')));
      await tester.pumpAndSettle();
      expect(find.text('Andi (you)'), findsOneWidget);
      expect(find.textContaining('Ann Zoller'), findsOneWidget);
      expect(find.text('Bob Amrein'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('last name first in the band and in the lineup', (
      tester,
    ) async {
      final app = await start(tester, NameFormat.lastFirst);
      await tester.pumpWidget(app.build(home: const BandScreen(bandId: 'b1')));
      await tester.pumpAndSettle();
      expect(find.text('Zoller Ann (you)'), findsOneWidget);
      expect(find.text('Amrein Bob'), findsOneWidget);

      final lineup = (await tester.runAsync(() async {
        final id = await SetRepository(
          app.db,
          app.storage,
          bandId: 'b1',
        ).createSet(name: 'Gig');
        final set = await (app.db.select(
          app.db.setlists,
        )..where((s) => s.id.equals(id))).getSingle();
        return resolveLineup(
          set,
          members: await app.db.select(app.db.memberships).get(),
          orgMembers: const [],
          userId: 'ann',
          format: NameFormat.lastFirst,
        );
      }))!;
      expect(
        [for (final p in lineup.people) p.name],
        ['Amrein Bob', 'Zoller Ann'],
      );
      await app.dispose(tester);
    });
  });
}
