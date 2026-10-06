import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/voice_session_state.dart';

/// The six bars that show the microphone is open.
///
/// Six bars and not a curve: a curve is drawn, it moves as a whole and reads as a
/// decoration, whereas bars of different heights move out of step and read as a
/// level. A microphone that looks busy while it hears nothing is worse than one
/// that looks still, so the animation follows [status] and stops with it.
///
/// The heights are the specification's, and they are deliberately unequal so the
/// row is not a fence.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({super.key, required this.status});

  final VoiceSessionStatus status;

  /// The height of each bar at rest, in logical pixels.
  static const List<double> heights = <double>[12, 24, 36, 16, 28, 10];

  static const double _barWidth = 4;

  static const double _spacing = 4;

  static const Duration _period = Duration(milliseconds: 1100);

  /// The tallest bar, which is the height of the row.
  static double get rowHeight => heights.reduce(math.max);

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: VoiceWaveform._period,
  );

  /// Starts and parks the bars from [didChangeDependencies], not from [initState].
  ///
  /// Whether the bars move is read from a [MediaQuery], and an inherited widget
  /// cannot be read before initState returns. Asking anyway throws on the way in and
  /// leaves the merchant with a row of bars that were never drawn.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _followStatus();
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Moves the bars, or parks them, to match what the microphone is doing.
  ///
  /// Parking resets to the first frame rather than freezing where the wave was: a row
  /// frozen at its peak would claim the loudest sound of the last turn.
  void _followStatus() {
    if (_isMoving == _controller.isAnimating) {
      return;
    }
    if (_isMoving) {
      _controller.repeat();
      return;
    }
    _controller.stop();
    _controller.value = 0;
  }

  /// Whether the bars are meant to move right now.
  ///
  /// Listening is the only status where a level is real: while the module is
  /// preparing it has no audio yet, and while it thinks or speaks the microphone is
  /// closed, so a moving wave would claim to hear something it cannot.
  ///
  /// `disableAnimations` is honoured because a merchant who turned motion off in
  /// the system settings gets still bars. Nothing is lost: the status is also drawn
  /// as a line of text on the panel.
  bool get _isMoving =>
      widget.status == VoiceSessionStatus.listening &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.voiceWaveformLabel,
      image: true,
      child: SizedBox(
        height: VoiceWaveform.rowHeight,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < VoiceWaveform.heights.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == VoiceWaveform.heights.length - 1
                          ? 0
                          : VoiceWaveform._spacing,
                    ),
                    child: _bar(i, _controller.value),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(int index, double phase) {
    final double rest = VoiceWaveform.heights[index];
    // One wave travels across the row, so the bars move in sequence rather than
    // all at once. A bar never shrinks below its resting height: a row that
    // collapses between two peaks reads as a broken animation rather than a quiet
    // one, and the merchant would think the microphone had stopped.
    final double offset = (phase - index * 0.11) % 1.0;
    final double lift = math.sin(offset * 2 * math.pi);
    return Container(
      width: VoiceWaveform._barWidth,
      height: rest * (1 + 0.4 * lift),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
