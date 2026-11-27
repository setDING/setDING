import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/web_client.dart';
import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import '../sync/band_service.dart';
import 'band_copy.dart';
import 'band_view.dart';
import 'contact_repository.dart';
import 'database.dart';
import 'person_name.dart';
import 'storage_providers.dart';

// Bands (ADR-0005) -------------------------------------------------------------

final bandServiceProvider = Provider<BandService>(
  (ref) => BandService(
    ref.watch(databaseProvider),
    ref.watch(syncBackendProvider),
    storage: ref.watch(attachmentStorageProvider),
  ),
);

/// Whether the local library "On this device" is shown: not on the web
/// client (ADR-0018), and not when the person switched it off while signed
/// in (ADR-0054); signed out it is always shown. Its data stays.
final localLibraryShownProvider = Provider<bool>((ref) {
  if (ref.watch(webClientProvider)) return false;
  if (ref.watch(authProvider.select((u) => u == null))) return true;
  return ref.watch(settingsProvider.select((s) => s.showLocalLibrary));
});

/// The local library followed by the bands of the signed-in user, without
/// the local library when it is not shown ([localLibraryShownProvider]).
final bandsProvider = StreamProvider<List<BandView>>((ref) {
  final bands = ref
      .watch(bandServiceProvider)
      .watchBands(ref.watch(authProvider.select((u) => u?.id)));
  if (ref.watch(localLibraryShownProvider)) return bands;
  return bands.map(
    (list) => [
      for (final b in list)
        if (!b.isLocal) b,
    ],
  );
});

// Band and song library selection (#856) --------------------------------------
//
// The band (sets, overview) and the song library (songs tab) are one
// selection across the app: choosing a band shows its organization's songs,
// choosing a library selects a band of it. Only an organization without a
// band of the user is a library without a band ([noBandId]).

/// [BandView.id] of [currentBandProvider] while the chosen song library has
/// no band of the user.
const noBandId = '';

String _lastBandKey(String libraryId) => 'lastBandId.$libraryId';

/// The bands the app can show, while they load: the local library when it
/// is shown, none on the web (ADR-0018) or when it is hidden (ADR-0054).
List<BandView> _availableBands(Ref ref) =>
    ref.watch(bandsProvider).value ??
    (ref.watch(localLibraryShownProvider)
        ? const [BandView.local]
        : const <BandView>[]);

/// The band chosen in the band switcher (stored per device). Choosing a
/// band also chooses its song library ([selectedLibraryIdProvider]).
class SelectedBandNotifier extends Notifier<String> {
  static const _key = 'currentBandId';

  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_key) ?? localBandId;

  Future<void> select(String bandId) async {
    final band = (ref.read(bandsProvider).value ?? const <BandView>[])
        .where((b) => b.id == bandId)
        .firstOrNull;
    final libraryId =
        band?.libraryId ?? (bandId == localBandId ? localBandId : null);
    await _store(bandId);
    if (libraryId != null) {
      await ref
          .read(sharedPreferencesProvider)
          .setString(_lastBandKey(libraryId), bandId);
      await ref.read(selectedLibraryIdProvider.notifier)._store(libraryId);
    }
  }

  /// Stores [bandId]; [noBandId] while the chosen library has no band.
  Future<void> _store(String bandId) async {
    state = bandId;
    await ref.read(sharedPreferencesProvider).setString(_key, bandId);
  }

  /// Forgets the choice (web sign-out).
  Future<void> reset() async {
    state = localBandId;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final selectedBandIdProvider = NotifierProvider<SelectedBandNotifier, String>(
  SelectedBandNotifier.new,
);

/// The band shown on the sets tab and the overview: a band of the current
/// song library ([currentLibraryProvider]) – the chosen one, else the one
/// last chosen in that library, else its first band. Without a band in that
/// library a band with the id [noBandId] that allows nothing.
final currentBandProvider = Provider<BandView>((ref) {
  final bands = _availableBands(ref);
  final library = ref.watch(currentLibraryProvider);
  final inLibrary = [
    for (final b in bands)
      if (b.libraryId == library.id) b,
  ];
  BandView? withId(String? id) =>
      inLibrary.where((b) => b.id == id).firstOrNull;
  final last = ref
      .watch(sharedPreferencesProvider)
      .getString(_lastBandKey(library.id));
  return withId(ref.watch(selectedBandIdProvider)) ??
      withId(last) ??
      inLibrary.firstOrNull ??
      // The web client without any band shows its start screen instead.
      (bands.isEmpty
          ? BandView.local
          : BandView(
              id: noBandId,
              name: '',
              organizationId: library.isLocal ? null : library.id,
              organizationName: library.name,
            ));
});

/// Whether the current song library has a band of the user; without one the
/// sets tab and the overview show a hint instead of sets.
final hasCurrentBandProvider = Provider<bool>(
  (ref) => ref.watch(currentBandProvider.select((b) => b.id != noBandId)),
);

/// [BandView.id] of [currentBandProvider].
final currentBandIdProvider = Provider<String>(
  (ref) => ref.watch(currentBandProvider.select((b) => b.id)),
);

/// Song library of the current band: its organization (ADR-0017), or the
/// local library. Sets, their song picker and Live mode use it.
final bandLibraryIdProvider = Provider<String>(
  (ref) => ref.watch(currentBandProvider.select((b) => b.libraryId)),
);

// Song libraries (ADR-0017) ---------------------------------------------------

/// Every library on this device, the local one also when it is hidden
/// (ADR-0054); the web client has none (ADR-0018).
final allLibrariesProvider = StreamProvider<List<LibraryView>>((ref) {
  final libraries = ref
      .watch(bandServiceProvider)
      .watchLibraries(ref.watch(authProvider.select((u) => u?.id)));
  if (!ref.watch(webClientProvider)) return libraries;
  return libraries.map(
    (list) => [
      for (final l in list)
        if (!l.isLocal) l,
    ],
  );
});

/// The local library followed by the libraries of the user's
/// organizations, without the local library when it is not shown
/// ([localLibraryShownProvider]). The full and the automatic backup use
/// [allLibrariesProvider] instead.
final librariesProvider = Provider<AsyncValue<List<LibraryView>>>((ref) {
  final libraries = ref.watch(allLibrariesProvider);
  if (ref.watch(localLibraryShownProvider)) return libraries;
  return libraries.whenData(
    (list) => [
      for (final l in list)
        if (!l.isLocal) l,
    ],
  );
});

/// The song library chosen on the songs tab (stored per device); null until
/// one is chosen. Choosing a library also chooses a band of it
/// ([currentBandProvider]).
class SelectedLibraryNotifier extends Notifier<String?> {
  static const _key = 'currentLibraryId';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> select(String libraryId) async {
    await _store(libraryId);
    // Keep the chosen band only while it belongs to the library, so a band
    // of another library never wins over this choice.
    final bands = ref.read(bandsProvider).value ?? const [BandView.local];
    final selected = ref.read(selectedBandIdProvider);
    final keeps = bands.any(
      (b) => b.id == selected && b.libraryId == libraryId,
    );
    if (!keeps) {
      final last = ref
          .read(sharedPreferencesProvider)
          .getString(_lastBandKey(libraryId));
      final inLibrary = [
        for (final b in bands)
          if (b.libraryId == libraryId) b.id,
      ];
      await ref
          .read(selectedBandIdProvider.notifier)
          ._store(
            inLibrary.contains(last)
                ? last!
                : inLibrary.firstOrNull ?? noBandId,
          );
    }
  }

  Future<void> _store(String? libraryId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = libraryId;
    if (libraryId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, libraryId);
    }
  }

  /// Forgets the choice (web sign-out).
  Future<void> reset() => _store(null);
}

final selectedLibraryIdProvider =
    NotifierProvider<SelectedLibraryNotifier, String?>(
      SelectedLibraryNotifier.new,
    );

/// The song library shown on the songs tab, the sets tab and the overview:
/// the library of the chosen band, else the chosen library (an
/// organization without a band of the user), else the library of the first
/// band, else the first library. A choice that is not available (signed
/// out, left the band or organization) is skipped.
final currentLibraryProvider = Provider<LibraryView>((ref) {
  final libraries =
      ref.watch(librariesProvider).value ??
      (ref.watch(localLibraryShownProvider)
          ? const [LibraryView.local]
          : const <LibraryView>[]);
  final bands = _availableBands(ref);
  LibraryView? withId(String? id) =>
      libraries.where((l) => l.id == id).firstOrNull;
  final selectedBand = ref.watch(selectedBandIdProvider);
  return withId(
        bands.where((b) => b.id == selectedBand).firstOrNull?.libraryId,
      ) ??
      withId(ref.watch(selectedLibraryIdProvider)) ??
      withId(bands.firstOrNull?.libraryId) ??
      libraries.firstOrNull ??
      LibraryView.local;
});

/// A song library with the user's permissions, e.g. of the song shown;
/// without permissions when the user cannot see it (any more).
final libraryProvider = Provider.family<LibraryView, String>((ref, id) {
  if (id == localBandId) return LibraryView.local;
  final libraries = ref.watch(librariesProvider).value ?? const [];
  return libraries.where((l) => l.id == id).firstOrNull ?? LibraryView(id: id);
});

/// [LibraryView.id] of [currentLibraryProvider].
final currentLibraryIdProvider = Provider<String>(
  (ref) => ref.watch(currentLibraryProvider.select((l) => l.id)),
);

/// The organizations of the signed-in user.
final organizationsProvider = StreamProvider<List<OrganizationView>>(
  (ref) => ref
      .watch(bandServiceProvider)
      .watchOrganizations(ref.watch(authProvider.select((u) => u?.id))),
);

/// People of an organization, admins first, then by name as the user
/// shows names (ADR-0062).
final orgMembersProvider = StreamProvider.autoDispose
    .family<List<OrgMembershipEntry>, String>((ref, orgId) {
      final format = ref.watch(nameFormatProvider);
      return ref
          .watch(bandServiceProvider)
          .watchOrgMembers(orgId)
          .map(
            (people) => sortedPeople(
              people,
              format,
              role: (m) => m.role.name,
              person: (m) => m.person,
            ),
          );
    });

final contactRepositoryProvider = Provider<ContactRepository>(
  (ref) => ContactRepository(ref.watch(databaseProvider)),
);

/// The people of an organization without an account that can be put in a
/// lineup (ADR-0064).
final orgContactsProvider = StreamProvider.autoDispose
    .family<List<ContactEntry>, String>(
      (ref, orgId) => ref.watch(contactRepositoryProvider).watchContacts(orgId),
    );

/// Every contact of an organization, deleted ones too, for the names in
/// lineups (ADR-0064).
final allOrgContactsProvider = StreamProvider.autoDispose
    .family<List<ContactEntry>, String>(
      (ref, orgId) =>
          ref.watch(contactRepositoryProvider).watchAllContacts(orgId),
    );

/// Members of a band, admins first, then by name as the user shows names
/// (ADR-0062).
final bandMembersProvider = StreamProvider.autoDispose
    .family<List<MembershipEntry>, String>((ref, bandId) {
      final format = ref.watch(nameFormatProvider);
      return ref
          .watch(bandServiceProvider)
          .watchMembers(bandId)
          .map(
            (people) => sortedPeople(
              people,
              format,
              role: (m) => m.role.name,
              person: (m) => m.person,
            ),
          );
    });

/// Copies songs and sets into other libraries and bands (ADR-0017).
final bandCopyProvider = Provider<BandCopyService>(
  (ref) => BandCopyService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);
