/// What happened to one utterance on its way to a proposal.
///
/// The cascade has three places where an utterance stops being understood the way
/// it should: the device is not online, the remote circuit is open, or the remote
/// answer is late. The remote parser has three more: the call failed, the answer
/// names no command, or it names one the app does not have. And two reasons say the
/// thing simply worked.
///
/// Every one of those looks identical from the outside. The merchant hears "I did not
/// understand", the merchant cannot tell a bad key from an empty catalogue from a
/// model that answered late, and the session reports nothing at all. That is why this
/// vocabulary exists: each reason is a different bug with a different fix, and they
/// have to be told apart before any of them can be corrected.
///
/// [localOnly] and [cloudAnswered] are the two reasons that need no repair. The rest
/// are the ones that do.
enum ParseRouteReason {
  /// The rules parser answered, and nothing else was tried.
  localOnly,

  /// No remote credential is configured, so the cloud was never attempted.
  ///
  /// Distinct from [localOnly] because the two look the same to the merchant and
  /// mean the opposite to whoever is shipping: a device with no key can never reach
  /// a command the rules cannot hear.
  noCredential,

  /// The device reported no usable connection.
  offline,

  /// The remote circuit is open after repeated failures.
  circuitOpen,

  /// The remote call outlived the cascade's budget and its answer was discarded.
  ///
  /// The answer may well have been correct. It was thrown away for being late, which
  /// is a budget problem and not a comprehension problem.
  timeout,

  /// The remote call failed: no network, a refused key, an exhausted quota, a
  /// server error. [ParseRouteEvent.detail] carries what the caller knew.
  unreachable,

  /// The remote answered without naming a command.
  noIntentReturned,

  /// The remote named a command, and its answer could not be read.
  ///
  /// The call succeeded, so this is neither [unreachable] nor [noIntentReturned]: the
  /// gateway did its job and handed over something that does not fit the catalog.
  malformedAnswer,

  /// The remote named a command the app does not implement.
  ///
  /// Worth its own reason because it means the prompt and the app disagree about
  /// what commands exist, which is a defect in the catalog rather than in the model.
  unsupportedIntent,

  /// The remote answered, and the answer was used.
  cloudAnswered,
}

/// One recorded fact about how an utterance was understood.
///
/// Recorded by whichever layer knows the fact: the cascade for the route it took,
/// the remote parser for an answer it could not use, a gateway for a status code. The
/// history is read newest first, so the reason a merchant is stuck on is the first
/// thing anyone looks at.
final class ParseRouteEvent {
  const ParseRouteEvent({
    required this.utterance,
    required this.reason,
    this.detail,
  });

  /// What was heard, kept because the reason only makes sense against the words
  /// that produced it.
  final String utterance;

  final ParseRouteReason reason;

  /// Whatever the writer knew beyond the reason: an HTTP status, an exception
  /// message, the identifier the remote invented.
  final String? detail;

  /// Whether the cloud parser produced the proposal.
  bool get fromCloud => reason == ParseRouteReason.cloudAnswered;

  /// Whether this reason is a failure to explain rather than a normal outcome.
  bool get isFailure => reason != ParseRouteReason.cloudAnswered;

  @override
  String toString() =>
      'ParseRouteEvent($reason, "$utterance"'
      '${detail == null ? '' : ', $detail'})';
}
