/// A gateway call that did not come back with an answer.
///
/// The gateways answer three different kinds of "no", and a merchant cannot tell them
/// apart, so neither can anyone debugging: an exhausted quota, a typo in the key and
/// a dropped connection all used to arrive as an empty answer. Reporting them as one
/// thing is what made a bad credential look like a model that did not understand.
///
/// Thrown rather than returned as an empty answer, so the parser above knows the call
/// failed instead of guessing. Every caller of a gateway already handles a failure by
/// falling back to the rules parser, so nothing about what the merchant hears changes:
/// the status code simply stops being lost.
final class CloudCallFailure implements Exception {
  const CloudCallFailure(this.detail);

  /// Builds the failure of a gateway that answered with a status and a body.
  ///
  /// [kBodyExcerptLimit] characters of the body are kept because the status alone
  /// cannot tell a wrong key from an exhausted quota, and because a body dropped in a
  /// log line by a gateway is small by the time it says anything useful.
  factory CloudCallFailure.fromResponse(
    String gateway,
    int status,
    String body,
  ) {
    final String trimmed = body.trim();
    final bool clipped = trimmed.length > kBodyExcerptLimit;
    final String excerpt = clipped
        ? '${trimmed.substring(0, kBodyExcerptLimit)}...'
        : trimmed;
    return CloudCallFailure(
      '$gateway HTTP $status${excerpt.isEmpty ? '' : ': $excerpt'}',
    );
  }

  static const int kBodyExcerptLimit = 200;

  /// What the gateway said, kept short enough to read in a log.
  final String detail;

  @override
  String toString() => 'CloudCallFailure($detail)';
}
