import 'package:flutter/services.dart';

/// Facts that can only be read on the device, through one channel.
///
/// Two questions matter here and neither can be answered from Dart.
///
/// Whether the process holds `INTERNET` decides if the measurement proves
/// anything: the Flutter templates add that permission to the debug and profile
/// manifests for the tooling's own socket, so a debug run reaches the network
/// even when nobody wrote a line of networking code. Reading the granted
/// permission at runtime is the difference between believing the app is offline
/// and knowing it, and it travels in the result file as a fact.
///
/// Which phone took the measurement is part of the exit criterion, since the
/// pipeline asks for the most modest device the shop owns. Reading the model from
/// the device means the result file carries it, and the ADR no longer depends on
/// somebody remembering the name afterwards.
const MethodChannel _channel = MethodChannel('stt_tts_spike/device');

final class OfflineFacts {
  const OfflineFacts({required this.internetGranted, this.error});

  final bool internetGranted;

  final String? error;

  /// F2 requires voice to work without a network, so a granted `INTERNET`
  /// permission means the measurement proves nothing until the build changes.
  bool get provesOffline => !internetGranted;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'internetGranted': internetGranted,
      'provesOffline': provesOffline,
      if (error != null) 'error': error,
    };
  }
}

final class DeviceFacts {
  const DeviceFacts({
    required this.manufacturer,
    required this.model,
    required this.androidRelease,
    required this.sdkInt,
    this.error,
  });

  final String manufacturer;
  final String model;
  final String androidRelease;
  final int sdkInt;

  final String? error;

  String get label =>
      '$manufacturer $model (Android $androidRelease, API $sdkInt)';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'manufacturer': manufacturer,
      'model': model,
      'androidRelease': androidRelease,
      'sdkInt': sdkInt,
      if (error != null) 'error': error,
    };
  }
}

/// A read that failed reports the pessimistic value rather than a favourable one:
/// an unread permission is treated as granted, so a broken channel can never turn
/// into a passed offline proof.
Future<OfflineFacts> readOfflineFacts() async {
  try {
    final bool? granted = await _channel.invokeMethod<bool>(
      'hasInternetPermission',
    );
    if (granted == null) {
      return const OfflineFacts(
        internetGranted: true,
        error: 'le canal ne repond pas: controle impossible',
      );
    }
    return OfflineFacts(internetGranted: granted);
  } on MissingPluginException {
    return const OfflineFacts(
      internetGranted: true,
      error: 'MainActivity ne parle pas le canal du spike',
    );
  } on Object catch (error) {
    return OfflineFacts(internetGranted: true, error: error.toString());
  }
}

Future<DeviceFacts> readDeviceFacts() async {
  try {
    final Map<Object?, Object?>? raw = await _channel
        .invokeMethod<Map<Object?, Object?>>('describe');
    if (raw == null) {
      return const DeviceFacts(
        manufacturer: 'inconnu',
        model: 'inconnu',
        androidRelease: 'inconnu',
        sdkInt: 0,
        error: 'le canal ne repond pas',
      );
    }
    return DeviceFacts(
      manufacturer: (raw['manufacturer'] as String?) ?? 'inconnu',
      model: (raw['model'] as String?) ?? 'inconnu',
      androidRelease: (raw['androidRelease'] as String?) ?? 'inconnu',
      sdkInt: (raw['sdkInt'] as int?) ?? 0,
    );
  } on Object catch (error) {
    return DeviceFacts(
      manufacturer: 'inconnu',
      model: 'inconnu',
      androidRelease: 'inconnu',
      sdkInt: 0,
      error: error.toString(),
    );
  }
}
