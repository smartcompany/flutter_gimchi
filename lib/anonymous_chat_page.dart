// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fl_chat_core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as fl_chat_ui;
import 'package:uuid/uuid.dart';
import 'utils.dart';

class AnonymousChatPage extends StatefulWidget {
  const AnonymousChatPage({super.key});

  @override
  State<AnonymousChatPage> createState() => _AnonymousChatPageState();
}

class _AnonymousChatPageState extends State<AnonymousChatPage> {
  late final fl_chat_core.InMemoryChatController _chatController;
  late final StreamSubscription _subscription;

  final String _roomId = 'anonymous_room';
  String _userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _chatController = fl_chat_core.InMemoryChatController(messages: const []);

    final messagesStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final createdAt = data['createdAt'];

            DateTime createdAtMillis;

            // createdAt이 Timestamp면 변환, 아니면 그대로 사용
            if (createdAt is Timestamp) {
              createdAtMillis = DateTime.fromMillisecondsSinceEpoch(
                createdAt.millisecondsSinceEpoch,
              );
            } else if (createdAt is int) {
              createdAtMillis = DateTime.fromMillisecondsSinceEpoch(createdAt);
            } else {
              createdAtMillis = DateTime.now();
            }

            return fl_chat_core.TextMessage(
              id: data['id'],
              authorId: data['authorId'],
              createdAt: createdAtMillis,
              text: data['text'],
            );
          }).toList();
        });

    // Firestgore에서 메시지 스트림 구독
    _subscription = messagesStream.listen((messages) {
      // 메시지들을 InMemoryChatController에 설정
      _chatController.setMessages(messages);
    });
  }

  Future<void> _loadUserId() async {
    final userId = await getOrCreateUserId();
    setState(() {
      _userId = userId;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_userId.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
      );
    }

    final builders = fl_chat_core.Builders(
      textMessageBuilder:
          (
            context,
            message,
            index, {
            required bool isSentByMe,
            fl_chat_core.MessageGroupStatus? groupStatus,
          }) => USTextMessageBuilder(
            context,
            message,
            index,
            isSentByMe: isSentByMe,
            groupStatus: groupStatus,
          ),
    );

    final theme = Theme.of(context);
    final chatTheme = fl_chat_core.ChatTheme.fromThemeData(theme);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(l10n(context).chatRoom),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [],
      ),
      body: SafeArea(
        child: fl_chat_ui.Chat(
          chatController: _chatController,
          currentUserId: _userId,
          onMessageSend: _onMessageSend,
          builders: builders,
          theme: chatTheme,
          backgroundColor: cs.surface,
          resolveUser: (fl_chat_core.UserID id) async {
            return fl_chat_core.User(id: id, name: 'John Doe');
          },
        ),
      ),
    );
  }

  // onMessageSend에 연결할 멤버 함수
  Future<void> _onMessageSend(String message) async {
    final textMessage = fl_chat_core.TextMessage(
      authorId: _userId,
      createdAt: DateTime.now(),
      id: const Uuid().v4(),
      text: message,
    );

    // Firestore에 메시지 저장 (비동기 처리, 오류 무시)
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_roomId)
        .collection('messages')
        .add({
          'authorId': textMessage.authorId,
          'createdAt': textMessage.createdAt,
          'id': textMessage.id,
          'text': textMessage.text,
          'type': 'text',
        });
  }
}

// 1. authorId와 익명번호를 매핑할 Map을 만듭니다.
final Map<String, int> _authorIdToAnonNum = {};
int _anonCounter = 1;

// 2. 메시지 리스트를 순회하며 authorId별로 번호를 부여합니다.
int getAnonNum(String authorId) {
  if (!_authorIdToAnonNum.containsKey(authorId)) {
    _authorIdToAnonNum[authorId] = _anonCounter++;
  }
  return _authorIdToAnonNum[authorId]!;
}

Color getAnonColor(String authorId) {
  const colors = [
    Color(0xFF7EB8FF),
    Color(0xFF86EFAC),
    Color(0xFFFBBF24),
    Color(0xFFC4B5FD),
    Color(0xFF5EEAD4),
  ];
  final anonNum = getAnonNum(authorId);
  return colors[(anonNum - 1) % colors.length];
}

String _parseMessageText(String text) {
  // JSON 형식인지 확인
  final trimmed = text.trim();
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final json = jsonDecode(trimmed);
      // JSON 객체에서 text 필드 추출
      if (json is Map<String, dynamic>) {
        final sender = json['sender'] as String?;
        final messageText = json['text'] as String?;
        if (messageText != null) {
          return sender != null ? '$sender: $messageText' : messageText;
        }
        // text 필드가 없으면 전체 JSON을 보기 좋게 포맷
        return json.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      }
    } catch (e) {
      // JSON 파싱 실패 시 원본 텍스트 반환
      return text;
    }
  }
  return text;
}

Widget USTextMessageBuilder(
  BuildContext context,
  fl_chat_core.TextMessage message,
  int index, {
  required bool isSentByMe,
  fl_chat_core.MessageGroupStatus? groupStatus,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  // 상대방 말풍선: 어두운 톤 위에 읽기 좋은 밝은 글자
  const otherBubbleTints = [
    Color(0xFF2D2640),
    Color(0xFF1E3328),
    Color(0xFF332A1F),
    Color(0xFF252838),
    Color(0xFF1F2D33),
    Color(0xFF302428),
    Color(0xFF28332A),
  ];

  final Color bgColor;
  final Color fgColor;
  if (isSentByMe) {
    bgColor = cs.primary;
    fgColor = cs.onPrimary;
  } else {
    final idx = (getAnonNum(message.authorId) - 1) % otherBubbleTints.length;
    bgColor = otherBubbleTints[idx];
    fgColor = const Color(0xFFE8E6ED);
  }

  // 메시지 텍스트 파싱
  final displayText = _parseMessageText(message.text);

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSentByMe
            ? cs.primary.withValues(alpha: 0.35)
            : cs.outline.withValues(alpha: 0.35),
      ),
    ),
    child: Text(
      displayText,
      style: tt.bodyLarge?.copyWith(
            fontSize: 16,
            color: fgColor,
            height: 1.35,
          ) ??
          TextStyle(fontSize: 16, color: fgColor, height: 1.35),
    ),
  );
}
