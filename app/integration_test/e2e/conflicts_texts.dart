// The songs and texts of the end-to-end story "conflicts"
// (conflicts_a_test.dart, conflicts_b_test.dart).

/// Changed on both clients; Carla keeps her version.
const keepMine = 'Conflict Mine';

/// Changed on both clients; Carla takes the server version.
const takeServer = 'Conflict Server';

/// Changed on both clients; Carla keeps both versions.
const keepBoth = 'Conflict Both';

/// Deleted by Anna, changed by Carla; Carla keeps her version.
const deletedKeep = 'Deleted Keep';

/// Deleted by Anna, changed by Carla; Carla accepts the deletion.
const deletedAccept = 'Deleted Accept';

const conflictSongs = [
  keepMine,
  takeServer,
  keepBoth,
  deletedKeep,
  deletedAccept,
];

String original(String title) => '{title: $title}\n[C]Original line';
String annasVersion(String title) => '{title: $title}\n[G]Anna online';
String carlasVersion(String title) => '{title: $title}\n[D]Carla offline';

/// Created by Carla while offline.
const offlineSong = 'Offline Song';

/// A set both rename: sets have no conflicts, the last writer wins.
const lwwSet = 'LWW Set';
const annasSet = 'Set by Anna';
const carlasSet = 'Set by Carla';
