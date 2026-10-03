import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/connectivity/data_connection_probe.dart';

final class _FakeSocket implements Socket {
  bool destroyed = false;

  @override
  void destroy() {
    destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DataConnectionProbe', () {
    test('returns true and destroys socket when connection succeeds', () async {
      final fakeSocket = _FakeSocket();
      String? connectedHost;
      int? connectedPort;
      Duration? connectionTimeout;

      final probe = DataConnectionProbe(
        host: '1.1.1.1',
        port: 53,
        timeout: const Duration(milliseconds: 300),
        socketOpener: (host, port, {timeout}) async {
          connectedHost = host;
          connectedPort = port;
          connectionTimeout = timeout;
          return fakeSocket;
        },
      );

      final isOnline = await probe.isOnline;

      expect(isOnline, isTrue);
      expect(fakeSocket.destroyed, isTrue);
      expect(connectedHost, equals('1.1.1.1'));
      expect(connectedPort, equals(53));
      expect(connectionTimeout, equals(const Duration(milliseconds: 300)));
    });

    test(
      'returns false when socket connection fails with SocketException',
      () async {
        final probe = DataConnectionProbe(
          socketOpener: (host, port, {timeout}) async {
            throw const SocketException('Network unreachable');
          },
        );

        final isOnline = await probe.isOnline;

        expect(isOnline, isFalse);
      },
    );

    test('returns false when socket connection times out', () async {
      final probe = DataConnectionProbe(
        socketOpener: (host, port, {timeout}) async {
          throw TimeoutException('Connection timed out');
        },
      );

      final isOnline = await probe.isOnline;

      expect(isOnline, isFalse);
    });
  });
}
