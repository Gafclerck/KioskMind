/// One recorded handler call: the evidence the routing metric is built on (D9).
///
/// [handlerArgs] is the canonical projection of the intent input, so it can be
/// compared directly with the `expected.handlerArgs` of a golden case.
typedef HandlerCall = ({String intentId, Map<String, Object?> handlerArgs});

/// Where handler calls are recorded, so a test or `voice_eval` can assert which
/// use case was called and with which arguments.
abstract interface class HandlerCallJournal {
  void record(HandlerCall call);

  /// A snapshot, not a live view: mutating it must not corrupt the run.
  List<HandlerCall> get calls;

  void clear();
}
