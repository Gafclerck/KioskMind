import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_session_state.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_waveform.dart';

/// The waveform alone, in whatever status a test needs it in.
///
/// Mounted on its own because the panel reaches "listening" through a microphone
/// that resolves in the real zone, and a test that could only ever see two of the
/// five statuses would leave the other three unchecked.
///
/// The [MediaQuery] that carries `disableAnimations` is built inside the [MaterialApp]
/// and not around it: an app installs its own from the view, so a wrapper outside it
/// would be discarded and the test would pass for the wrong reason.
Future<void> pumpWaveform(
  WidgetTester tester,
  VoiceSessionStatus status, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: VoiceWaveform(status: status),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The height of every bar, in order.
///
/// Six numbers because the row is the specification's, and its shape at rest is a
/// fact a later change could quietly break while still looking like a waveform.
List<double> barHeights(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .map((Container bar) => tester.getSize(find.byWidget(bar)).height)
      .toList();
}

void main() {
  testWidgets('draws the six bars of the specification', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, VoiceSessionStatus.listening);

    expect(find.byType(Container), findsNWidgets(6));
    // The tallest bar is 36 at rest and 50.4 at its peak. The row reserves 36, so
    // the peak is clipped: the row is 50 tall and nothing is drawn outside it.
    expect(VoiceWaveform.rowHeight, 36);
  });

  testWidgets('moves while the microphone is open', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, VoiceSessionStatus.listening);
    final List<double> first = barHeights(tester);

    // A quarter of the period: enough for the wave to have travelled and come back
    // on at least one bar, and short enough that the bars cannot all be at their
    // resting height by chance.
    await tester.pump(const Duration(milliseconds: 275));
    final List<double> second = barHeights(tester);

    expect(second, isNot(first));
  });

  testWidgets('is still while the microphone is closed', (
    WidgetTester tester,
  ) async {
    for (final VoiceSessionStatus status in <VoiceSessionStatus>[
      VoiceSessionStatus.idle,
      VoiceSessionStatus.preparing,
      VoiceSessionStatus.thinking,
      VoiceSessionStatus.speaking,
    ]) {
      await pumpWaveform(tester, status);
      final List<double> still = barHeights(tester);

      await tester.pump(const Duration(milliseconds: 275));

      expect(
        barHeights(tester),
        still,
        reason: '$status has no audio to show, so the row must not pretend to',
      );
    }
  });

  testWidgets('is still when the merchant turned motion off', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(
      tester,
      VoiceSessionStatus.listening,
      disableAnimations: true,
    );
    final List<double> still = barHeights(tester);

    await tester.pump(const Duration(milliseconds: 275));

    expect(barHeights(tester), still);

    // And the same setup with motion on does move, so the assertion above is about
    // the setting and not about a waveform that never animated in the first place.
    await pumpWaveform(tester, VoiceSessionStatus.listening);
    await tester.pump(const Duration(milliseconds: 275));

    expect(barHeights(tester), isNot(still));
  });

  testWidgets('starts again when the microphone reopens', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, VoiceSessionStatus.thinking);
    final List<double> still = barHeights(tester);
    await tester.pump(const Duration(milliseconds: 275));
    expect(barHeights(tester), still);

    await pumpWaveform(tester, VoiceSessionStatus.listening);
    await tester.pump(const Duration(milliseconds: 275));

    expect(barHeights(tester), isNot(still));
  });

  testWidgets('tells a reader who cannot see it what it is', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, VoiceSessionStatus.listening);

    expect(find.bySemanticsLabel('Niveau du micro'), findsOneWidget);
  });
}
