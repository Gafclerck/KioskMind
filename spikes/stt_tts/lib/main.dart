import 'package:flutter/material.dart';

import 'src/flutter_tts_probe.dart';
import 'src/harness_controller.dart';
import 'src/harness_view.dart';
import 'src/phrase_book.dart';
import 'src/speech_to_text_probe.dart';
import 'src/spike_stt.dart';
import 'src/spike_tts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final PhraseBook book = await loadPhraseBook();
  runApp(SpikeApp(book: book));
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({required this.book, this.stt, this.tts, super.key});

  final PhraseBook book;

  /// Injectable so the harness can be driven on a workstation, against fakes.
  final SpikeStt? stt;
  final SpikeTts? tts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spike STT/TTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: HarnessView(
        controller: HarnessController(
          stt: stt ?? SpeechToTextProbe(),
          tts: tts ?? FlutterTtsProbe(),
          book: book,
        ),
      ),
    );
  }
}
