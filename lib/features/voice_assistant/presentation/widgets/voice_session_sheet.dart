import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/voice_session_controller.dart';
import 'voice_panel.dart';

/// Opens the voice session over the till, from the docked microphone.
///
/// The chrome of the app owns the button; this owns what happens after it is
/// pressed. A snackbar is not a session: the merchant needs the panel, the transcript
/// and the undo banner, and they stay until he dismisses them.
Future<void> openVoiceSession(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.primary,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    // The panel draws its own header, with a close button a merchant can reach with
    // one finger. The drag handle stays: dragging is how the sheet is dismissed by
    // anyone who already knows the gesture, and removing it would take that away.
    showDragHandle: true,
    builder: (BuildContext context) => Theme(
      // The handle is the only part of the sheet drawn by the framework rather than
      // by this module, and the default is a grey pill that reads as a mistake on
      // the green.
      data: Theme.of(context).copyWith(
        bottomSheetTheme: Theme.of(context).bottomSheetTheme.copyWith(
          dragHandleColor: Colors.white.withValues(alpha: 0.4),
        ),
      ),
      child: const VoiceSessionSheet(),
    ),
  );
}

/// The surface of one voice session on the till.
///
/// A sheet and not a page: the till underneath stays on screen, because the session
/// is an overlay on the work and not a place the merchant goes instead of it. It is
/// capped rather than free to grow, so a confirmation with twenty lines scrolls
/// instead of pushing the microphone off the top of the screen.
class VoiceSessionSheet extends ConsumerStatefulWidget {
  const VoiceSessionSheet({super.key});

  /// The sheet never covers more than this much of the screen.
  ///
  /// Enough for the green area and a panel of three or four cards, which is what the
  /// specification lays out. Past that the panel scrolls, so the microphone and the
  /// header stay put.
  static const double maxHeightFactor = 0.92;

  @override
  ConsumerState<VoiceSessionSheet> createState() => _VoiceSessionSheetState();
}

class _VoiceSessionSheetState extends ConsumerState<VoiceSessionSheet> {
  late final VoiceSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(voiceSessionProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_controller.startListening());
    });
  }

  @override
  void dispose() {
    unawaited(_controller.stopListening());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height *
            VoiceSessionSheet.maxHeightFactor,
      ),
      child: Semantics(
        container: true,
        label: l10n.voicePanelLabel,
        child: VoicePanel(onClose: () => Navigator.of(context).pop()),
      ),
    );
  }
}
