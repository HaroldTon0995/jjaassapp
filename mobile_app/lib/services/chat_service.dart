import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/chat_message_model.dart';

class ChatService extends ChangeNotifier {
  static final ChatService instance = ChatService._();
  ChatService._();

  final List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  StreamSubscription? _streamSub;
  Timer? _pollingTimer;
  bool _initialized = false;

  bool get isSupabaseConfigured => AppConstants.isSupabaseConfigured;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _seedInitialMockMessages();

    if (isSupabaseConfigured) {
      _listenToRealtimeStream();
      _fetchDirectMessages();
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _fetchDirectMessages(silent: true);
      });
    }
  }

  void _seedInitialMockMessages() {
    if (_messages.isNotEmpty) return;
    final now = DateTime.now();
    _messages.addAll([
      ChatMessageModel(
        id: 'msg_seed_1',
        conversationId: 'support_haroldcristonborbo',
        senderId: 'usr_haroldcristonborbo',
        senderName: 'haroldcristonborbo',
        senderRole: 'customer',
        receiverId: 'admin',
        receiverName: 'Station Admin',
        receiverRole: 'admin',
        message: 'Hi Admin, can you schedule delivery every Monday for our household?',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      ChatMessageModel(
        id: 'msg_seed_2',
        conversationId: 'support_tonton_driver',
        senderId: 'usr_tonton_driver',
        senderName: 'Tonton Borbo',
        senderRole: 'driver',
        receiverId: 'admin',
        receiverName: 'Station Admin',
        receiverRole: 'admin',
        message: 'Traffic along Malilipot highway, will finish delivery soon.',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      ChatMessageModel(
        id: 'msg_seed_3',
        conversationId: 'support_carl_customer',
        senderId: 'usr_carl_customer',
        senderName: 'Carl Customer',
        senderRole: 'customer',
        receiverId: 'admin',
        receiverName: 'Station Admin',
        receiverRole: 'admin',
        message: 'Thank you! The purified water quality is very clean and crisp.',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  Future<void> _fetchDirectMessages({bool silent = false}) async {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      final List<dynamic> res = await client
          .from('chat_messages')
          .select()
          .order('created_at', ascending: true);
      final fetched = res
          .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
          .toList();

      if (fetched.isNotEmpty) {
        bool changed = fetched.length != _messages.length;
        _messages.clear();
        _messages.addAll(fetched);
        if (changed || !silent) {
          notifyListeners();
        }
      }
    } catch (_) {
      // Supabase table chat_messages might not exist yet; silently retain local messages
    }
  }

  void _listenToRealtimeStream() {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      _streamSub = client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .listen((data) {
            final fetched = data
                .map((m) => ChatMessageModel.fromJson(m))
                .toList();
            if (fetched.isNotEmpty) {
              _messages.clear();
              _messages.addAll(fetched);
              notifyListeners();
            }
          }, onError: (err) {
            debugPrint('Chat Realtime stream error: $err');
          });
    } catch (e) {
      debugPrint('Chat Realtime stream setup failed: $e');
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    String? orderId,
    required String senderId,
    required String senderName,
    required String senderRole,
    String? receiverId,
    String? receiverName,
    String? receiverRole,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final newMsg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      orderId: orderId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverRole: receiverRole,
      message: clean,
      createdAt: DateTime.now(),
    );

    _messages.add(newMsg);
    notifyListeners();

    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client.from('chat_messages').insert(newMsg.toJson());
      } catch (e) {
        debugPrint('Supabase insert chat message failed: $e');
      }
    }
  }

  List<ChatMessageModel> getConversationMessages(String conversationId) {
    return _messages
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int getUnreadCount(String currentUserId, String currentRole) {
    return _messages.where((m) {
      if (m.isRead) return false;
      if (m.senderRole == currentRole) return false;
      if (currentRole == 'admin') return true;
      if (m.receiverId == currentUserId ||
          m.conversationId.contains(currentUserId) ||
          m.senderId == currentUserId) {
        return true;
      }
      return false;
    }).length;
  }

  void markConversationAsRead(String conversationId, String currentRole) {
    bool updated = false;
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].conversationId == conversationId &&
          _messages[i].senderRole != currentRole &&
          !_messages[i].isRead) {
        _messages[i] = ChatMessageModel(
          id: _messages[i].id,
          conversationId: _messages[i].conversationId,
          orderId: _messages[i].orderId,
          senderId: _messages[i].senderId,
          senderName: _messages[i].senderName,
          senderRole: _messages[i].senderRole,
          receiverId: _messages[i].receiverId,
          receiverName: _messages[i].receiverName,
          receiverRole: _messages[i].receiverRole,
          message: _messages[i].message,
          isRead: true,
          createdAt: _messages[i].createdAt,
        );
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
      if (isSupabaseConfigured) {
        try {
          final client = Supabase.instance.client;
          client
              .from('chat_messages')
              .update({'is_read': true})
              .eq('conversation_id', conversationId)
              .neq('sender_role', currentRole)
              .catchError((_) {});
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}
