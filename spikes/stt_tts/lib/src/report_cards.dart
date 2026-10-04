import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'harness_controller.dart';
import 'measurement.dart';
import 'platform_facts.dart';
import 'spike_tts.dart';

/// The conditions the run was taken under, and the running totals.
///
/// The conditions come first and stay on screen during the whole pass, because the
/// two findings that invalidate everything else are a phone that can reach the
/// network and a missing French pack. Seeing them once in a log the person is not
/// looking at would be a worse check than seeing them the whole time.
class ReportCards extends StatelessWidget {
  const ReportCards({required this.controller, super.key});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Conditions(controller: controller),
        if (controller.measurements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _Totals(controller: controller),
          ),
      ],
    );
  }
}

class _Conditions extends StatelessWidget {
  const _Conditions({required this.controller});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    final DeviceFacts? device = controller.device;
    final OfflineFacts? offline = controller.offline;
    final TtsReport? tts = controller.ttsReport;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Conditions de la mesure',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _Fact(label: 'Téléphone', value: device?.label ?? 'lecture...'),
            _Fact(label: 'Permission INTERNET', value: _internetValue(offline)),
            _Fact(
              label: 'Pack français',
              value: controller.readiness.hasFrench ? 'présent' : 'ABSENT',
            ),
            _Fact(label: 'Voix TTS', value: _ttsValue(tts)),
            if (controller.readinessError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  controller.readinessError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _internetValue(OfflineFacts? offline) {
    if (offline == null) {
      return 'lecture...';
    }
    return offline.provesOffline
        ? 'refusée - le hors-ligne est prouvé'
        : 'ACCORDÉE - la mesure ne prouve rien';
  }

  static String _ttsValue(TtsReport? tts) {
    if (tts == null) {
      return 'non mesurée';
    }
    final Duration? latency = tts.startLatency;
    if (latency == null) {
      return 'aucun son (${tts.error ?? 'sans détail'})';
    }
    return '${latency.inMilliseconds} ms avant le premier son';
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.controller});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    final RunSummary summary = controller.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Cumul', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Phrases: ${summary.measured} (échecs: ${summary.failed})'),
            Text(
              'Taux d\'erreur: ${_percent(summary.rate)} plié, ${_percent(summary.literalRate)} littéral',
            ),
            Text('Latence médiane: ${summary.medianLatency.inMilliseconds} ms'),
            Text('Latence p95: ${summary.p95Latency.inMilliseconds} ms'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: controller.isFinished ? () => _copy(context) : null,
              icon: const Icon(Icons.copy),
              label: const Text('Copier le rapport JSON'),
            ),
            if (controller.isFinished) const _PasteHint(),
          ],
        ),
      ),
    );
  }

  /// The report is copied rather than written to a file, because a release build
  /// cannot read its own private directory from `adb` and adding an external storage
  /// permission to a spike would be a worse trade than one paste.
  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final report = controller.report;
    if (report == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: report.encode()));
    messenger.showSnackBar(
      const SnackBar(content: Text('Rapport copié. Collez-le dans l ADR.')),
    );
  }
}

class _PasteHint extends StatelessWidget {
  const _PasteHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        'Collez le JSON dans docs/decisions/ADR-001-stt-retenu.md, section '
        '"Mesures", puis remplissez la décision.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label: $value'),
    );
  }
}
