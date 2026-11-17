/// Role of a user in a band (ADR-0005, ADR-0023), from the most rights to
/// the fewest. `admin` is the band leader (stored as `admin` on the server).
enum BandRole { admin, planner, member }

/// Role of a user in an organization (ADR-0017, ADR-0023), from the most
/// rights to the fewest. Organization admins may do everything; librarians
/// maintain the song library.
enum OrgRole { admin, librarian, member }
