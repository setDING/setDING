// The songs and the set of the end-to-end story "roles" (roles_a_test.dart,
// roles_b_test.dart).

/// Deleted by Anna, undone, deleted again and restored from the trash; Ben
/// has a personal transposition of it.
const roleSong = 'Role Song';
const otherSong = 'Other Song';
const thirdSong = 'Third Song';

const roleSongs = [roleSong, otherSong, thirdSong];

String roleSource(String title) => '{title: $title}\n{key: C}\n[C]Role [G]play';

const roleSet = 'Role Set';

/// Ben's personal transposition of [roleSong] (ADR-0006).
const bensTranspose = 2;
