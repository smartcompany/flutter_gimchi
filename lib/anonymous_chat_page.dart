import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'utils.dart'; // Assuming this file contains getOrCreateUserId function

class AnonymousChatPage extends StatefulWidget {
  const AnonymousChatPage({super.key});

  @override
  AnonymousChatPageState createState() => AnonymousChatPageState();
}

class AnonymousChatPageState extends State<AnonymousChatPage> {
  late final InMemoryChatController _chatController;

  String _userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _chatController = InMemoryChatController(messages: const []);

    // Foreground 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      print('Foreground message: ${msg.notification?.title}');
    });
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
  }

  // Background 메시지 핸들러
  Future<void> _bgHandler(RemoteMessage msg) async {
    print('Background message: ${msg.notification?.body}');
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
        child: Chat(
          chatController: _chatController,
          currentUserId: _userId,
          onMessageSend: (text) {
            _chatController.insertMessage(
              TextMessage(
                // Better to use UUID or similar for the ID - IDs must be unique
                id: '${Random().nextInt(1000) + 1}',
                authorId: _userId,
                createdAt: DateTime.now().toUtc(),
                text: text,
              ),
            );
          },
          resolveUser: (UserID id) async {
            return User(id: id, name: 'John Doe');
          },
        ),
      ),
    );
  }
}
