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
  RealtimeChannel? _broadcastChannel;
  Timer? _pollingTimer;
  bool _initialized = false;

  bool get isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  void init() {
    if (_initialized) return;
    _initialized = true;

    if (isSupabaseConfigured) {
      _initBroadcastChannel();
      _listenToRealtimeStream();
      _fetchDirectMessages();
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _fetchDirectMessages(silent: true);
      });
    }
  }

  void _initBroadcastChannel() {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      _broadcastChannel = client.channel('jjaass_chat_room');
      _broadcastChannel!
          .onBroadcast(
            event: 'new_message',
            callback: (payload) {
              try {
                final msg = ChatMessageModel.fromJson(
                    Map<String, dynamic>.from(payload));
                if (msg.id.startsWith('msg_seed_')) return;
                final exists = _messages.any((m) => m.id == msg.id);
                if (!exists) {
                  _messages.add(msg);
                  _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('Chat broadcast parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Chat broadcast channel init error: $e');
    }
  }

  bool _upsertMessages(List<ChatMessageModel> fetched) {
    bool changed = false;
    for (final m in fetched) {
      if (m.id.startsWith('msg_seed_')) continue;
      final idx = _messages.indexWhere((existing) => existing.id == m.id);
      if (idx == -1) {
        _messages.add(m);
        changed = true;
      } else if (_messages[idx].isRead != m.isRead) {
        _messages[idx] = m;
        changed = true;
      }
    }
    if (changed) {
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return changed;
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

      final changed = _upsertMessages(fetched);
      if (changed || !silent) {
        notifyListeners();
      }
    } catch (_) {
      // Table may not exist yet in user's Supabase project, silently retain in-memory messages
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
            if (_upsertMessages(fetched)) {
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
      // 1. Instant peer-to-peer WebSocket broadcast
      try {
        _broadcastChannel?.sendBroadcastMessage(
          event: 'new_message',
          payload: newMsg.toJson(),
        );
      } catch (e) {
        debugPrint('Supabase broadcast send failed: $e');
      }

      // 2. Persistent storage in Supabase DB
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
          m.conversationId.contains(currentUserId)) {
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
    _broadcastChannel?.unsubscribe();
    _pollingTimer?.cancel();
    super.dispose();
  }
}
