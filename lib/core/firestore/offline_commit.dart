import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Commits [batch] and lets the caller answer without waiting for the server.
///
/// Local persistence queues the write and synchronises it when connectivity
/// returns, so an offline merchant action must not block on the server
/// round-trip: once the timeout passes, the write is queued locally and the
/// call reports success. The trade-off is optimistic: an error the server
/// reports after the timeout (permissions, missing document) cannot be seen by
/// this call anymore. A failure raised before the timeout still propagates, so
/// genuinely invalid writes are not silently accepted.
Future<void> commitOffline(WriteBatch batch) async {
  try {
    await batch.commit().timeout(const Duration(seconds: 4));
  } on TimeoutException {
    return;
  }
}