import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

final askAiRepositoryProvider = Provider<AskAiRepository>((ref) {
  return AskAiRepository();
});

class AskAiRepository {
  AskAiRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  SettingStore get _settings => Stores.setting;

  /// Streams the AI response using the configured endpoint.
  Stream<AskAiEvent> ask({
    required String selection,
    String? localeHint,
    List<AskAiMessage> conversation = const [],
  }) async* {
    final baseUrl = _settings.askAiBaseUrl.fetch().trim();
    final apiKey = _settings.askAiApiKey.fetch().trim();
    final model = _settings.askAiModel.fetch().trim();

    final missing = <AskAiConfigField>[];
    if (baseUrl.isEmpty) missing.add(AskAiConfigField.baseUrl);
    if (apiKey.isEmpty) missing.add(AskAiConfigField.apiKey);
    if (model.isEmpty) missing.add(AskAiConfigField.model);
    if (missing.isNotEmpty) {
      throw AskAiConfigException(missingFields: missing);
    }

    final uri = _composeUri(baseUrl, '/v1/chat/completions');
    final authHeader = apiKey.startsWith('Bearer ') ? apiKey : 'Bearer $apiKey';
    final headers = <String, String>{
      Headers.acceptHeader: 'text/event-stream',
      Headers.contentTypeHeader: Headers.jsonContentType,
      'Authorization': authHeader,
    };

    final requestBody = _buildRequestBody(
      model: model,
      selection: selection,
      localeHint: localeHint,
      conversation: conversation,
    );

    Response<ResponseBody> response;
    try {
      response = await _dio.postUri<ResponseBody>(
        uri,
        data: jsonEncode(requestBody),
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
    } on DioException catch (e) {
      throw AskAiNetworkException(message: e.message ?? 'Request failed', cause: e);
    }

    final body = response.data;
    if (body == null) {
      throw AskAiNetworkException(message: 'Empty response body');
    }

    final contentBuffer = StringBuffer();
    final commands = <AskAiCommand>[];
    final toolBuilders = <int, _ToolCallBuilder>{};
    final utf8Stream = body.stream.cast<List<int>>().transform(utf8.decoder);
    final carry = StringBuffer();

    try {
      await for (final chunk in utf8Stream) {
        carry.write(chunk);
        final segments = carry.toString().split('\n\n');
        carry
          ..clear()
          ..write(segments.removeLast());

        for (final segment in segments) {
          final lines = segment.split('\n');
          for (final rawLine in lines) {
            final line = rawLine.trim();
            if (line.isEmpty || !line.startsWith('data:')) {
              continue;
            }
            final payload = line.substring(5).trim();
            if (payload.isEmpty) {
              continue;
            }
            if (payload == '[DONE]') {
              yield AskAiCompleted(
                fullText: contentBuffer.toString(),
                commands: List.unmodifiable(commands),
              );
              return;
            }

            Map<String, dynamic> json;
            try {
              json = jsonDecode(payload) as Map<String, dynamic>;
            } catch (e, s) {
              yield AskAiStreamError(e, s);
              continue;
            }

            final choices = json['choices'];
            if (choices is! List || choices.isEmpty) {
              continue;
            }

            for (final choice in choices) {
              if (choice is! Map<String, dynamic>) {
                continue;
              }
              final delta = choice['delta'];
              if (delta is Map<String, dynamic>) {
                final content = delta['content'];
                if (content is String && content.isNotEmpty) {
                  contentBuffer.write(content);
                  yield AskAiContentDelta(content);
                } else if (content is List) {
                  for (final item in content) {
                    if (item is Map<String, dynamic>) {
                      final text = item['text'] as String?;
                      if (text != null && text.isNotEmpty) {
                        contentBuffer.write(text);
                        yield AskAiContentDelta(text);
                      }
                    }
                  }
                }

                final toolCalls = delta['tool_calls'];
                if (toolCalls is List) {
                  for (final toolCall in toolCalls) {
                    if (toolCall is! Map<String, dynamic>) continue;
                    final index = toolCall['index'] as int? ?? 0;
                    final builder = toolBuilders.putIfAbsent(index, _ToolCallBuilder.new);
                    final function = toolCall['function'];
                    if (function is Map<String, dynamic>) {
                      builder.name ??= function['name'] as String?;
                      final args = function['arguments'] as String?;
                      if (args != null && args.isNotEmpty) {
                        builder.arguments.write(args);
                        final command = builder.tryBuild();
                        if (command != null) {
                          commands.add(command);
                          yield AskAiToolSuggestion(command);
                        }
                      }
                    }
                  }
                }
              }

              final finishReason = choice['finish_reason'];
              if (finishReason == 'tool_calls') {
                for (final builder in toolBuilders.values) {
                  final command = builder.tryBuild(force: true);
                  if (command != null) {
                    commands.add(command);
                    yield AskAiToolSuggestion(command);
                  }
                }
                toolBuilders.clear();
              }
            }
          }
        }
      }

      // Flush remaining buffer if [DONE] not received.
      if (contentBuffer.isNotEmpty || commands.isNotEmpty) {
        yield AskAiCompleted(
          fullText: contentBuffer.toString(),
          commands: List.unmodifiable(commands),
        );
      }
    } catch (e, s) {
      yield AskAiStreamError(e, s);
      return;
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required String model,
    required String selection,
    required List<AskAiMessage> conversation,
    String? localeHint,
  }) {
    final promptBuffer = StringBuffer()
      ..writeln('你是一个 SSH 终端助手。')
      ..writeln('用户会提供一段终端输出或命令，请结合上下文给出解释。')
      ..writeln('当需要给出可执行命令时，调用 `recommend_shell` 工具，并提供简短描述。')
      ..writeln('仅在非常确定命令安全时才给出建议。');

    if (localeHint != null && localeHint.isNotEmpty) {
      promptBuffer
        ..writeln('请优先使用用户的语言输出：$localeHint。')
        ..writeln('如果无法判断语言，请使用简体中文。');
    } else {
      promptBuffer.writeln('如果无法判断语言，请使用简体中文。');
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': promptBuffer.toString(),
      },
      {
        'role': 'user',
        'content': '以下是终端选中的内容：\n$selection',
      },
      ...conversation.map((message) => {
            'role': message.apiRole,
            'content': message.content,
          }),
    ];

    return {
      'model': model,
      'stream': true,
      'messages': messages,
      'tools': [
        {
          'type': 'function',
          'function': {
            'name': 'recommend_shell',
            'description': '返回一个用户可以直接复制执行的终端命令。',
            'parameters': {
              'type': 'object',
              'required': ['command'],
              'properties': {
                'command': {
                  'type': 'string',
                  'description': '完整的终端命令，确保可以被粘贴后直接执行。',
                },
                'description': {
                  'type': 'string',
                  'description': '简述该命令的作用或注意事项。',
                },
              },
            },
          },
        },
      ],
    };
  }

  Uri _composeUri(String base, String path) {
    final sanitizedBase = base.replaceAll(RegExp(r'/+$'), '');
    final sanitizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$sanitizedBase/$sanitizedPath');
  }
}

class _ToolCallBuilder {
  _ToolCallBuilder();

  final StringBuffer arguments = StringBuffer();
  String? name;
  bool _emitted = false;

  AskAiCommand? tryBuild({bool force = false}) {
    if (_emitted && !force) return null;
    final raw = arguments.toString();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final command = decoded['command'] as String?;
      if (command == null || command.trim().isEmpty) {
        if (force) {
          _emitted = true;
        }
        return null;
      }
      final description = decoded['description'] as String? ?? decoded['explanation'] as String? ?? '';
      _emitted = true;
      return AskAiCommand(
        command: command.trim(),
        description: description.trim(),
        toolName: name,
      );
    } on FormatException {
      if (force) {
        _emitted = true;
      }
      return null;
    }
  }
}

@immutable
enum AskAiConfigField { baseUrl, apiKey, model }

class AskAiConfigException implements Exception {
  const AskAiConfigException({required this.missingFields});

  final List<AskAiConfigField> missingFields;

  @override
  String toString() => 'AskAiConfigException(missing: ${missingFields.map((e) => e.name).join(', ')})';
}

@immutable
class AskAiNetworkException implements Exception {
  const AskAiNetworkException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AskAiNetworkException(message: $message)';
}
