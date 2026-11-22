import 'package:flutter/foundation.dart';

import 'band_role.dart';
import 'database.dart' show localBandId, SongEntry;

/// A band as the UI shows it: the local library or a band from the server,
/// with the signed-in user's roles and the resulting permissions
/// (ADR-0005, ADR-0017, ADR-0023).
@immutable
class BandView {
  const BandView({
    required this.id,
    required this.name,
    this.organizationId,
    this.organizationName = '',
    this.role,
    this.orgRole,
    this.orgLibrary,
    this.staleAfterSetting = 0,
  });

  /// Months after which a song counts as not played for a while when the
  /// band sets none (ADR-0046).
  static const defaultStaleAfterMonths = 6;

  /// The local library ("On this device"); everything is allowed.
  static const local = BandView(
    id: localBandId,
    name: '',
    role: BandRole.admin,
  );

  final String id;

  /// Band name; empty for the local library (shown localized).
  final String name;

  /// Organization of the band; null for the local library.
  final String? organizationId;
  final String organizationName;

  /// Role in the band; null for organization admins who are no band member.
  final BandRole? role;

  /// Role in the band's organization; null for the local library.
  final OrgRole? orgRole;

  /// The song library of the band's organization with the user's song
  /// permissions; null for the local library (see [library]).
  final LibraryView? orgLibrary;

  /// The band's own threshold for songs not played for a while, in months;
  /// 0 = [defaultStaleAfterMonths] (ADR-0046).
  final int staleAfterSetting;

  /// Months after which a song counts as not played for a while.
  int get staleAfterMonths =>
      staleAfterSetting > 0 ? staleAfterSetting : defaultStaleAfterMonths;

  bool get isLocal => id == localBandId;

  /// Organization admins may do everything in its bands (ADR-0023).
  bool get isOrgAdmin => orgRole == OrgRole.admin;

  /// Band leader (stored as band `admin`).
  bool get isBandAdmin => role == BandRole.admin;

  /// Song library of the band: its organization, or the local library.
  String get libraryId => organizationId ?? localBandId;

  /// The song library with the user's song permissions.
  /// Without [orgLibrary], an organization's library allows nothing.
  LibraryView get library => isLocal
      ? LibraryView.local
      : orgLibrary ?? LibraryView(id: libraryId, name: organizationName);

  /// Create, edit, reorder and delete sets: leaders, set planners and
  /// organization admins.
  bool get canManageSets =>
      isLocal || isBandAdmin || role == BandRole.planner || isOrgAdmin;

  /// Change when songs count as not played for a while: leaders, set
  /// planners and organization admins of a band from the server (ADR-0046);
  /// the local library keeps the default.
  bool get canSetStaleAfter => !isLocal && canManageSets;

  /// Band settings, members and their roles, invitations into the band
  /// (never for the local library).
  bool get canManageBand => !isLocal && (isBandAdmin || isOrgAdmin);

  /// Delete the band (to the trash for 30 days): organization admins only,
  /// like creating bands (ADR-0044).
  bool get canDeleteBand => !isLocal && isOrgAdmin;

  @override
  bool operator ==(Object other) =>
      other is BandView &&
      other.id == id &&
      other.name == name &&
      other.organizationId == organizationId &&
      other.organizationName == organizationName &&
      other.role == role &&
      other.orgRole == orgRole &&
      other.orgLibrary == orgLibrary &&
      other.staleAfterSetting == staleAfterSetting;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    organizationId,
    organizationName,
    role,
    orgRole,
    orgLibrary,
    staleAfterSetting,
  );
}

/// A song library as the UI shows it: the local library or an
/// organization's library, with the signed-in user's song permissions
/// (ADR-0017, ADR-0023). Chosen together with the band (#856).
@immutable
class LibraryView {
  const LibraryView({
    required this.id,
    this.name = '',
    this.orgRole,
    this.isLeader = false,
    this.userId,
  });

  /// The local library ("On this device"); everything is allowed.
  static const local = LibraryView(id: localBandId);

  /// The local library id or an organization id.
  final String id;

  /// Organization name; empty for the local library (shown localized).
  final String name;

  /// Role in the organization; null for the local library.
  final OrgRole? orgRole;

  /// Leader of at least one band of the organization.
  final bool isLeader;

  /// The signed-in user, for their own songs.
  final String? userId;

  bool get isLocal => id == localBandId;

  bool get isOrgAdmin => orgRole == OrgRole.admin;

  /// Maintains the library: organization admins and librarians.
  bool get isLibrarian =>
      orgRole == OrgRole.admin || orgRole == OrgRole.librarian;

  /// Create and import new songs: librarians and band leaders.
  bool get canCreateSongs => isLocal || isLibrarian || isLeader;

  /// Edit [song] and its attachments: librarians, and band leaders for the
  /// songs they created as long as nobody else has changed them.
  bool canEditSong(SongEntry song) =>
      canEditSongBy(createdBy: song.createdBy, updatedBy: song.updatedBy);

  /// [canEditSong] for a song with this creator and last editor, e.g. from
  /// a song list.
  bool canEditSongBy({String? createdBy, String? updatedBy}) =>
      isLocal ||
      isLibrarian ||
      (isLeader &&
          userId != null &&
          createdBy == userId &&
          updatedBy == userId);

  /// Delete songs and attachments: librarians.
  bool get canDeleteSongs => isLocal || isLibrarian;

  /// Export the library as a backup archive (ADR-0043): the local library,
  /// and organizations for librarians (organization admins included).
  bool get canExportLibrary => isLocal || isLibrarian;

  @override
  bool operator ==(Object other) =>
      other is LibraryView &&
      other.id == id &&
      other.name == name &&
      other.orgRole == orgRole &&
      other.isLeader == isLeader &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(id, name, orgRole, isLeader, userId);
}

/// An organization of the signed-in user.
@immutable
class OrganizationView {
  const OrganizationView({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final OrgRole role;

  bool get isAdmin => role == OrgRole.admin;

  /// Close the organization (30 days in the trash): its admins (ADR-0044).
  bool get canClose => isAdmin;

  @override
  bool operator ==(Object other) =>
      other is OrganizationView &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}
