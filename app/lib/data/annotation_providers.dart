import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/auth_providers.dart';
import 'annotation_repository.dart';
import 'storage_providers.dart';

/// Personal freehand annotations (ADR-0032).
final annotationRepositoryProvider = Provider<AnnotationRepository>(
  (ref) => AnnotationRepository(
    ref.watch(databaseProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);

/// The strokes on a song's ChordPro text (`target` empty) or on one of its
/// PDF attachments.
final annotationsProvider = StreamProvider.autoDispose
    .family<List<AnnotationStroke>, ({String songId, String target})>(
      (ref, key) => ref
          .watch(annotationRepositoryProvider)
          .watch(key.songId, target: key.target),
    );

/// Estimated size in bytes of the strokes on a song's text or attachment,
/// against [annotationMaxBytes].
final annotationSizeProvider = StreamProvider.autoDispose
    .family<int, ({String songId, String target})>(
      (ref, key) => ref
          .watch(annotationRepositoryProvider)
          .watchSize(key.songId, target: key.target),
    );

/// Number of strokes on a song (text and attachments).
final annotationCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, songId) => ref.watch(annotationRepositoryProvider).watchCount(songId),
);
