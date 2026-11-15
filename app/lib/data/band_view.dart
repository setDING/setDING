import 'package:flutter/foundation.dart';

import 'band_role.dart';
import 'database.dart' show localBandId;

/// A band as the UI shows it: the local library or a band from the server,
/// with the signed-in user's roles and the resulting permissions
/// (ADR-0005, ADR-0017).
@immutable
class BandView {
  const BandView({
    required this.id,
    required this.name,
    this.organizationId,
    this.organizationName = '',
    this.role,
    this.isOrgAdmin = false,
    this.membersCanEditSongs = false,
    this.mayEditOrgSongs = false,
  });

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

  final bool isOrgAdmin;
  final bool membersCanEditSongs;

  /// The user may edit the organization's songs: organization admin, admin
  /// of any of its bands, or member of a band that allows it.
  final bool mayEditOrgSongs;

  bool get isLocal => id == localBandId;

  /// Song library of the band: its organization, or the local library.
  String get libraryId => organizationId ?? localBandId;

  bool get isBandAdmin => role == BandRole.admin;

  /// Create, import and edit songs and their attachments.
  bool get canEditSongs => isLocal || mayEditOrgSongs;

  /// Delete songs and attachments (organization admins, ADR-0017).
  bool get canDeleteSongs => isLocal || isOrgAdmin;

  /// Create, edit, reorder and delete sets.
  bool get canManageSets => isLocal || isBandAdmin || isOrgAdmin;

  /// Band settings and members (never for the local library).
  bool get canManageBand => !isLocal && (isBandAdmin || isOrgAdmin);

  @override
  bool operator ==(Object other) =>
      other is BandView &&
      other.id == id &&
      other.name == name &&
      other.organizationId == organizationId &&
      other.organizationName == organizationName &&
      other.role == role &&
      other.isOrgAdmin == isOrgAdmin &&
      other.membersCanEditSongs == membersCanEditSongs &&
      other.mayEditOrgSongs == mayEditOrgSongs;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    organizationId,
    organizationName,
    role,
    isOrgAdmin,
    membersCanEditSongs,
    mayEditOrgSongs,
  );
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
  final BandRole role;

  bool get isAdmin => role == BandRole.admin;

  @override
  bool operator ==(Object other) =>
      other is OrganizationView &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}
