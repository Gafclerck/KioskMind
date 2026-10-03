import 'dart:async';
import 'dart:io';

import '../../domain/ports/connectivity_probe.dart';

typedef SocketOpener =
    Future<Socket> Function(String host, int port, {Duration? timeout});

/// Real implementation of [ConnectivityProbe] that verifies actual Internet reachability
/// via a low-latency TCP socket connection.
final class DataConnectionProbe implements ConnectivityProbe {
  DataConnectionProbe({
    this.host = '8.8.8.8',
    this.port = 53,
    this.timeout = const Duration(milliseconds: 600),
    SocketOpener? socketOpener,
  }) : _socketOpener = socketOpener ?? _defaultSocketOpener;

  final String host;
  final int port;
  final Duration timeout;
  final SocketOpener _socketOpener;

  static Future<Socket> _defaultSocketOpener(
    String host,
    int port, {
    Duration? timeout,
  }) {
    return Socket.connect(host, port, timeout: timeout);
  }

  @override
  Future<bool> get isOnline async {
    try {
      final Socket socket = await _socketOpener(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
