import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/chat_message_model.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/chat_service.dart';

class RealtimeChatModal extends StatefulWidget {
  final String? initialConversationId;
  final String? initialOrderId;

  const RealtimeChatModal({
    super.key,
    this.initialConversationId,
    this.initialOrderId,
  });

  static void show(
    BuildContext context, {
    String? initialConversationId,
    String? initialOrderId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RealtimeChatModal(
        initialConversationId: initialConversationId,
        initialOrderId: initialOrderId,
      ),
    );
  }

  @override
  State<RealtimeChatModal> createState() => _RealtimeChatModalState();
}

class _RealtimeChatModalState extends State<RealtimeChatModal> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentConversationId;
  String? _currentOrderId;
  String _currentPartnerName = 'Station Admin';
  String _currentPartnerRole = 'admin';

  @override
  void initState() {
    super.initState();
    ChatService.instance.init();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final userId = user?.id ?? 'customer';

    if (widget.initialConversationId != null &&
        widget.initialConversationId!.isNotEmpty) {
      _currentConversationId = widget.initialConversationId!;
      _currentOrderId = widget.initialOrderId;
    } else {
      _currentConversationId = 'support_$userId';
      _currentPartnerName = 'Station Admin';
      _currentPartnerRole = 'admin';
    }

    _markRead();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markRead() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.currentUser?.role.name ?? 'customer';
    ChatService.instance.markConversationAsRead(_currentConversationId, role);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final senderId = user?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final senderName = user?.name ?? 'Customer';
    final senderRole = user?.role.name ?? 'customer';

    _textController.clear();

    await ChatService.instance.sendMessage(
      conversationId: _currentConversationId,
      orderId: _currentOrderId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      receiverId: _currentPartnerRole == 'admin' ? 'admin' : null,
      receiverName: _currentPartnerName,
      receiverRole: _currentPartnerRole,
      text: text,
    );

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final userRole = user?.role.name ?? 'customer';
    final userId = user?.id ?? '';

    // Collect available channels for this user:
    // 1. Station Admin Support channel (persistent)
    // 2. Active Order Channels (auto-closing when completed/cancelled)
    final channels = <Map<String, dynamic>>[];

    // Support Desk Channel
    channels.add({
      'id': 'support_$userId',
      'title': userRole == 'driver' ? 'Station Dispatch Desk' : 'Station Admin Support',
      'partnerName': 'Station Admin',
      'partnerRole': 'admin',
      'orderId': null,
      'isOrder': false,
    });

    if (userRole == 'customer') {
      final activeOrders = orderProvider.orders.where((o) {
        return (o.customerId == userId || o.customerName == user?.name) &&
            o.orderStatus != OrderStatus.completed &&
            o.orderStatus != OrderStatus.cancelled;
      }).toList();

      for (var o in activeOrders) {
        final driverLabel = o.driverName != null && o.driverName!.isNotEmpty
            ? o.driverName!
            : 'Assigned Driver';
        channels.add({
          'id': 'order_${o.id}',
          'title': 'Delivery ${o.id}',
          'partnerName': driverLabel,
          'partnerRole': 'driver',
          'orderId': o.id,
          'isOrder': true,
          'order': o,
        });
      }
    } else if (userRole == 'driver') {
      final assignedJobs = orderProvider.orders.where((o) {
        return (o.driverId == userId || o.driverName == user?.name) &&
            o.orderStatus != OrderStatus.completed &&
            o.orderStatus != OrderStatus.cancelled;
      }).toList();

      for (var o in assignedJobs) {
        channels.add({
          'id': 'order_${o.id}',
          'title': 'Customer Order ${o.id}',
          'partnerName': o.customerName,
          'partnerRole': 'customer',
          'orderId': o.id,
          'isOrder': true,
          'order': o,
        });
      }
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 36,
        vertical: isNarrow ? 16 : 28,
      ),
      child: Container(
        width: 720,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.navyColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_chat_unread_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPartnerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _currentOrderId != null
                                  ? 'Active Delivery Chat • ${_currentOrderId!}'
                                  : 'Station Live Direct Channel',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Channel Selector Tabs
            if (channels.length > 1)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: channels.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final ch = channels[i];
                    final isSelected = _currentConversationId == ch['id'];
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ch['isOrder'] == true
                                ? Icons.local_shipping_rounded
                                : Icons.support_agent_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : AppTheme.navyColor,
                          ),
                          const SizedBox(width: 5),
                          Text(ch['title'] as String),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _currentConversationId = ch['id'] as String;
                          _currentPartnerName = ch['partnerName'] as String;
                          _currentPartnerRole = ch['partnerRole'] as String;
                          _currentOrderId = ch['orderId'] as String?;
                        });
                        _markRead();
                      },
                    );
                  },
                ),
              ),

            // Message Stream Area
            Expanded(
              child: ListenableBuilder(
                listenable: ChatService.instance,
                builder: (context, _) {
                  final messages = ChatService.instance
                      .getConversationMessages(_currentConversationId);

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No messages in this channel yet.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Say hi to start the conversation!',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final bool isMe = msg.senderId == userId ||
                          msg.senderRole == userRole &&
                              msg.senderName == (user?.name ?? '');

                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),

            // Bottom Typing Bar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Type your message to $_currentPartnerName...',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe) {
    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(2),
            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(14),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? 'You' : msg.senderName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white70 : AppTheme.navyColor,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white24
                        : (msg.senderRole == 'admin'
                            ? Colors.purple.withValues(alpha: 0.15)
                            : (msg.senderRole == 'driver'
                                ? Colors.orange.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15))),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    msg.senderRole.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isMe
                          ? Colors.white
                          : (msg.senderRole == 'admin'
                              ? Colors.purple
                              : (msg.senderRole == 'driver'
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg.message,
              style: TextStyle(
                fontSize: 12.5,
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 8.5,
                color: isMe ? Colors.white60 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
