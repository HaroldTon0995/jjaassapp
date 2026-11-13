part of 'admin_dashboard.dart';

extension _AdminHeader on _AdminDashboardState {
  Widget _buildDesktopHeader(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final adminName = user?.name ?? 'Admin';
    final adminInitial = adminName.isNotEmpty
        ? adminName[0].toUpperCase()
        : 'A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTabTitle(),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyColor,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Welcome back, ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$adminName!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _globalSearchController,
              onSubmitted: _handleGlobalSearch,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                color: AppTheme.navyColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search anything (e.g. users, orders, inventory)...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Realtime Notifications Popup Button
          _buildRealtimeNotificationsPopup(isDark),

          const SizedBox(width: 16),

          // Realtime Messages/Inbox Popup Button
          _buildRealtimeMessagesPopup(isDark),

          const SizedBox(width: 24),
          Container(height: 32, width: 1, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppTheme.navyColor,
                child: Text(
                  adminInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    adminName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  const Text(
                    'Administrator',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeNotificationsPopup(bool isDark) {
    final unreadCount = _notifications
        .where((n) => !(n['isRead'] as bool))
        .length;

    return Tooltip(
      message: 'System Notifications',
      child: InkWell(
        onTap: () => _showNotificationsDialog(isDark),
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Full Scrollable System Notifications Dialog with Back to Dashboard button
  void _showNotificationsDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final unreadCount = _notifications
                .where((n) => !(n['isRead'] as bool))
                .length;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'System Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        for (var n in _notifications) {
                          n['isRead'] = true;
                        }
                      });
                      setDialogState(() {});
                      Helpers.showSnackBar(
                        context,
                        'All notifications marked as read.',
                      );
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 14),
                    label: const Text(
                      'Mark All Read',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                height: 480,
                child: Column(
                  children: [
                    const Divider(height: 16),
                    Expanded(
                      child: _notifications.isEmpty
                          ? const Center(
                              child: Text(
                                'No system notifications yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: ListView.separated(
                                itemCount: _notifications.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final n = _notifications[i];
                                  final bool isRead = n['isRead'] as bool;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          (n['color'] as Color? ?? Colors.blue)
                                              .withValues(alpha: 0.12),
                                      child: Icon(
                                        n['icon'] as IconData? ??
                                            Icons.notifications,
                                        color:
                                            n['color'] as Color? ?? Colors.blue,
                                        size: 18,
                                      ),
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          n['title'] as String,
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w600
                                                : FontWeight.w900,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          n['time'] as String,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        n['body'] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isRead
                                              ? Colors.grey
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        n['isRead'] = true;
                                      });
                                      setDialogState(() {});
                                      if ((n['id'] as String).startsWith(
                                            'new_',
                                          ) ||
                                          (n['id'] as String).startsWith(
                                            'status_',
                                          )) {
                                        Navigator.of(ctx).pop();
                                        setState(() {
                                          _selectedTab = 1;
                                          _activeSidebarMenu = 1;
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRealtimeMessagesPopup(bool isDark) {
    return ListenableBuilder(
      listenable: ChatService.instance,
      builder: (context, _) {
        final unreadCount = ChatService.instance.getUnreadCount(
          'admin',
          'admin',
        );

        return Tooltip(
          message: 'Customer & Driver Messages',
          child: InkWell(
            onTap: () => _showInboxDialog(isDark),
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Customer & Driver Direct Communication Hub Dialog
  void _showInboxDialog(bool isDark, {String? targetConversationId}) {
    String? selectedConvoId = targetConversationId;
    final TextEditingController replyController = TextEditingController();
    final ScrollController convoScrollController = ScrollController();

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (convoScrollController.hasClients) {
          convoScrollController.animateTo(
            convoScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return ListenableBuilder(
              listenable: ChatService.instance,
              builder: (context, _) {
                final allMessages = ChatService.instance.messages;

                // Group by conversationId
                final Map<String, List<ChatMessageModel>> grouped = {};
                for (var m in allMessages) {
                  grouped.putIfAbsent(m.conversationId, () => []).add(m);
                }

                // Convert to conversation summaries
                final convos = grouped.entries.map((entry) {
                  final list = entry.value
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  final lastMsg = list.last;
                  final nonAdmin = list.reversed.firstWhere(
                    (m) => m.senderRole != 'admin',
                    orElse: () => list.last,
                  );
                  final isPartnerAdmin = nonAdmin.senderRole == 'admin';
                  final partnerName = isPartnerAdmin
                      ? (nonAdmin.receiverName ?? 'User')
                      : nonAdmin.senderName;
                  final rawRole = isPartnerAdmin
                      ? (nonAdmin.receiverRole ?? 'Customer')
                      : nonAdmin.senderRole;
                  final partnerRole = rawRole.isEmpty
                      ? 'Customer'
                      : rawRole[0].toUpperCase() +
                            rawRole.substring(1).toLowerCase();
                  final partnerId = isPartnerAdmin
                      ? nonAdmin.receiverId
                      : nonAdmin.senderId;
                  final unreadCount = list
                      .where((m) => !m.isRead && m.senderRole != 'admin')
                      .length;

                  final diff = DateTime.now().difference(lastMsg.createdAt);
                  String timeStr;
                  if (diff.inMinutes < 1) {
                    timeStr = 'Just now';
                  } else if (diff.inMinutes < 60) {
                    timeStr = '${diff.inMinutes}m ago';
                  } else if (diff.inHours < 24) {
                    timeStr = '${diff.inHours}h ago';
                  } else {
                    timeStr =
                        '${lastMsg.createdAt.month}/${lastMsg.createdAt.day}';
                  }

                  return {
                    'id': entry.key,
                    'conversationId': entry.key,
                    'orderId': lastMsg.orderId,
                    'sender': partnerName,
                    'role': partnerRole,
                    'partnerId': partnerId,
                    'snippet': lastMsg.message,
                    'time': timeStr,
                    'isRead': unreadCount == 0,
                    'unreadCount': unreadCount,
                    'messages': list,
                  };
                }).toList();

                convos.sort((a, b) {
                  final List<ChatMessageModel> aList =
                      a['messages'] as List<ChatMessageModel>;
                  final List<ChatMessageModel> bList =
                      b['messages'] as List<ChatMessageModel>;
                  final aTime = aList.isNotEmpty
                      ? aList.last.createdAt
                      : DateTime(2000);
                  final bTime = bList.isNotEmpty
                      ? bList.last.createdAt
                      : DateTime(2000);
                  return bTime.compareTo(aTime);
                });

                if (selectedConvoId == null && convos.isNotEmpty) {
                  selectedConvoId = convos.first['id'] as String;
                  ChatService.instance.markConversationAsRead(
                    selectedConvoId!,
                    'admin',
                  );
                }

                Map<String, dynamic>? selectedConvo;
                if (selectedConvoId != null) {
                  selectedConvo = convos.firstWhere(
                    (c) => c['id'] == selectedConvoId,
                    orElse: () => convos.isNotEmpty ? convos.first : {},
                  );
                }

                final orderProvider = Provider.of<OrderProvider>(
                  context,
                  listen: false,
                );
                OrderModel? convoOrder;
                if (selectedConvo != null && selectedConvo['orderId'] != null) {
                  for (var o in orderProvider.orders) {
                    if (o.id == selectedConvo['orderId']) {
                      convoOrder = o;
                      break;
                    }
                  }
                }
                final bool isTransactionLocked =
                    convoOrder != null &&
                    (convoOrder.orderStatus == OrderStatus.completed ||
                        convoOrder.orderStatus == OrderStatus.cancelled);

                return AlertDialog(
                  backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_chat_unread_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Customer & Driver Communication Hub',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.navyColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 760,
                    height: 520,
                    child: Column(
                      children: [
                        const Divider(height: 16),
                        Expanded(
                          child: Row(
                            children: [
                              // Left: Conversation List
                              Container(
                                width: 280,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                child: convos.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No active messages.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: convos.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, i) {
                                          final convo = convos[i];
                                          final isSelected =
                                              selectedConvo?['id'] ==
                                              convo['id'];
                                          final bool isRead =
                                              convo['isRead'] as bool? ?? true;
                                          final int unread =
                                              convo['unreadCount'] as int? ?? 0;
                                          final senderStr =
                                              (convo['sender'] as String? ??
                                              'U');
                                          final initial = senderStr.isNotEmpty
                                              ? senderStr[0].toUpperCase()
                                              : 'U';

                                          return ListTile(
                                            selected: isSelected,
                                            selectedTileColor: AppTheme
                                                .primaryColor
                                                .withValues(alpha: 0.08),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: AppTheme
                                                  .primaryColor
                                                  .withValues(alpha: 0.15),
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                            title: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    convo['sender'] as String,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: isRead
                                                          ? FontWeight.w600
                                                          : FontWeight.w900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (convo['role'] ==
                                                                    'Driver'
                                                                ? Colors.orange
                                                                : Colors.blue)
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    convo['role']?.toString() ??
                                                        '',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          convo['role'] ==
                                                              'Driver'
                                                          ? Colors
                                                                .orange
                                                                .shade800
                                                          : Colors
                                                                .blue
                                                                .shade800,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    convo['snippet'] as String,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                    ),
                                                  ),
                                                ),
                                                if (unread > 0)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              Colors.redAccent,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: Text(
                                                      '$unread',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            onTap: () {
                                              setDialogState(() {
                                                selectedConvoId =
                                                    convo['id'] as String;
                                              });
                                              ChatService.instance
                                                  .markConversationAsRead(
                                                    convo['id'] as String,
                                                    'admin',
                                                  );
                                              scrollToBottom();
                                            },
                                          );
                                        },
                                      ),
                              ),

                              // Right: Message Thread & Reply
                              Expanded(
                                child:
                                    selectedConvo == null ||
                                        selectedConvo.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Select a conversation to message.',
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: AppTheme
                                                      .primaryColor
                                                      .withValues(alpha: 0.1),
                                                  child: Text(
                                                    ((selectedConvo['sender']
                                                                as String?) ??
                                                            'U')[0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      selectedConvo['sender']
                                                              as String? ??
                                                          'User',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Role: ${selectedConvo['role'] ?? "User"}${selectedConvo['orderId'] != null ? " • Order ${selectedConvo['orderId']}" : ""}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 16),
                                            if (isTransactionLocked)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFEF3C7,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFFDE68A,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.lock_rounded,
                                                      size: 14,
                                                      color: Color(0xFFB45309),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Order ${convoOrder.id} is ${convoOrder.orderStatus.displayName} • Chat locked to Read-Only',
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF92400E,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            // Thread
                                            Expanded(
                                              child: ListView(
                                                controller:
                                                    convoScrollController,
                                                children: [
                                                  ...?((selectedConvo['messages']
                                                          as List<
                                                            ChatMessageModel
                                                          >?)
                                                      ?.map((msg) {
                                                        final bool isAdmin =
                                                            msg.senderRole ==
                                                            'admin';
                                                        final timeFormatted =
                                                            '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';
                                                        return Align(
                                                          alignment: isAdmin
                                                              ? Alignment
                                                                    .centerRight
                                                              : Alignment
                                                                    .centerLeft,
                                                          child: Container(
                                                            margin:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 4,
                                                                ),
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  10,
                                                                ),
                                                            constraints:
                                                                const BoxConstraints(
                                                                  maxWidth: 340,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isAdmin
                                                                  ? AppTheme
                                                                        .primaryColor
                                                                  : (isDark
                                                                        ? Colors
                                                                              .white10
                                                                        : const Color(
                                                                            0xFFF1F5F9,
                                                                          )),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  isAdmin
                                                                      ? 'Admin (You)'
                                                                      : msg.senderName,
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        isAdmin
                                                                        ? Colors
                                                                              .white70
                                                                        : AppTheme
                                                                              .primaryColor,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  msg.message,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        11.5,
                                                                    color:
                                                                        isAdmin
                                                                        ? Colors
                                                                              .white
                                                                        : (isDark
                                                                              ? Colors.white
                                                                              : Colors.black87),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .bottomRight,
                                                                  child: Text(
                                                                    timeFormatted,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          8,
                                                                      color:
                                                                          isAdmin
                                                                          ? Colors.white60
                                                                          : Colors.grey,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      })),
                                                ],
                                              ),
                                            ),

                                            // Reply Input or Transaction Locked Notice
                                            const SizedBox(height: 8),
                                            if (isTransactionLocked)
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: const [
                                                    Icon(
                                                      Icons
                                                          .lock_outline_rounded,
                                                      size: 14,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Transaction completed. Chat history is locked for audit records.',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          replyController,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText:
                                                            'Type reply to ${selectedConvo['sender']}...',
                                                        hintStyle:
                                                            const TextStyle(
                                                              fontSize: 11,
                                                            ),
                                                        isDense: true,
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onSubmitted: (text) async {
                                                        final clean = text
                                                            .trim();
                                                        if (clean.isEmpty) {
                                                          return;
                                                        }
                                                        replyController.clear();
                                                        await ChatService.instance.sendMessage(
                                                          conversationId:
                                                              selectedConvo!['conversationId']
                                                                  as String,
                                                          orderId:
                                                              selectedConvo['orderId']
                                                                  as String?,
                                                          senderId: 'admin',
                                                          senderName:
                                                              'Station Admin',
                                                          senderRole: 'admin',
                                                          receiverId:
                                                              selectedConvo['partnerId']
                                                                  as String?,
                                                          receiverName:
                                                              selectedConvo['sender']
                                                                  as String?,
                                                          receiverRole:
                                                              (selectedConvo['role']
                                                                          as String? ??
                                                                      'customer')
                                                                  .toLowerCase(),
                                                          text: clean,
                                                        );
                                                        scrollToBottom();
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      final text =
                                                          replyController.text
                                                              .trim();
                                                      if (text.isEmpty) return;
                                                      replyController.clear();
                                                      await ChatService.instance.sendMessage(
                                                        conversationId:
                                                            selectedConvo!['conversationId']
                                                                as String,
                                                        orderId:
                                                            selectedConvo['orderId']
                                                                as String?,
                                                        senderId: 'admin',
                                                        senderName:
                                                            'Station Admin',
                                                        senderRole: 'admin',
                                                        receiverId:
                                                            selectedConvo['partnerId']
                                                                as String?,
                                                        receiverName:
                                                            selectedConvo['sender']
                                                                as String?,
                                                        receiverRole:
                                                            (selectedConvo['role']
                                                                        as String? ??
                                                                    'customer')
                                                                .toLowerCase(),
                                                        text: text,
                                                      );
                                                      scrollToBottom();
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppTheme.primaryColor,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 10,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.send_rounded,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.navyColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Back to Dashboard',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
