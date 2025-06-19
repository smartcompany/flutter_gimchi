// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fl_chat_core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as fl_chat_ui;
import 'utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AnonymousChatPage extends StatefulWidget {
  const AnonymousChatPage({super.key});

  @override
  State<AnonymousChatPage> createState() => _AnonymousChatPageState();
}

class _AnonymousChatPageState extends State<AnonymousChatPage> {
  late final fl_chat_core.InMemoryChatController _chatController;
  final _firestore = FirebaseFirestore.instance;
  final String _roomId = 'anonymous_room';

  String _userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _chatController = fl_chat_core.InMemoryChatController(messages: const []);

    // Firestgore에서 메시지 스트림 구독
    _messagesStream.listen((messages) {
      // 메시지들을 InMemoryChatController에 설정
      _chatController.setMessages(messages);
    });
  }

  Stream<List<fl_chat_core.Message>> get _messagesStream {
    return _firestore
        .collection('chat_rooms')
        .doc(_roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
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
  }

  Future<void> _loadUserId() async {
    final userId = await getOrCreateUserId();
    setState(() {
      _userId = userId;
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('익명 대화방'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: fl_chat_ui.Chat(
          chatController: _chatController,
          currentUserId: _userId,
          onMessageSend: _onMessageSend,
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

    //_chatController.insertMessage(textMessage);

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
