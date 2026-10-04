/// The network reachability the cascade consults before trying cloud voice.
///
/// A port so the domain decides whether to attempt cloud interpretation without
/// knowing about sockets, HTTP or telephony, and so a test can simulate a network
/// drop mid-utterance.
abstract interface class ConnectivityProbe {
  /// Whether the device has working connectivity to the cloud backend.
  Future<bool> get isOnline;
}
