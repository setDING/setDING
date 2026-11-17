import '../../data/band_role.dart';
import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';

/// Name of a band; the local library is shown as "On this device".
String bandLabel(AppLocalizations l10n, BandView band) =>
    band.isLocal ? l10n.bandLocal : band.name;

/// Band roles (ADR-0023): the band `admin` is shown as leader.
String roleLabel(AppLocalizations l10n, BandRole role) => switch (role) {
  BandRole.admin => l10n.bandRoleLeader,
  BandRole.planner => l10n.bandRolePlanner,
  BandRole.member => l10n.bandRoleMember,
};

/// Organization roles (ADR-0023).
String orgRoleLabel(AppLocalizations l10n, OrgRole role) => switch (role) {
  OrgRole.admin => l10n.bandRoleAdmin,
  OrgRole.librarian => l10n.orgRoleLibrarian,
  OrgRole.member => l10n.bandRoleMember,
};

/// The user's role in a band; organization admins outside the band are
/// shown as such.
String bandRoleLabel(AppLocalizations l10n, BandView band) =>
    band.role == null ? l10n.bandRoleOrgAdmin : roleLabel(l10n, band.role!);

/// Second line for a band in lists: organization and role, or the hint for
/// the local library.
String bandSubtitle(AppLocalizations l10n, BandView band) => band.isLocal
    ? l10n.bandLocalHint
    : '${band.organizationName} · ${bandRoleLabel(l10n, band)}';
