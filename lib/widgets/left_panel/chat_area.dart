import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import 'chat_bubble.dart';

class ChatArea extends StatelessWidget {
  const ChatArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final settings = context.read<SettingsProvider>();
        final messages = chat.messages;
        final hasStreaming = chat.isLoading && chat.streamingContent.isNotEmpty;
        final showGreeting = messages.isEmpty && !hasStreaming;

        return Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: (showGreeting ? 1 : 0) + messages.length + (hasStreaming ? 1 : 0),
            itemBuilder: (context, index) {
              if (showGreeting && index == 0) {
                return ChatBubble(
                  content: settings.profile.openingLine,
                  isUser: false,
                  timestamp: DateTime.now(),
                );
              }
              final msgIndex = index - (showGreeting ? 1 : 0);
              if (hasStreaming && msgIndex == messages.length) {
                return ChatBubble(
                  content: chat.streamingContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                );
              }
              final msg = messages[msgIndex];
              return ChatBubble(
                content: msg.content,
                isUser: msg.role == 'user',
                timestamp: msg.timestamp,
              );
            },
          ),
        );
      },
    );
  }
}
