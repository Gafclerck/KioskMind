import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';

import 'intent_handler_contract.dart';

void main() {
  runIntentHandlerContract(buildMockVoiceHandlers);
}
