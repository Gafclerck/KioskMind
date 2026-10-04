import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../state/voice_session_controller.dart';
import 'voice_panel.dart';

/// Opens the voice session over the till, from the docked microphone.
///
/// The chrome of the app owns the button; this owns what happens after it is
/// pressed. A snackbar is not a session: the merchant needs the panel, the
/// transcript and the undo banner, and they stay until he dismisses them.
Future<void> openVoiceSession(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const VoiceSessionSheet(),
  );
}

/// The surface of one voice session on the till.
class VoiceSessionSheet extends ConsumerStatefulWidget {
  const VoiceSessionSheet({super.key});

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Semantics(
          container: true,
          label: l10n.voicePanelLabel,
          child: const VoicePanel(),
        ),
      ),
    );
  }
}
