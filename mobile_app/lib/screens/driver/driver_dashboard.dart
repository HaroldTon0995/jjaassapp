import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../services/ai_support_service.dart';
import '../../services/navigation_launcher.dart';
import '../../services/chat_service.dart';
import '../../widgets/realtime_chat_modal.dart';
import '../../widgets/water_widgets.dart';
import '../../widgets/google_map_widget.dart';
import 'driver_styles.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _selectedTab = 0;
  int _activeSidebarMenu = 0;

  // AI Chat States
  int _supportSubTab = 0; // 0 = AquaBot AI Guide, 1 = Station Admin Desk
  final List<Map<String, dynamic>> _supportMessages = [
    {
      'sender': 'AquaBot',
      'message':
          "Hello! I'm **AquaBot 💧**, your JJAASS Water Market driver dispatch assistant.\n\nTap any topic in the **Quick Inquiry Guide** above, or type your question below for instant delivery, route, or gallon collection guidance!",
    },
  ];
  final TextEditingController _supportInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _faqScrollController = ScrollController();
  bool _isChatLoading = false;

  // Station Admin Direct Chat States
  final TextEditingController _adminChatInputController = TextEditingController();
  final ScrollController _adminChatScrollController = ScrollController();

  // Settings controller
  final TextEditingController _plateNoController = TextEditingController(
    text: 'ABC-1234',
  );
  String _selectedVehicleType = 'Motorcycle with Rack';
  String? _selectedActiveOrderId;

  // Gallon Collection search controller
  final TextEditingController _gallonSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ChatService.instance.init();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _supportInputController.dispose();
    _chatScrollController.dispose();
    _faqScrollController.dispose();
    _adminChatInputController.dispose();
    _adminChatScrollController.dispose();
    _plateNoController.dispose();
    _gallonSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await Future.wait([
        _apiService.getDriverDashboardData(),
        orderProvider.fetchSupabaseOrders(silent: true),
        orderProvider.fetchSupabaseInventory(silent: true),
      ]);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to load driver data.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _acceptDeliveryJob(OrderModel order) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    final success = await orderProvider.acceptJob(
      orderId: order.id,
      driverId: user?.id ?? '',
      driverName: user?.name ?? 'Driver',
    );

    if (success) {
      if (mounted) {
        if (order.isCollectionJob) {
          setState(() {
            _selectedTab = 2; // Auto navigate to Gallon Collection Tab
            _activeSidebarMenu = 2;
          });
          Helpers.showSnackBar(
            context,
            'Weekly Gallon Collection Task accepted! You can now log collected containers below.',
          );
        } else {
          setState(() {
            _selectedActiveOrderId = order.id;
            _selectedTab = 1; // Auto navigate to GPS Map Tab
            _activeSidebarMenu = 1;
          });
          Helpers.showSnackBar(
            context,
            'Job ${order.id} accepted! Added to active deliveries.',
          );
        }
      }
    } else {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Could not accept order ${order.id}.',
          isError: true,
        );
      }
    }
  }

  void _confirmAndAcceptAllAssignedJobs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final driverName = user?.name ?? '';
    final driverEmail = user?.email ?? '';
    final availableJobs = orderProvider.getAvailableDriverJobs(
      driverId,
      driverName: driverName,
      driverEmail: driverEmail,
    );

    if (availableJobs.isEmpty) {
      Helpers.showSnackBar(
        context,
        'No available job invitations to accept.',
      );
      return;
    }

    final totalOrderAmount = availableJobs.fold<double>(
      0.0,
      (sum, job) => sum + job.totalAmount,
    );

    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.playlist_add_check_circle_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Accept All Jobs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accept all ${availableJobs.length} available delivery job invitation${availableJobs.length > 1 ? 's' : ''}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Deliveries:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      Text('${availableJobs.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Transaction Value:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      Text(
                        '₱${totalOrderAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Accept All'),
          ),
        ],
      ),
    );

    if (shouldAccept == true) {
      final count = await orderProvider.acceptAllAssignedJobs(
        driverId: driverId,
        driverName: user?.name ?? 'Driver',
        driverEmail: driverEmail,
      );

      if (mounted) {
        final activeJobs = orderProvider.getActiveDriverJobs(driverId);
        setState(() {
          if (activeJobs.isNotEmpty) {
            _selectedActiveOrderId = activeJobs.first.id;
          }
        });
        Helpers.showSnackBar(
          context,
          'Successfully accepted $count delivery job${count > 1 ? 's' : ''}!',
        );
      }
    }
  }

  void _completeActiveJob(OrderModel activeOrder) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';

    final success = await orderProvider.completeJob(
      orderId: activeOrder.id,
      driverId: driverId,
    );

    if (success && mounted) {
      final remainingActive = orderProvider.getActiveDriverJobs(driverId);
      setState(() {
        if (remainingActive.isEmpty) {
          _selectedActiveOrderId = null;
          _selectedTab = 0; // Go back to dashboard when all jobs complete
          _activeSidebarMenu = 0;
        } else {
          _selectedActiveOrderId = remainingActive.first.id;
        }
      });
      Helpers.showSnackBar(
        context,
        'Delivery #${activeOrder.id} marked as Delivered! (${remainingActive.length} remaining)',
      );
    }
  }

  void _sendSupportMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isChatLoading) return; // Prevent multiple requests at once
    final userQuery = text.trim();

    setState(() {
      _supportMessages.add({'sender': 'Driver', 'message': userQuery});
      _supportInputController.clear();
      _isChatLoading = true;
      _supportMessages.add({'sender': 'AquaBot', 'message': 'Thinking...'});
    });

    _scrollToBottom();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    try {
      final response = await AiSupportService.getChatResponse(
        query: userQuery,
        isDriver: true,
        isAdmin: false,
        userId: user?.id ?? '',
        userName: user?.name ?? 'Driver',
        orderProvider: orderProvider,
      );

      if (mounted) {
        setState(() {
          if (_supportMessages.isNotEmpty && _supportMessages.last['message'] == 'Thinking...') {
            _supportMessages.removeLast();
          }
          _supportMessages.add({'sender': 'AquaBot', 'message': response});
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_supportMessages.isNotEmpty && _supportMessages.last['message'] == 'Thinking...') {
            _supportMessages.removeLast();
          }
          _supportMessages.add({
            'sender': 'AquaBot',
            'message': 'Sorry, I encountered an issue retrieving a response. Please check your connection and try again.'
          });
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendAdminChatMessage([String? manualText]) async {
    final text = (manualText ?? _adminChatInputController.text).trim();
    if (text.isEmpty) return;
    _adminChatInputController.clear();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final driverId = user?.id ?? 'driver';
    final driverName = user?.name ?? 'Driver';

    await ChatService.instance.sendMessage(
      conversationId: 'support_$driverId',
      senderId: driverId,
      senderName: driverName,
      senderRole: 'driver',
      receiverId: 'admin',
      receiverName: 'Station Admin',
      receiverRole: 'admin',
      text: text,
    );

    _scrollAdminChatToBottom();
  }

  void _scrollAdminChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_adminChatScrollController.hasClients) {
        _adminChatScrollController.animateTo(
          _adminChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 1100;
    const isDark = false;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      drawer: (!isWide)
          ? Drawer(
              backgroundColor: Colors.white,
              child: _buildSidebar(isDark, isDrawer: true),
            )
          : null,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: AppTheme.navyColor,
              foregroundColor: Colors.white,
              elevation: 2,
              titleSpacing: 8,
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTabTitle(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'JJAASS Water Market • Driver',
                          style: TextStyle(
                            color: Color(0xFFBFDBFE),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ListenableBuilder(
                  listenable: ChatService.instance,
                  builder: (context, _) {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final userId = auth.currentUser?.id ?? '';
                    final unread = ChatService.instance.getUnreadCount(userId, 'driver');
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Dispatch & Customer Live Chat',
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                          onPressed: () => RealtimeChatModal.show(context),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  '$unread',
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
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.sync_rounded, color: Colors.white),
                  onPressed: _loadDashboardData,
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.navyColor,
                    ),
                  )
                : Column(
                    children: [
                      if (isWide) _buildDesktopHeader(isDark),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppTheme.navyColor,
                          onRefresh: _loadDashboardData,
                          child: _buildSelectedTabContent(
                            isDark,
                            media.size.width,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFCBD5E1),
            width: 1.0,
          ),
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
                    '${auth.currentUser?.name ?? "Driver"}!',
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
            child: const TextField(
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: AppTheme.navyColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search routes, orders...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 19,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.navyColor,
            ),
          ),
          ListenableBuilder(
            listenable: ChatService.instance,
            builder: (context, _) {
              final userId = auth.currentUser?.id ?? '';
              final unread = ChatService.instance.getUnreadCount(userId, 'driver');
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Dispatch & Customer Live Chat',
                    onPressed: () => RealtimeChatModal.show(context),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            '$unread',
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
              );
            },
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              setState(() {
                _selectedTab = 5;
                _activeSidebarMenu = 5;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: AppTheme.navyColor,
              child: Text(
                (auth.currentUser?.name ?? 'D').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 0:
        return 'Driver Dispatch Dashboard';
      case 1:
        return 'Live GPS Navigation Map';
      case 2:
        return 'Gallon Collection';
      case 3:
        return 'Trip Duty History';
      case 4:
        return _supportSubTab == 1 ? 'Station Admin Desk' : 'AI Support Dispatch';
      case 5:
        return 'Vehicle & Profile Settings';
      default:
        return 'Driver Dashboard';
    }
  }

  Widget _buildSidebar(bool isDark, {bool isDrawer = false}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';

    final menuItems = [
      {'title': 'Dashboard', 'icon': Icons.home_rounded, 'tab': 0},
      {'title': 'Deliveries Map', 'icon': Icons.map_rounded, 'tab': 1},
      {'title': 'Gallon Collection', 'icon': Icons.assignment_return_rounded, 'tab': 2},
      {'title': 'Duty History', 'icon': Icons.history_rounded, 'tab': 3},
      {'title': 'Station Admin Desk', 'icon': Icons.support_agent_rounded, 'tab': 4, 'subTab': 1},
      {'title': 'AI Chat Support', 'icon': Icons.smart_toy_rounded, 'tab': 4, 'subTab': 0},
      {'title': 'Settings', 'icon': Icons.settings_rounded, 'tab': 5},
    ];

    return Container(
      width: 260,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              left: 20,
              top: 24,
              right: 20,
              bottom: 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const WaterDropletLogo(size: 40),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JJAASS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navyColor,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      'WATER MARKET',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: ChatService.instance,
              builder: (context, _) {
                final unreadDesk = driverId.isNotEmpty
                    ? ChatService.instance
                        .getConversationMessages('support_$driverId')
                        .where((m) => !m.isRead && m.senderRole != 'driver')
                        .length
                    : 0;

                return ListView.builder(
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    final targetTab = item['tab'] as int;
                    final targetSubTab = item['subTab'] as int?;
                    final bool isSelected = _activeSidebarMenu == index ||
                        (_selectedTab == targetTab &&
                            (targetSubTab == null || _supportSubTab == targetSubTab));

                    final badge = item['title'] == 'Station Admin Desk' ? unreadDesk : null;

                    return _SidebarItemTile(
                      icon: item['icon'] as IconData,
                      title: item['title'] as String,
                      isSelected: isSelected,
                      badgeCount: badge,
                      onTap: () {
                        setState(() {
                          _activeSidebarMenu = index;
                          _selectedTab = targetTab;
                          if (targetSubTab != null) {
                            _supportSubTab = targetSubTab;
                          }
                        });
                        if (targetSubTab == 1 && driverId.isNotEmpty) {
                          ChatService.instance.markConversationAsRead('support_$driverId', 'driver');
                          _scrollAdminChatToBottom();
                        }
                        if (isDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          _SidebarItemTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            isSelected: false,
            textColor: const Color(0xFFDC2626),
            onTap: _handleLogout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent(bool isDark, double width) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(isDark, width);
      case 1:
        return _buildDeliveriesMapTab(isDark);
      case 2:
        return _buildGallonCollectionTab(isDark);
      case 3:
        return _buildDutyHistoryTab(isDark);
      case 4:
        return _buildSupportTab(isDark);
      case 5:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }

  // TAB 0: DISPATCH DASHBOARD / OVERVIEW
  Widget _buildOverviewTab(bool isDark, double width) {
    final isDesktop = width >= 1100;
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final driverName = user?.name ?? '';
    final driverEmail = user?.email ?? '';

    final activeJobs = orderProvider.getActiveDriverJobs(
      driverId,
      driverName: driverName,
      driverEmail: driverEmail,
    );
    final availableJobs = orderProvider.getAvailableDriverJobs(
      driverId,
      driverName: driverName,
      driverEmail: driverEmail,
    );
    final completedJobs = orderProvider.getDriverCompletedJobs(driverId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Operational Stat Cards (Zero overflow on mobile)
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'Active',
                  '${activeJobs.length}',
                  Icons.directions_bike_rounded,
                  const Color(0xFF2563EB),
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactStatCard(
                  'Invitations',
                  '${availableJobs.length}',
                  Icons.notifications_active_rounded,
                  const Color(0xFFD97706),
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactStatCard(
                  'Completed',
                  '${completedJobs.length}',
                  Icons.check_circle_rounded,
                  const Color(0xFF059669),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(children: [_buildJobsCard(isDark)]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildQuickActionsCard(isDark),
                      const SizedBox(height: 16),
                      _buildMiniAiSupportCard(isDark),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildJobsCard(isDark),
                const SizedBox(height: 16),
                _buildQuickActionsCard(isDark),
                const SizedBox(height: 16),
                _buildMiniAiSupportCard(isDark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsCard(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final driverName = user?.name ?? '';
    final driverEmail = user?.email ?? '';

    final availableJobs = orderProvider.getAvailableDriverJobs(
      driverId,
      driverName: driverName,
      driverEmail: driverEmail,
    );
    final activeJobs = orderProvider.getActiveDriverJobs(
      driverId,
      driverName: driverName,
      driverEmail: driverEmail,
    );

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: DriverDecorations.card(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Available Job Invitations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (availableJobs.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _confirmAndAcceptAllAssignedJobs,
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(
                    'Accept All (${availableJobs.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (availableJobs.isEmpty && activeJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No job invitations at the moment.')),
            )
          else ...[
            if (activeJobs.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_bike_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Deliveries: ${activeJobs.length} In Progress',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            activeJobs.length == 1
                                ? 'Destination: ${activeJobs.first.deliveryAddress}'
                                : 'Next stop: ${activeJobs.first.customerName} • ${activeJobs.length - 1} more order(s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => setState(() {
                        _selectedTab = 1;
                        _activeSidebarMenu = 1;
                      }),
                      child: const Text(
                        'View Map',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableJobs.length,
              itemBuilder: (context, index) {
                final job = availableJobs[index];
                final orderTotal = job.totalAmount;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header: Icon + Customer Name & Ref + Price Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (job.isCollectionJob ? const Color(0xFF10B981) : AppTheme.primaryColor)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                job.isCollectionJob ? Icons.assignment_return_rounded : Icons.location_on_rounded,
                                color: job.isCollectionJob ? const Color(0xFF059669) : AppTheme.primaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'Ref #${job.id}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: job.isCollectionJob
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : (job.paymentMethod == 'GCash'
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFFEF3C7)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: job.isCollectionJob
                                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                      : (job.paymentMethod == 'GCash'
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFFFCD34D)),
                                ),
                              ),
                              child: Text(
                                job.isCollectionJob
                                    ? 'Collection'
                                    : (job.paymentMethod == 'GCash'
                                        ? '₱${orderTotal.toStringAsFixed(2)} • Paid'
                                        : '₱${orderTotal.toStringAsFixed(2)} • COD'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  color: job.isCollectionJob
                                      ? const Color(0xFF047857)
                                      : (job.paymentMethod == 'GCash'
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFFB45309)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Assigned Directly Badge
                        if (job.orderStatus == OrderStatus.assigned &&
                            (job.driverId == driverId ||
                             (driverName.isNotEmpty && job.driverName != null && job.driverName!.trim().toLowerCase() == driverName.trim().toLowerCase()) ||
                             (driverEmail.isNotEmpty && (job.driverId == driverEmail || (job.driverName != null && job.driverName!.toLowerCase().contains(driverEmail.split('@').first))))))
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 13, color: Color(0xFFD97706)),
                                SizedBox(width: 4),
                                Text(
                                  'Assigned directly to you by Admin',
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Delivery Address
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  job.deliveryAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badges Row (Items & Target using Wrap so it NEVER overflows!)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Items: ${job.itemsSummary} • Dist: ${job.distance}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (job.isCollectionJob)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.assignment_return_rounded, size: 12, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Weekly Collection • ${(job.borrowedSlimCount ?? 0) > 0 ? '${job.borrowedSlimCount} Slim ' : ''}${(job.borrowedRoundCount ?? 0) > 0 ? '${job.borrowedRoundCount} Round ' : ''}Target',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (job.isBorrowingContainers || (job.borrowedSlimCount ?? 0) > 0 || (job.borrowedRoundCount ?? 0) > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 11, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Borrowing: ${_formatBorrowSummary(job)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '💧 Refill (Customer Owns Jugs)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: job.isCollectionJob ? const Color(0xFF10B981) : AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => _acceptDeliveryJob(job),
                            icon: Icon(
                              job.isCollectionJob ? Icons.assignment_turned_in_rounded : Icons.check_circle_rounded,
                              size: 16,
                            ),
                            label: Text(
                              job.isCollectionJob ? 'Accept Task' : 'Accept Job',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';

    final actions = [
      {
        'title': 'Deliveries Map',
        'icon': Icons.map_rounded,
        'color': AppTheme.navyColor,
        'tab': 1,
      },
      {
        'title': 'Gallon Collection',
        'icon': Icons.assignment_return_rounded,
        'color': const Color(0xFF0284C7),
        'tab': 2,
      },
      {
        'title': 'Duty History',
        'icon': Icons.history_rounded,
        'color': AppTheme.primaryColor,
        'tab': 3,
      },
      {
        'title': 'Driver Support',
        'icon': Icons.smart_toy_rounded,
        'color': AppTheme.accentColor,
        'tab': 4,
        'subTab': 0,
      },
      {
        'title': 'Message Admin',
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFFD97706),
        'tab': 4,
        'subTab': 1,
      },
      {
        'title': 'Settings',
        'icon': Icons.settings_rounded,
        'color': const Color(0xFF059669),
        'tab': 5,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: DriverDecorations.card(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyColor,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, index) {
              final act = actions[index];
              final color = act['color'] as Color;
              final isMessageAdmin = act['title'] == 'Message Admin';

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTab = act['tab'] as int;
                    if (act['title'] == 'Message Admin') {
                      _activeSidebarMenu = 4;
                    } else if (act['title'] == 'Driver Support') {
                      _activeSidebarMenu = 5;
                    } else if (act['title'] == 'Settings') {
                      _activeSidebarMenu = 6;
                    } else {
                      _activeSidebarMenu = act['tab'] as int;
                    }
                    if (act.containsKey('subTab')) {
                      _supportSubTab = act['subTab'] as int;
                    }
                  });
                  if (act['subTab'] == 1 && driverId.isNotEmpty) {
                    ChatService.instance.markConversationAsRead('support_$driverId', 'driver');
                    _scrollAdminChatToBottom();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            act['icon'] as IconData,
                            color: color,
                            size: 24,
                          ),
                          if (isMessageAdmin && driverId.isNotEmpty)
                            AnimatedBuilder(
                              animation: ChatService.instance,
                              builder: (context, _) {
                                final unread = ChatService.instance
                                    .getConversationMessages('support_$driverId')
                                    .where((m) => !m.isRead && m.senderRole != 'driver')
                                    .length;
                                if (unread == 0) return const SizedBox.shrink();
                                return Positioned(
                                  top: -4,
                                  right: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        act['title'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAiSupportCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: DriverDecorations.card(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'AI Chat Support',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(
                color: AppTheme.secondaryColor.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppTheme.navyColor,
                  child: Icon(Icons.adb_rounded, size: 13, color: Colors.white),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AquaBot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hello! I\'m AquaBot. How can I help you today?',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.bodyText,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _supportInputController,
                    textAlignVertical: TextAlignVertical.center,
                    onSubmitted: (val) {
                      _sendSupportMessage(val);
                      setState(() {
                        _selectedTab = 4; // Route to support tab
                        _supportSubTab = 0; // AquaBot AI tab
                        _activeSidebarMenu = 5;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.navyColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.navyColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: () {
                    _sendSupportMessage(_supportInputController.text);
                    setState(() {
                      _selectedTab = 4;
                      _supportSubTab = 0;
                      _activeSidebarMenu = 5;
                    });
                  },
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 1: DELIVERIES MAP (Google Maps tracking with multi-order support)
  Widget _buildDeliveriesMapTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final activeJobs = orderProvider.getActiveDriverJobs(driverId);

    if (activeJobs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.map_rounded, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No active delivery jobs.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Accept jobs on the Dashboard to view routes.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final focusedJob = activeJobs.firstWhere(
      (o) => o.id == _selectedActiveOrderId,
      orElse: () => activeJobs.first,
    );
    final otherJobs = activeJobs.where((o) => o.id != focusedJob.id).toList();

    final cleanFocusId = focusedJob.id.startsWith('#')
        ? focusedJob.id.substring(1)
        : focusedJob.id;
    final shortFocusId = cleanFocusId.length > 7
        ? '${cleanFocusId.substring(0, 7)}...'
        : cleanFocusId;

    final hasCollections = activeJobs.any((j) => j.isCollectionJob);
    final hasDeliveries = activeJobs.any((j) => !j.isCollectionJob);
    final mapHeaderTitle = (hasCollections && !hasDeliveries)
        ? 'Active Collection Route (${activeJobs.length} Stops)'
        : (hasCollections && hasDeliveries)
            ? 'Active Route (${activeJobs.length} Stops: Collections & Deliveries)'
            : 'Active Deliveries (${activeJobs.length})';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count badge
          Row(
            children: [
              Icon(
                hasCollections ? Icons.assignment_return_rounded : Icons.navigation_rounded,
                color: hasCollections ? const Color(0xFF059669) : AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mapHeaderTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  'Focus: #$shortFocusId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Order Selector Chips (if > 1 order)
          if (activeJobs.length > 1) ...[
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activeJobs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final job = activeJobs[idx];
                  final isFocused = job.id == focusedJob.id;
                  final prefix = job.isCollectionJob ? 'Collect' : 'Delivery';
                  return ChoiceChip(
                    label: Text(
                      'Stop ${idx + 1} ($prefix): ${job.customerName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                        color: isFocused
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                    selected: isFocused,
                    selectedColor: job.isCollectionJob ? const Color(0xFF10B981) : AppTheme.primaryColor,
                    backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedActiveOrderId = job.id;
                        });
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Map Area (Multi-pin map)
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMapWidget(
                  destinationLat: focusedJob.latitude,
                  destinationLng: focusedJob.longitude,
                  destinationAddress: focusedJob.deliveryAddress,
                  customerName: focusedJob.customerName,
                  customerPhone: focusedJob.customerPhone,
                  isDriverView: true,
                  isCollectionJob: focusedJob.isCollectionJob,
                  orderId: focusedJob.id,
                  otherActiveOrders: otherJobs,
                  onOrderPinTapped: (orderId) {
                    setState(() {
                      _selectedActiveOrderId = orderId;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Scrollable List of Collapsible Active Delivery Cards
          Expanded(
            flex: 5,
            child: ListView.separated(
              itemCount: activeJobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final job = activeJobs[index];
                final isFocused = job.id == focusedJob.id;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.primaryColor
                          : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      width: isFocused ? 2.0 : 1.0,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: job.isCollectionJob
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : (isFocused
                                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                      : (isDark ? Colors.white10 : const Color(0xFFF1F5F9))),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              job.isCollectionJob ? Icons.assignment_return_rounded : Icons.location_on_rounded,
                              color: job.isCollectionJob
                                  ? const Color(0xFF059669)
                                  : (isFocused ? AppTheme.primaryColor : Colors.grey),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        job.isCollectionJob
                                            ? 'Stop ${index + 1} (Collect): ${job.customerName}'
                                            : 'Stop ${index + 1}: ${job.customerName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (job.isCollectionJob)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'COLLECTION TASK',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else if (isFocused)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'NAVIGATING',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  job.deliveryAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (job.isCollectionJob ? const Color(0xFF10B981) : AppTheme.secondaryColor)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              job.isCollectionJob
                                  ? 'Task: ${job.itemsSummary} • Dist: ${job.distance}'
                                  : 'Items: ${job.itemsSummary} • Dist: ${job.distance}',
                              style: TextStyle(
                                color: job.isCollectionJob ? const Color(0xFF047857) : AppTheme.secondaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!job.isCollectionJob)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: job.paymentMethod == 'GCash'
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: job.paymentMethod == 'GCash'
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFFFCD34D),
                                ),
                              ),
                              child: Text(
                                job.paymentMethod == 'GCash'
                                    ? '₱${job.totalAmount.toStringAsFixed(2)} • Paid GCash'
                                    : '₱${job.totalAmount.toStringAsFixed(2)} • Collect COD',
                                style: TextStyle(
                                  color: job.paymentMethod == 'GCash'
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Collection Service',
                                style: TextStyle(
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (job.isCollectionJob)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_return_rounded, size: 12, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text(
                                '🔄 Gallon Retrieval • Target: ${(job.borrowedSlimCount ?? 0) > 0 ? '${job.borrowedSlimCount} Slim ' : ''}${(job.borrowedRoundCount ?? 0) > 0 ? '${job.borrowedRoundCount} Round ' : ''}${job.quantity > 0 && (job.borrowedSlimCount ?? 0) == 0 && (job.borrowedRoundCount ?? 0) == 0 ? '${job.quantity} Jugs' : ''}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (job.isBorrowingContainers || (job.borrowedSlimCount ?? 0) > 0 || (job.borrowedRoundCount ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Borrowing: ${_formatBorrowSummary(job)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '💧 Refill (Customer Owns Jugs)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      if (job.deliveryNote != null && job.deliveryNote!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '📝 Note: ${job.deliveryNote}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF78350F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (job.deliveryNote?.contains('[SWAP_REPLACEMENT:') == true) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC084FC), width: 1.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.swap_horizontal_circle_rounded, color: Color(0xFF7E22CE), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🔁 DEFECT SWAP: Bring replacement container & collect defective gallon from customer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6B21A8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!isFocused)
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedActiveOrderId = job.id;
                                });
                              },
                              icon: const Icon(Icons.center_focus_strong_rounded, size: 14),
                              label: const Text('Focus Map'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () {
                              final double lat = job.latitude ?? 14.5995;
                              final double lng = job.longitude ?? 120.9842;
                              NavigationLauncher.showNavigationSheet(
                                context,
                                lat: lat,
                                lng: lng,
                                customerName: job.customerName,
                                address: job.deliveryAddress,
                                phone: job.customerPhone,
                              );
                            },
                            icon: const Icon(Icons.navigation_rounded, size: 14),
                            label: const Text('Navigate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D63B8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          if (job.isCollectionJob)
                            ElevatedButton.icon(
                              onPressed: () {
                                final borrows = orderProvider.customerBorrows;
                                final matchingBorrow = borrows.firstWhere(
                                  (b) =>
                                      (b['customerId'] == job.customerId ||
                                       b['customerName']?.toString().trim().toLowerCase() == job.customerName.trim().toLowerCase()) &&
                                      b['isReturned'] == false,
                                  orElse: () => {
                                    'orderId': job.id,
                                    'customerId': job.customerId,
                                    'customerName': job.customerName,
                                    'customerPhone': job.customerPhone,
                                    'deliveryAddress': job.deliveryAddress,
                                    'gallonType': (job.borrowedRoundCount ?? 0) > 0 ? '5-Gallon Round' : '5-Gallon Slim',
                                    'quantity': job.quantity > 0 ? job.quantity : ((job.borrowedSlimCount ?? 0) + (job.borrowedRoundCount ?? 0)),
                                  },
                                );
                                _showCollectGallonsDialog(context, matchingBorrow, collectionJob: job);
                              },
                              icon: const Icon(Icons.assignment_return_rounded, size: 14),
                              label: const Text('Collect Gallons'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => _completeActiveJob(job),
                              icon: const Icon(Icons.check_circle_rounded, size: 14),
                              label: const Text('Delivered'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatBorrowSummary(OrderModel job) {
    final slim = job.borrowedSlimCount ?? 0;
    final round = job.borrowedRoundCount ?? 0;
    if (slim > 0 && round > 0) {
      return '$slim Slim, $round Round';
    } else if (slim > 0) {
      return '$slim Slim Gallon${slim > 1 ? 's' : ''}';
    } else if (round > 0) {
      return '$round Round Gallon${round > 1 ? 's' : ''}';
    } else if (job.isBorrowingContainers) {
      return '${job.quantity} Borrowed Gallon${job.quantity > 1 ? 's' : ''}';
    }
    return 'Refill (Customer Owns Jugs)';
  }

  // TAB 2: GALLON COLLECTION & CONTAINER TRACKING
  Widget _buildGallonCollectionTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final driverName = auth.currentUser?.name ?? 'Driver';
    final currentDriverId = auth.currentUser?.id ?? '';
    final currentDriverName = (auth.currentUser?.name ?? '').trim().toLowerCase();
    final currentDriverEmail = (auth.currentUser?.email ?? '').trim().toLowerCase();

    bool driverMatchesOrder(OrderModel o) {
      final cleanId = currentDriverId.trim();
      final cleanName = currentDriverName;
      final cleanEmail = currentDriverEmail;

      if (cleanId.isNotEmpty && o.driverId != null && o.driverId == cleanId) return true;
      if (cleanName.isNotEmpty && o.driverName != null) {
        final oName = o.driverName!.trim().toLowerCase();
        if (oName == cleanName || oName.contains(cleanName) || cleanName.contains(oName)) return true;
      }
      if (cleanEmail.isNotEmpty) {
        if (o.driverId != null && o.driverId!.trim().toLowerCase() == cleanEmail) return true;
        final emailPrefix = cleanEmail.split('@').first;
        if (emailPrefix.length >= 3 && o.driverName != null) {
          if (o.driverName!.toLowerCase().replaceAll(' ', '').contains(emailPrefix)) return true;
        }
      }
      return false;
    }

    final activeCollectionJobs = orderProvider.orders
        .where((o) => o.isCollectionJob && driverMatchesOrder(o) && o.orderStatus != OrderStatus.cancelled && o.orderStatus != OrderStatus.completed)
        .toList();
    final int assignedRouteCount = activeCollectionJobs.length;

    final borrows = orderProvider.customerBorrows;
    final activeBorrows = borrows.where((b) => b['isReturned'] == false).toList();
    final dailyCollectedCount = orderProvider.getDriverDailyCollectedGallonsCount(driverName);
    final totalActiveBorrows = orderProvider.totalActiveBorrowedGallons;

    final query = _gallonSearchController.text.trim().toLowerCase();
    final filteredBorrows = activeBorrows.where((b) {
      if (query.isEmpty) return true;
      final name = (b['customerName'] as String? ?? '').toLowerCase();
      final phone = (b['customerPhone'] as String? ?? '').toLowerCase();
      final addr = (b['deliveryAddress'] as String? ?? '').toLowerCase();
      final txn = (b['txnId'] as String? ?? '').toLowerCase();
      final gType = (b['gallonType'] as String? ?? '').toLowerCase();
      return name.contains(query) || phone.contains(query) || addr.contains(query) || txn.contains(query) || gType.contains(query);
    }).toList();

    final cardBgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Text(
            'Gallon Collection & Returns',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor customer container balances and record empty gallons collected on dispatch.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards Summary
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final card1 = _buildGallonStatCard(
                title: "Today's Collected",
                value: '+$dailyCollectedCount Gallons',
                subtitle: 'Empties retrieved by you today',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
              );
              final card2 = _buildGallonStatCard(
                title: 'Active Customers with Jugs',
                value: '${activeBorrows.length} Customer${activeBorrows.length == 1 ? '' : 's'}',
                subtitle: 'Customers with outstanding gallons',
                icon: Icons.assignment_ind_rounded,
                color: const Color(0xFF2563EB),
                isDark: isDark,
              );
              final card3 = _buildGallonStatCard(
                title: 'Total Gallons in Field',
                value: '$totalActiveBorrows Gallons',
                subtitle: 'Awaiting return to station',
                icon: Icons.warehouse_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: card1),
                    const SizedBox(width: 14),
                    Expanded(child: card2),
                    const SizedBox(width: 14),
                    Expanded(child: card3),
                  ],
                );
              } else {
                return Column(
                  children: [
                    card1,
                    const SizedBox(height: 12),
                    card2,
                    const SizedBox(height: 12),
                    card3,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // Search Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _gallonSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search customer name, phone, address, or Txn ID...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _gallonSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _gallonSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Weekly Route Banner if active collection jobs exist for this driver
          if (assignedRouteCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌟 Weekly Route Active • $assignedRouteCount Dispatched Customers',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                        ),
                        Text(
                          'Dispatched by Admin • All customer collection buttons are unlocked for real-time returns.',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Active Borrows List
          if (filteredBorrows.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                  const SizedBox(height: 12),
                  Text(
                    activeBorrows.isEmpty
                        ? 'All customer borrowed gallons are returned! Zero pending collections.'
                        : 'No borrowed gallons match your search.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredBorrows.length,
              itemBuilder: (context, index) {
                final b = filteredBorrows[index];
                final custName = b['customerName'] as String? ?? 'Customer';
                final phone = b['customerPhone'] as String? ?? 'No phone';
                final rawAddress = b['deliveryAddress'] as String? ?? 'No address';
                final address = rawAddress
                    .replaceAll(RegExp(r'\[BORROWED_[A-Z]+:\d+\]'), '')
                    .replaceAll('[GALLONS_RETURNED]', '')
                    .replaceAll(RegExp(r'\s{2,}'), ' ')
                    .trim();
                final gType = b['gallonType'] as String? ?? '5-Gallon';
                final qty = (b['quantity'] as num?)?.toInt() ?? 1;
                final txnId = b['txnId'] as String? ?? '';
                final isSlim = gType.toLowerCase().contains('slim');

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Avatar + Customer Info & Owed Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: (isSlim ? Colors.indigo : Colors.deepPurple).withValues(alpha: 0.12),
                            child: Icon(
                              isSlim ? Icons.local_drink_rounded : Icons.crop_portrait_rounded,
                              color: isSlim ? Colors.indigo : Colors.deepPurple,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      custName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        'Owes $qty $gType',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.phone_rounded,
                                          size: 13,
                                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          phone,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '• Ref: $txnId',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Builder(
                        builder: (context) {
                          final custId = b['customerId'] as String? ?? '';
                          final currentDriverId = auth.currentUser?.id ?? '';
                          final currentDriverName = (auth.currentUser?.name ?? '').trim().toLowerCase();
                          final currentDriverEmail = (auth.currentUser?.email ?? '').trim().toLowerCase();

                          final driverCollectionJob = orderProvider.orders.cast<OrderModel?>().firstWhere(
                            (o) {
                              if (o == null) return false;
                              if (!o.isCollectionJob) return false;
                              if (o.orderStatus == OrderStatus.cancelled || o.orderStatus == OrderStatus.completed) return false;

                              final matchesDriver = (currentDriverId.isNotEmpty && o.driverId == currentDriverId) ||
                                  (currentDriverName.isNotEmpty && o.driverName != null &&
                                      (o.driverName!.trim().toLowerCase() == currentDriverName ||
                                       o.driverName!.trim().toLowerCase().contains(currentDriverName) ||
                                       currentDriverName.contains(o.driverName!.trim().toLowerCase()))) ||
                                  (currentDriverEmail.isNotEmpty &&
                                      (o.driverId == currentDriverEmail ||
                                       (o.driverName != null && o.driverName!.toLowerCase().contains(currentDriverEmail.split('@').first))));

                              if (!matchesDriver) return false;

                              final matchesCust = (custId.isNotEmpty && o.customerId == custId) ||
                                  (custName.isNotEmpty &&
                                      (o.customerName.trim().toLowerCase() == custName.trim().toLowerCase() ||
                                       o.customerName.trim().toLowerCase().contains(custName.trim().toLowerCase()) ||
                                       custName.trim().toLowerCase().contains(o.customerName.trim().toLowerCase()))) ||
                                  (txnId.isNotEmpty && (o.deliveryNote?.contains(txnId) ?? false));

                              return matchesCust;
                            },
                            orElse: () => null,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (driverCollectionJob != null || assignedRouteCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: Color(0xFF059669),
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Weekly Task Dispatched • Ready to log returned containers',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: (driverCollectionJob != null || assignedRouteCount > 0)
                                    ? ElevatedButton.icon(
                                        onPressed: () {
                                          if (driverCollectionJob != null && driverCollectionJob.orderStatus != OrderStatus.onDelivery) {
                                            _acceptDeliveryJob(driverCollectionJob);
                                          }
                                          _showCollectGallonsDialog(
                                            context,
                                            b,
                                            collectionJob: driverCollectionJob,
                                          );
                                        },
                                        icon: const Icon(Icons.assignment_return_rounded, size: 16),
                                        label: const Text('Log Return / Collect Gallons'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () {
                                          Helpers.showSnackBar(
                                            context,
                                            'Awaiting Admin job order. The Admin has not scheduled a weekly collection route for your account yet.',
                                          );
                                        },
                                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                                        label: const Text('🔒 Awaiting Admin Job Order'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                          foregroundColor: isDark ? Colors.white54 : const Color(0xFF64748B),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGallonStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cardBgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCollectGallonsDialog(BuildContext context, Map<String, dynamic> borrow, {OrderModel? collectionJob}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final driverName = auth.currentUser?.name ?? 'Driver';

    final String custName = borrow['customerName'] ?? 'Customer';
    final String gType = borrow['gallonType'] ?? '5-Gallon';
    final int owedQty = (borrow['quantity'] as num?)?.toInt() ?? 1;
    final String orderId = borrow['orderId'] ?? '';

    final isSlim = gType.toLowerCase().contains('slim');
    final isRound = gType.toLowerCase().contains('round');

    final slimController = TextEditingController(text: isSlim ? owedQty.toString() : '0');
    final roundController = TextEditingController(text: isRound ? owedQty.toString() : '0');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_return_rounded, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collect Returned Gallons',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'From: $custName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Customer currently owes $owedQty $gType gallon(s). Enter the quantity of empty containers handed over to your vehicle.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: slimController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '5-Gallon Slim Containers Collected',
                      prefixIcon: Icon(Icons.local_drink_rounded, color: Colors.indigo),
                      helperText: 'Number of empty Slim jugs received',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: roundController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '5-Gallon Round Containers Collected',
                      prefixIcon: Icon(Icons.crop_portrait_rounded, color: Colors.deepPurple),
                      helperText: 'Number of empty Round jugs received',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Container Condition (Optional)',
                      hintText: 'e.g. Good condition with cap intact',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final slimCount = int.tryParse(slimController.text.trim()) ?? 0;
                final roundCount = int.tryParse(roundController.text.trim()) ?? 0;
                if (slimCount <= 0 && roundCount <= 0) {
                  Helpers.showSnackBar(context, 'Please enter at least 1 collected gallon.', isError: true);
                  return;
                }

                await orderProvider.collectDriverReturnedGallons(
                  orderId: orderId,
                  customerName: custName,
                  slimCount: slimCount,
                  roundCount: roundCount,
                  driverName: driverName,
                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                );

                if (collectionJob != null) {
                  await orderProvider.updateOrderStatus(
                    orderId: collectionJob.id,
                    newStatus: OrderStatus.completed,
                    driverId: auth.currentUser?.id,
                    driverName: driverName,
                  );
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                setState(() {});
                Helpers.showSnackBar(
                  context,
                  'Successfully logged return: ${slimCount > 0 ? '$slimCount Slim ' : ''}${roundCount > 0 ? '$roundCount Round' : ''} gallons collected from $custName! Admin inventory updated in real-time.',
                );
              },
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Confirm Collection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // TAB 3: TRIP DUTY HISTORY
  Widget _buildDutyHistoryTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final completedJobs = orderProvider.getDriverCompletedJobs(driverId);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Duty Log Sheet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: completedJobs.isEmpty
                ? const Center(child: Text('No trips completed today.'))
                : ListView.builder(
                    itemCount: completedJobs.length,
                    itemBuilder: (context, index) {
                      final job = completedJobs[index];
                      final orderTotal = job.totalAmount;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.check_rounded,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(
                            '${job.customerName} (${job.id})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Dest: ${job.deliveryAddress} • Items: ${job.itemsSummary} • ${job.paymentMethod}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${orderTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job.completedAt?.toString().split('.')[0] ??
                                    'Completed',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 4: AI SUPPORT DESK (Full chat interface)
  Widget _buildSupportTab(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final maxAccordionHeight = totalHeight > 550
            ? 210.0
            : (totalHeight * 0.30).clamp(110.0, 160.0);
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
            // Dynamic Gradient Header (AquaBot vs Station Admin Desk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _supportSubTab == 1
                      ? [const Color(0xFF1E293B), const Color(0xFFD97706)]
                      : [AppTheme.navyColor, AppTheme.primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: _supportSubTab == 1
                          ? const Icon(
                              Icons.support_agent_rounded,
                              color: Color(0xFFD97706),
                              size: 24,
                            )
                          : Image.asset(
                              'assets/images/logo_icon.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.water_drop_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _supportSubTab == 1
                              ? 'Station Admin Dispatch Desk'
                              : 'AquaBot AI Assistant',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 7, height: 7),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _supportSubTab == 1
                                    ? 'Direct Station Administrator Link • Live'
                                    : 'JJAASS Water Market • Online',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFBAE6FD),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _supportSubTab == 1 ? 'Scroll to Latest' : 'Reset Chat',
                    icon: Icon(
                      _supportSubTab == 1 ? Icons.arrow_downward_rounded : Icons.refresh_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () {
                      if (_supportSubTab == 1) {
                        _scrollAdminChatToBottom();
                      } else {
                        setState(() {
                          _supportMessages.clear();
                          _supportMessages.add({
                            'sender': 'AquaBot',
                            'message':
                                "Hello! I'm **AquaBot 💧**, your JJAASS Water Market driver dispatch assistant.\n\nTap any topic in the **Quick Inquiry Guide** above, or type your question below for instant delivery, route, or gallon collection guidance!",
                          });
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            // Sub-Tab Switcher: [ AquaBot AI Guide ] vs [ Station Admin Desk ]
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _supportSubTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _supportSubTab == 0
                              ? Colors.white
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: _supportSubTab == 0
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.smart_toy_rounded,
                              size: 16,
                              color: _supportSubTab == 0
                                  ? AppTheme.primaryColor
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AquaBot AI Guide',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _supportSubTab == 0
                                    ? AppTheme.primaryColor
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _supportSubTab = 1);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final driverId = auth.currentUser?.id ?? '';
                        if (driverId.isNotEmpty) {
                          ChatService.instance.markConversationAsRead('support_$driverId', 'driver');
                          _scrollAdminChatToBottom();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _supportSubTab == 1
                              ? Colors.white
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: _supportSubTab == 1
                                  ? const Color(0xFFD97706)
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent_rounded,
                              size: 16,
                              color: _supportSubTab == 1
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Station Admin Desk',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _supportSubTab == 1
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: ChatService.instance,
                              builder: (context, _) {
                                final auth = Provider.of<AuthProvider>(context, listen: false);
                                final driverId = auth.currentUser?.id ?? '';
                                final unread = driverId.isNotEmpty
                                    ? ChatService.instance
                                        .getConversationMessages('support_$driverId')
                                        .where((m) => !m.isRead && m.senderRole != 'driver')
                                        .length
                                    : 0;
                                if (unread == 0) return const SizedBox.shrink();
                                return Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_supportSubTab == 0) ...[

            // Collapsible Quick Inquiry FAQ Accordion
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.quiz_rounded,
                      color: AppTheme.navyColor,
                      size: 18,
                    ),
                  ),
                  title: const Text(
                    'Quick Inquiry Guide (FAQs)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  subtitle: const Text(
                    'Tap to browse 4 driver topics for instant answers',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxAccordionHeight),
                      child: Scrollbar(
                        controller: _faqScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _faqScrollController,
                          primary: false,
                          padding: const EdgeInsets.only(right: 6),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              _buildInquiryCategoryTile(
                                title: '🚚 Dispatch & Live Navigation',
                                color: const Color(0xFF0284C7),
                                questions: [
                                  'How do I mark an assigned order as out for delivery?',
                                  'How do I navigate using the customer pinned GPS location?',
                                  'What should I do if the customer is not at the delivery address?',
                                ],
                              ),
                              _buildInquiryCategoryTile(
                                title: '🔄 Gallon Collection & Returns',
                                color: const Color(0xFF10B981),
                                questions: [
                                  'How do I log collected borrowed gallons from a customer?',
                                  'How are returned Slim and Round containers restocked automatically?',
                                  'What if the customer only returns 3 out of 5 borrowed gallons?',
                                ],
                              ),
                              _buildInquiryCategoryTile(
                                title: '💳 Cash & GCash Collection',
                                color: const Color(0xFF0F2B5C),
                                questions: [
                                  'How do I confirm payment received for Cash on Delivery (COD)?',
                                  'How do I verify if an order was already paid online via GCash?',
                                ],
                              ),
                              _buildInquiryCategoryTile(
                                title: '⛽ Vehicle Stock & Driver Status',
                                color: const Color(0xFFD97706),
                                questions: [
                                  'How do I check my vehicle gallon loading capacity?',
                                  'How do I switch between Available and On Delivery status?',
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Message List
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(14.0),
                itemCount: _supportMessages.length,
                itemBuilder: (context, index) {
                  final msg = _supportMessages[index];
                  final isBot = msg['sender'] == 'AquaBot';
                  return Align(
                    alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: isBot
                        ? Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(
                                color: const Color(0xFFBAE6FD),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.smart_toy_rounded,
                                      size: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'AquaBot',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  msg['message'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF0F2B5C),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.navyColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(4),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              msg['message'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),

            // Chat Input Bar
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _supportInputController,
                      onSubmitted: _sendSupportMessage,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type dispatch query or ask anything...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isChatLoading ? null : () => _sendSupportMessage(_supportInputController.text),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.navyColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.navyColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isChatLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: _buildStationAdminChatSection(isDark),
            ),
          ],
        ],
      ),
    ),
  );
      },
    );
  }

  Widget _buildStationAdminChatSection(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final conversationId = 'support_$driverId';

    return Column(
      children: [
        // Desk Sub-Header with Admin Status & Full Modal Shortcut
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Dispatch Direct Channel • Station Administrator',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => RealtimeChatModal.show(
                  context,
                  initialConversationId: conversationId,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.primaryColor),
                label: const Text(
                  'Full Modal',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),

        // Live Messages from ChatService
        Expanded(
          child: AnimatedBuilder(
            animation: ChatService.instance,
            builder: (context, _) {
              final messages = ChatService.instance.getConversationMessages(conversationId);

              if (messages.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            size: 36,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Station Admin Desk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navyColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Direct two-way channel with station dispatchers.\nSend an urgent message below for route assistance, customer updates, or gallon inventory questions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ActionChip(
                              label: const Text('🚨 Traffic Delay Alert', style: TextStyle(fontSize: 11.5)),
                              onPressed: () => _sendAdminChatMessage('Station Admin: Heavy traffic along delivery route, completing stops shortly.'),
                            ),
                            ActionChip(
                              label: const Text('📍 Clarify Address', style: TextStyle(fontSize: 11.5)),
                              onPressed: () => _sendAdminChatMessage('Station Admin: Need assistance clarifying customer landmark/pinned location.'),
                            ),
                            ActionChip(
                              label: const Text('💧 Need Refill Stock', style: TextStyle(fontSize: 11.5)),
                              onPressed: () => _sendAdminChatMessage('Station Admin: Heading back to refilling station to reload gallon inventory.'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _adminChatScrollController,
                padding: const EdgeInsets.all(14.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderRole == 'driver';

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? AppTheme.navyColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isMe ? 14 : 2),
                          bottomRight: Radius.circular(isMe ? 2 : 14),
                        ),
                        border: Border.all(
                          color: isMe ? AppTheme.navyColor : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isMe ? 'You (Driver)' : (msg.senderName.isNotEmpty ? msg.senderName : 'Station Admin'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? const Color(0xFF93C5FD) : const Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isMe ? Colors.white60 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            msg.message,
                            style: TextStyle(
                              fontSize: 13,
                              color: isMe ? Colors.white : const Color(0xFF0F172A),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Bottom Input Bar for Station Admin
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adminChatInputController,
                  onSubmitted: (_) => _sendAdminChatMessage(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Type message to Station Admin...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _sendAdminChatMessage(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInquiryCategoryTile({
    required String title,
    required Color color,
    required List<String> questions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          visualDensity: VisualDensity.compact,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          children: questions.map((q) {
            return InkWell(
              onTap: () => _sendSupportMessage(q),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.navyColor,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // TAB 5: SETTINGS
  InputDecoration _boxedDecoration(String label) {
    OutlineInputBorder border(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF475569)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(const Color(0xFFCBD5E1)),
      enabledBorder: border(const Color(0xFFCBD5E1)),
      focusedBorder: border(AppTheme.primaryColor, 2),
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Profile Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicleType,
                  isExpanded: true,
                  decoration: _boxedDecoration('Registered Vehicle Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Motorcycle with Rack',
                      child: Text(
                        'Motorcycle with Rack',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Sidecar / Tricycle',
                      child: Text(
                        'Sidecar / Tricycle',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Delivery Truck',
                      child: Text(
                        'Delivery Truck',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedVehicleType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _plateNoController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: _boxedDecoration('Plate Number'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Helpers.showSnackBar(
                      context,
                      'Vehicle registration updated.',
                    );
                  },
                  child: const Text('Save Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _SidebarItemTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;
  final int? badgeCount;

  const _SidebarItemTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.textColor,
    this.badgeCount,
  });

  @override
  State<_SidebarItemTile> createState() => _SidebarItemTileState();
}

class _SidebarItemTileState extends State<_SidebarItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;
    final bool highlighted = active || _isHovered;

    Color backgroundColor;
    Color contentColor;
    if (active) {
      backgroundColor = AppTheme.navyColor;
      contentColor = Colors.white;
    } else if (_isHovered) {
      backgroundColor = const Color(0xFFEFF6FF);
      contentColor = widget.textColor ?? AppTheme.navyColor;
    } else {
      backgroundColor = Colors.transparent;
      contentColor = widget.textColor ?? const Color(0xFF334155);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          onTap: widget.onTap,
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          leading: Icon(widget.icon, size: 20, color: contentColor),
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500,
              color: contentColor,
            ),
          ),
          trailing: widget.badgeCount != null && widget.badgeCount! > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
