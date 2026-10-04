import 'package:flutter/material.dart';

import 'harness_controller.dart';
import 'measurement.dart';
import 'phrase_book.dart';

/// The pass itself: which phrase is on screen, what came back, and the two buttons
/// that let a phrase be re-measured without restarting the run.
class PassCard extends StatelessWidget {
  const PassCard({required this.controller, super.key});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.stage == PassStage.idle) {
      return FilledButton.icon(
        onPressed: controller.prepare,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Lancer le diagnostic'),
      );
    }
    if (controller.isFinished) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Passe terminée. Copiez le rapport ci-dessous.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _header(context),
            const SizedBox(height: 16),
            if (controller.isListening) const _Listening() else _listenButton(),
            _Outcome(controller: controller),
            _corrections(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final SpikePhrase? phrase = controller.currentPhrase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Phrase ${controller.index + 1} / ${controller.total}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          phrase?.text ?? '',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          phrase?.tags.join(' / ') ?? '',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _listenButton() {
    return FilledButton.icon(
      onPressed: controller.measureCurrent,
      icon: const Icon(Icons.mic),
      label: const Text('Prononcer la phrase'),
    );
  }

  Widget _corrections(BuildContext context) {
    return Row(
      children: <Widget>[
        TextButton(
          onPressed: controller.isListening ? null : controller.retryCurrent,
          child: const Text('Reprendre'),
        ),
        TextButton(
          onPressed: controller.isListening ? null : controller.restart,
          child: const Text('Recommencer'),
        ),
      ],
    );
  }
}

class _Listening extends StatelessWidget {
  const _Listening();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(width: 12),
          Text('écoute...'),
        ],
      ),
    );
  }
}

/// What the last listen attempt produced, next to what was expected.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.controller});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    final PhraseMeasurement? last = controller.lastMeasurement;
    if (last == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Entendu: ${last.heard.isEmpty ? '(rien)' : last.heard}'),
          const SizedBox(height: 4),
          Text('Taux: ${_percent(last.foldedRate.ratio)}'),
          Text('Latence: ${last.latency.inMilliseconds} ms'),
          if (last.failure != null)
            Text(last.failure!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
