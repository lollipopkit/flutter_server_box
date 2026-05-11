import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';

void main() {
  group('AskAiRepository.composeChatCompletionsUri', () {
    test('appends v1 chat completions to service root', () {
      final uri = AskAiRepository.composeChatCompletionsUri(
        'https://api.openai.com',
      );

      expect(uri.toString(), 'https://api.openai.com/v1/chat/completions');
    });

    test('appends chat completions to v1 endpoint', () {
      final uri = AskAiRepository.composeChatCompletionsUri(
        'https://api.longcat.chat/openai/v1',
      );

      expect(
        uri.toString(),
        'https://api.longcat.chat/openai/v1/chat/completions',
      );
    });

    test('keeps full chat completions endpoint unchanged', () {
      final uri = AskAiRepository.composeChatCompletionsUri(
        'https://api.longcat.chat/openai/v1/chat/completions',
      );

      expect(
        uri.toString(),
        'https://api.longcat.chat/openai/v1/chat/completions',
      );
    });
  });
}
