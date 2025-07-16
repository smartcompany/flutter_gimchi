// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fl_chat_core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as fl_chat_ui;
import 'utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
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
    if (_userId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n(context).chatRoom), actions: []),
      body: SafeArea(
        child: fl_chat_ui.Chat(
          chatController: _chatController,
          currentUserId: _userId,
          onMessageSend: _onMessageSend,
          builders: builders,
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
  final colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];
  final anonNum = getAnonNum(authorId);
  return colors[(anonNum - 1) % colors.length];
}

Widget USTextMessageBuilder(
  BuildContext context,
  fl_chat_core.TextMessage message,
  int index, {
  required bool isSentByMe,
  fl_chat_core.MessageGroupStatus? groupStatus,
}) {
  // authorId별로 색상 매핑
  final colors = [
    Colors.blue[100],
    Colors.green[100],
    Colors.orange[100],
    Colors.purple[100],
    Colors.red[100],
    Colors.teal[100],
    Colors.amber[100],
  ];

  // authorId별로 고유한 색상 인덱스 생성
  final bgColor =
      isSentByMe
          ? Colors.blue[200]
          : colors[(getAnonNum(message.authorId) - 1) % colors.length];

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message.text, style: const TextStyle(fontSize: 16)),
  );
}
