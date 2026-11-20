// The songs and the set of the end-to-end story "live" (live_a_test.dart,
// live_b_test.dart).

/// Edited by Anna while Ben plays the set.
const liveOne = 'Live One';
const liveOneEdited = 'Live One (edited)';

/// Deleted by Anna while Ben has it on stage.
const liveTwo = 'Live Two';

/// Moved to the front by Anna.
const liveThree = 'Live Three';

const liveSongs = [liveOne, liveTwo, liveThree];

String liveSource(String title) => '{title: $title}\n[C]Played [G]live';

/// The gig today: Ben plays it from the overview.
const liveGig = 'Live Gig';
