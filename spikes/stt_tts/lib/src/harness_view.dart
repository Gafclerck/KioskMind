import 'package:flutter/material.dart';

import 'harness_controller.dart';
import 'pass_card.dart';
import 'report_cards.dart';

/// The whole spike, one screen.
///
/// One screen on purpose. The person holding the phone is holding a customer queue
/// in the other hand, and a wizard would mean losing sight of the conditions, or of
/// the totals, between two steps. Everything that has to be checked stays visible.
class HarnessView extends StatelessWidget {
  const HarnessView({required this.controller, super.key});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Spike STT/TTS')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              ReportCards(controller: controller),
              const SizedBox(height: 16),
              PassCard(controller: controller),
            ],
          ),
        );
      },
    );
  }
}
