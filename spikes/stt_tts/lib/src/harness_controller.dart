import 'package:flutter/foundation.dart';

import 'measurement.dart';
import 'phrase_book.dart';
import 'platform_facts.dart';
import 'result_document.dart';
import 'spike_stt.dart';
import 'spike_tts.dart';

enum PassStage { idle, ready, listening, finished }

/// Drives the thirty phrase pass, and holds no widget.
///
/// The recogniser and the synthesiser arrive as ports, so the whole pass can be
/// run on a workstation against fakes: which phrase comes next, what happens when
/// one comes back empty, when the pass is over, and what the report says are all
/// ordinary logic, and they are the parts that would otherwise only ever be seen
/// once, on a phone, in a shop.
final class HarnessController extends ChangeNotifier {
  HarnessController({
    required this.stt,
    required this.tts,
    required this.book,
    this.config = const SpikeConfig(),
  });

  final SpikeStt stt;
  final SpikeTts tts;
  final PhraseBook book;
  final SpikeConfig config;

  PassStage _stage = PassStage.idle;
  int _index = 0;
  bool _listening = false;
  final List<PhraseMeasurement> _measurements = <PhraseMeasurement>[];
  SttReadiness _readiness = const SttReadiness(
    available: false,
    microphoneGranted: false,
    localeIds: <String>[],
  );
  TtsReport? _ttsReport;
  DeviceFacts? _device;
  OfflineFacts? _offline;
  String? _readinessError;

  PassStage get stage => _stage;
  int get index => _index;
  int get total => book.phrases.length;
  List<PhraseMeasurement> get measurements =>
      List<PhraseMeasurement>.unmodifiable(_measurements);
  SttReadiness get readiness => _readiness;
  TtsReport? get ttsReport => _ttsReport;
  DeviceFacts? get device => _device;
  OfflineFacts? get offline => _offline;
  String? get readinessError => _readinessError;
  RunSummary get summary => RunSummary.from(_measurements);
  bool get isFinished => _stage == PassStage.finished;
  bool get isListening => _listening;

  /// The phrase just measured, shown next to what was expected.
  PhraseMeasurement? get lastMeasurement =>
      _measurements.isEmpty ? null : _measurements.last;

  SpikePhrase? get currentPhrase {
    if (_index >= total) {
      return null;
    }
    return book.phrases[_index];
  }

  /// Reads the device facts and asks the system whether it can listen. Nothing is
  /// measured before this, because a pass taken on a phone that can reach the
  /// network is not a measurement of offline recognition.
  Future<void> prepare() async {
    _device = await readDeviceFacts();
    _offline = await readOfflineFacts();
    _readiness = await stt.prepare();
    _ttsReport = await tts.speakOnce(language: 'fr-FR', text: _ttsProbeText);
    _readinessError = _describeUnusableDevice();
    _stage = PassStage.ready;
    notifyListeners();
  }

  /// The two findings that must be visible before a pass, before the protocol
  /// criteria apply. A phone holding INTERNET, or without a French voice, makes
  /// the numbers that follow uninterpretable.
  String? _describeUnusableDevice() {
    final OfflineFacts? offlineFacts = _offline;
    if (offlineFacts != null && !offlineFacts.provesOffline) {
      return 'INTERNET accordee: la reconnaissance a pu passer par le reseau. '
          'Construire en release pour que la mesure prouve le hors-ligne.';
    }
    if (!_readiness.microphoneGranted) {
      return 'Microphone non accorde.';
    }
    if (!_readiness.hasFrench) {
      return 'Aucun pack francais annonce par le systeme.';
    }
    final TtsReport? spoken = _ttsReport;
    if (spoken != null && !spoken.hasFrench) {
      return 'Aucune voix francaise pour la synthese.';
    }
    return null;
  }

  /// Measures the current phrase and moves to the next one. Refuses to start while
  /// a listen is still running, so a double tap cannot lose a phrase.
  Future<void> measureCurrent() async {
    if (_listening) {
      return;
    }
    final SpikePhrase? phrase = currentPhrase;
    if (phrase == null) {
      _stage = PassStage.finished;
      notifyListeners();
      return;
    }
    _listening = true;
    _stage = PassStage.listening;
    notifyListeners();

    final SttOutcome outcome = await stt.listenOnce(localeId: config.localeId);
    _measurements.add(
      PhraseMeasurement(
        phraseId: phrase.id,
        reference: phrase.text,
        heard: outcome.transcript,
        latency: outcome.latency,
        failure: outcome.error,
      ),
    );
    _index++;
    _listening = false;
    _stage = _index >= total ? PassStage.finished : PassStage.ready;
    notifyListeners();
  }

  /// Puts the current phrase back and forgets what it produced. The frozen set is
  /// the reference; a pass that got one phrase wrong is re-measured, not edited.
  void retryCurrent() {
    if (_measurements.isEmpty) {
      return;
    }
    _measurements.removeLast();
    _index = _index > 0 ? _index - 1 : 0;
    _stage = PassStage.ready;
    notifyListeners();
  }

  void restart() {
    _measurements.clear();
    _index = 0;
    _stage = book.phrases.isEmpty ? PassStage.finished : PassStage.ready;
    notifyListeners();
  }

  /// Null until the pass is complete, so a partial run can never be mistaken for a
  /// result in the ADR.
  ResultDocument? get report {
    if (!isFinished) {
      return null;
    }
    final DeviceFacts? deviceFacts = _device;
    final OfflineFacts? offlineFacts = _offline;
    final TtsReport? tts = _ttsReport;
    if (deviceFacts == null || offlineFacts == null || tts == null) {
      return null;
    }
    return ResultDocument.from(
      config: config,
      device: deviceFacts,
      offline: offlineFacts,
      readiness: _readiness,
      measurements: _measurements,
      tts: tts,
    );
  }

  /// A short fixed sentence, so the measured latency is comparable between runs and
  /// between devices.
  static const String _ttsProbeText = 'Vente enregistrée.';
}
