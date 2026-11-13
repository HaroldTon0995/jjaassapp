import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/delivery_issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../services/report_service.dart';
import '../../services/ai_support_service.dart';
import '../../services/chat_service.dart';
import '../../services/delivery_issue_service.dart';
import '../../services/compliance_permit_service.dart';
import '../../core/utils/laptop_file_picker.dart';
import '../../widgets/water_widgets.dart';
import '../../widgets/gcash_payment_modal.dart';

part 'admin_header.dart';
part 'admin_overview.dart';
part 'admin_orders.dart';
part 'admin_claims.dart';
part 'admin_deliveries.dart';
part 'admin_users.dart';
part 'admin_inventory.dart';
part 'admin_payments.dart';
part 'admin_reports.dart';
part 'admin_support.dart';
part 'admin_settings.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];

  // Tab indexing maps directly to sidebar:
  // 0: Dashboard, 1: Orders, 2: Deliveries, 3: Customers, 4: Inventory, 5: Payments, 6: Reports, 7: AI Chat Support, 8: Users, 9: Settings
  int _selectedTab = 0;
  int _activeSidebarMenu = 0;

  // Search/filter states for Users
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'All';

  // Search/filter states for Inventory
  final TextEditingController _inventorySearchController =
      TextEditingController();
  final TextEditingController _borrowSearchController = TextEditingController();
  int _inventorySubTab =
      0; // 0: Inventory Items, 1: Customer Borrowed Gallons Log
  String _inventoryCategoryFilter =
      'all'; // 'all', 'water', 'container', 'accessory'
  String _borrowFilter = 'all'; // 'all', 'active', 'returned', 'slim', 'round'

  // Sub-tabs & Filter states for Orders
  int _ordersSubTab = 0; // 0: Orders Log, 1: Defect & Swap Claims
  String _claimFilter = 'All'; // 'All', 'Pending', 'Approved', 'Declined'
  final TextEditingController _claimSearchController = TextEditingController();

  // State variables for interactive support chat
  final List<Map<String, dynamic>> _supportMessages = [
    {
      'sender': 'AquaBot',
      'message':
          "Hello Administrator! I'm **AquaBot 💧**, your JJAASS Water Market management assistant.\n\nTap any topic in the **Quick Inquiry Guide** above, or type your question below for instant guidance on inventory, bulk reservoir levels, driver dispatches, or sales reports!",
    },
  ];
  final TextEditingController _supportInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _faqScrollController = ScrollController();
  bool _isChatLoading = false;

  // Sales Overview interactive state
  String _salesTimeframe =
      'This Week'; // 'This Week', 'Last 7 Days', 'This Month', 'All Time'
  int? _selectedSalesPointIndex;

  // Orders status filter
  String _activeOrderFilter = 'All';

  // Deliveries Tab States
  String _deliveriesFilter =
      'All'; // 'All', 'Active', 'Pending', 'Completed', 'Today'
  final TextEditingController _deliveriesSearchController =
      TextEditingController();
  OrderModel? _selectedDeliveryOrder;
  bool _mapSatelliteMode = false;

  // Realtime Report States
  String _reportInterval = 'Daily'; // 'Daily', 'Weekly', 'Monthly', 'Annually'
  DateTime _selectedReportDate = DateTime.now();

  // Realtime Payments Filter and Search States
  String _paymentsFilter =
      'All'; // 'All', 'GCash', 'Cash on Delivery', 'Paid', 'Pending'
  final TextEditingController _paymentsSearchController =
      TextEditingController();

  // Realtime Live Notifications
  final List<Map<String, dynamic>> _notifications = [];

  // Global Header Search Controller
  final TextEditingController _globalSearchController = TextEditingController();

  // Orders Search Controller
  final TextEditingController _orderSearchController = TextEditingController();

  // Admin Profile Controllers (Settings)
  final TextEditingController _adminNameController = TextEditingController(
    text: 'harold borbo',
  );
  final TextEditingController _adminEmailController = TextEditingController(
    text: 'admin@jjaasswater.com',
  );
  final TextEditingController _adminPhoneController = TextEditingController(
    text: '+63 995 113 3652',
  );

  // Customer & Driver Direct Messages (Decoupled from order system notifications)
  final List<Map<String, dynamic>> _inboxMessages = [
    {
      'id': 'msg_001',
      'sender': 'haroldcristonborbo',
      'role': 'Customer',
      'snippet':
          'Hi Admin, can you schedule delivery every Monday for our household?',
      'time': '12 mins ago',
      'isRead': false,
      'messages': [
        {
          'sender': 'haroldcristonborbo',
          'text':
              'Hi Admin, can you schedule delivery every Monday for our household?',
          'time': '12 mins ago',
          'isAdmin': false,
        },
      ],
      'timestamp': DateTime.now(),
    },
    {
      'id': 'msg_002',
      'sender': 'Tonton Borbo',
      'role': 'Driver',
      'snippet':
          'Traffic in Malilipot highway, will finish delivery deliveries in 20 mins.',
      'time': '35 mins ago',
      'isRead': false,
      'messages': [
        {
          'sender': 'Tonton Borbo',
          'text':
              'Traffic in Malilipot highway, will finish delivery deliveries in 20 mins.',
          'time': '35 mins ago',
          'isAdmin': false,
        },
      ],
      'timestamp': DateTime.now(),
    },
    {
      'id': 'msg_003',
      'sender': 'Carl Customer',
      'role': 'Customer',
      'snippet': 'Thank you! The purified water quality is very clean.',
      'time': '2 hours ago',
      'isRead': true,
      'messages': [
        {
          'sender': 'Carl Customer',
          'text': 'Thank you! The purified water quality is very clean.',
          'time': '2 hours ago',
          'isAdmin': false,
        },
        {
          'sender': 'Station Admin',
          'text':
              'You are very welcome! We test our filtration systems weekly for highest purity.',
          'time': '1 hour ago',
          'isAdmin': true,
        },
      ],
      'timestamp': DateTime.now(),
    },
  ];

  // Order state tracking
  List<OrderModel> _previousOrders = [];

  // Profiles stream and state tracking
  StreamSubscription? _profilesSubscription;
  List<UserModel> _previousProfiles = [];

  void _syncRealtimeNotifications(List<OrderModel> currentOrders) {
    if (_previousOrders.isEmpty) {
      _previousOrders = List.from(currentOrders);
      _notifications.clear();
      _notifications.add({
        'id': 'system_init',
        'title': 'System Online',
        'body': 'Live transaction monitor is online.',
        'time': 'Just now',
        'icon': Icons.dns_rounded,
        'color': Colors.indigo,
        'isRead': false,
        'timestamp': DateTime.now(),
      });
      return;
    }

    final today = DateTime.now();

    for (var o in currentOrders) {
      final isNew = !_previousOrders.any((prev) => prev.id == o.id);
      if (isNew) {
        if (o.createdAt.year == today.year &&
            o.createdAt.month == today.month &&
            o.createdAt.day == today.day) {
          _notifications.insert(0, {
            'id': 'new_${o.id}',
            'title': 'New Order Placed',
            'body': '${o.customerName} ordered ${o.itemsSummary} (${o.id}).',
            'time': 'Just now',
            'icon': Icons.shopping_basket_rounded,
            'color': Colors.blue,
            'isRead': false,
            'timestamp': DateTime.now(),
          });

          // Realtime alert toast for admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Helpers.showSnackBar(
                context,
                '🛒 Realtime Order: ${o.customerName} placed ${o.id} (${o.itemsSummary} • ${o.paymentMethod} • ${o.paymentStatus})',
              );
            }
          });
        }
      }
    }

    for (var o in currentOrders) {
      final prevIndex = _previousOrders.indexWhere((prev) => prev.id == o.id);
      if (prevIndex != -1) {
        final prev = _previousOrders[prevIndex];

        if (prev.orderStatus != o.orderStatus) {
          IconData icon = Icons.info_outline;
          Color color = Colors.grey;
          String title = 'Order Update';
          String body =
              'Order ${o.id} status updated to ${o.orderStatus.displayName}.';

          if (o.orderStatus == OrderStatus.confirmed) {
            title = 'Order Confirmed';
            body = 'Order ${o.id} confirmed by Admin.';
            icon = Icons.assignment_turned_in_rounded;
            color = Colors.purple;
          } else if (o.orderStatus == OrderStatus.assigned) {
            title = 'Rider Assigned';
            body =
                'Driver ${o.driverName ?? "Driver"} assigned to Order ${o.id}.';
            icon = Icons.assignment_ind_rounded;
            color = const Color(0xFFF43F5E);
          } else if (o.orderStatus == OrderStatus.onDelivery) {
            title = 'Job Dispatched';
            body =
                'Driver ${o.driverName ?? "Driver"} accepted delivery for ${o.id}.';
            icon = Icons.local_shipping_rounded;
            color = Colors.cyan;
          } else if (o.orderStatus == OrderStatus.completed) {
            title = 'Delivery Completed';
            body =
                'Order ${o.id} delivered to ${o.customerName} by ${o.driverName ?? "Driver"}.';
            icon = Icons.check_circle_outline_rounded;
            color = Colors.green;
          } else if (o.orderStatus == OrderStatus.cancelled) {
            title = 'Order Cancelled';
            body = 'Order ${o.id} was cancelled.';
            icon = Icons.cancel_outlined;
            color = Colors.red;
          }

          _notifications.insert(0, {
            'id': 'status_${o.id}_${o.orderStatus.name}',
            'title': title,
            'body': body,
            'time': 'Just now',
            'icon': icon,
            'color': color,
            'isRead': false,
            'timestamp': DateTime.now(),
          });
        }

        if (prev.paymentStatus != o.paymentStatus &&
            o.paymentStatus == 'Paid') {
          _notifications.insert(0, {
            'id': 'pay_${o.id}',
            'title': 'Payment Confirmed',
            'body':
                'Payment of ₱${o.totalAmount.toStringAsFixed(2)} confirmed for ${o.id}.',
            'time': 'Just now',
            'icon': Icons.payments_rounded,
            'color': Colors.green,
            'isRead': false,
            'timestamp': DateTime.now(),
          });

          // Realtime payment alert toast for admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Helpers.showSnackBar(
                context,
                '💰 Realtime Payment: ${o.customerName} paid ₱${o.totalAmount.toStringAsFixed(2)} for ${o.id} via ${o.paymentMethod}!',
              );
            }
          });
        }
      }
    }

    _notifications.retainWhere((n) {
      final ts = n['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    _inboxMessages.retainWhere((m) {
      final ts = m['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    _previousOrders = List.from(currentOrders);
  }

  void _listenToSupabaseProfiles() {
    final isSupabaseConfigured =
        AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
        AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';
    if (!isSupabaseConfigured) return;

    try {
      final client = Supabase.instance.client;
      _profilesSubscription = client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> response) {
              if (!mounted) return;
              final orderProvider = Provider.of<OrderProvider>(
                context,
                listen: false,
              );
              final currentProfiles = response.map((item) {
                final model = UserModel.fromJson(item);
                final lower = model.name.trim().toLowerCase();
                if (lower.isEmpty ||
                    lower == 'new user' ||
                    lower == 'registered user') {
                  for (final o in orderProvider.orders) {
                    if (o.customerId == model.id &&
                        o.customerName.trim().isNotEmpty &&
                        o.customerName.trim().toLowerCase() != 'new user') {
                      return UserModel(
                        id: model.id,
                        name: o.customerName.trim(),
                        email: model.email,
                        role: model.role,
                      );
                    }
                  }
                }
                return model;
              }).toList();
              _syncProfileNotifications(currentProfiles);
            },
            onError: (e) {
              debugPrint('Supabase Realtime Profiles stream error: $e');
            },
          );
    } catch (e) {
      debugPrint('Supabase Realtime Profiles stream setup failed: $e');
    }
  }

  void _syncProfileNotifications(List<UserModel> currentProfiles) {
    if (_previousProfiles.isEmpty) {
      _previousProfiles = List.from(currentProfiles);
      setState(() {
        _allUsers = currentProfiles;
        _filteredUsers = currentProfiles;
      });
      _applyFilters();
      return;
    }

    final today = DateTime.now();

    for (var p in currentProfiles) {
      final isNew = !_previousProfiles.any((prev) => prev.id == p.id);
      if (isNew) {
        final roleLabel = p.role == UserRole.driver ? 'Driver' : 'Customer';
        _notifications.insert(0, {
          'id': 'reg_${p.id}',
          'title': 'New Registration',
          'body': 'Realtime: New $roleLabel ${p.name} registered.',
          'time': 'Just now',
          'icon': p.role == UserRole.driver
              ? Icons.local_shipping_rounded
              : Icons.person_add_rounded,
          'color': p.role == UserRole.driver ? Colors.orange : Colors.blue,
          'isRead': false,
          'timestamp': DateTime.now(),
        });

        Helpers.showSnackBar(
          context,
          'Database Alert: New $roleLabel ${p.name} has registered!',
        );
      }
    }

    _notifications.retainWhere((n) {
      final ts = n['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    _inboxMessages.retainWhere((m) {
      final ts = m['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    setState(() {
      _allUsers = currentProfiles;
      _filteredUsers = currentProfiles;
      _previousProfiles = List.from(currentProfiles);
    });
    _applyFilters();
  }

  String _resolveCustomerDisplayName(OrderModel order) {
    final raw = order.customerName.trim();
    if (raw.isNotEmpty &&
        raw.toLowerCase() != 'new user' &&
        raw.toLowerCase() != 'registered user') {
      return raw;
    }
    if (order.customerId.isNotEmpty) {
      for (final u in _allUsers) {
        if (u.id == order.customerId &&
            u.name.trim().isNotEmpty &&
            u.name.trim().toLowerCase() != 'new user') {
          return u.name.trim();
        }
      }
    }
    if (order.customerPhone.isNotEmpty &&
        order.customerPhone != '+63 912 345 6789') {
      return 'Customer (${order.customerPhone})';
    }
    final short = order.id.replaceFirst(RegExp(r'^[#A-Za-z\-]+'), '');
    return short.isNotEmpty ? 'Customer #$short' : 'Customer';
  }

  @override
  void initState() {
    super.initState();
    ChatService.instance.init();
    DeliveryIssueService.instance.init();
    CompliancePermitService.instance.loadPermits();
    _loadAllDashboardData();
    _listenToSupabaseProfiles();
  }

  @override
  void dispose() {
    _profilesSubscription?.cancel();
    _searchController.dispose();
    _inventorySearchController.dispose();
    _borrowSearchController.dispose();
    _supportInputController.dispose();
    _chatScrollController.dispose();
    _faqScrollController.dispose();
    _paymentsSearchController.dispose();
    _globalSearchController.dispose();
    _orderSearchController.dispose();
    _claimSearchController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAllDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _apiService.getAdminUsers();

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to sync dashboard data.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final matchesQuery =
            user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.role.name.toLowerCase().contains(query) ||
            (query == 'customers' && user.role == UserRole.customer);
        final matchesRole =
            _selectedRoleFilter == 'All' ||
            user.role.name.toLowerCase() == _selectedRoleFilter.toLowerCase() ||
            (_selectedRoleFilter.toLowerCase() == 'customers' &&
                user.role == UserRole.customer);
        return matchesQuery && matchesRole;
      }).toList();
    });
  }

  // ignore: unused_element
  void _updateOrderStatus(String id, String newStatusStr) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    OrderStatus status = OrderStatus.pending;
    if (newStatusStr == 'Confirmed') status = OrderStatus.confirmed;
    if (newStatusStr == 'Assigned') status = OrderStatus.assigned;
    if (newStatusStr == 'On Delivery') status = OrderStatus.onDelivery;
    if (newStatusStr == 'Completed') status = OrderStatus.completed;
    if (newStatusStr == 'Cancelled') status = OrderStatus.cancelled;

    await orderProvider.updateOrderStatus(orderId: id, newStatus: status);
    if (mounted) {
      Helpers.showSnackBar(
        context,
        'Order $id status updated to $newStatusStr across system.',
      );
    }
  }

  void _sendSupportMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isChatLoading) return; // Prevent multiple requests at once
    final userQuery = text.trim();

    setState(() {
      _supportMessages.add({'sender': 'Admin', 'message': userQuery});
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
        isDriver: false,
        isAdmin: true,
        userId: user?.id ?? '',
        userName: user?.name ?? 'Admin',
        orderProvider: orderProvider,
      );

      if (mounted) {
        setState(() {
          if (_supportMessages.isNotEmpty &&
              _supportMessages.last['message'] == 'Thinking...') {
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
          if (_supportMessages.isNotEmpty &&
              _supportMessages.last['message'] == 'Thinking...') {
            _supportMessages.removeLast();
          }
          _supportMessages.add({
            'sender': 'AquaBot',
            'message':
                'Sorry, I encountered an issue retrieving a response. Please check your connection and try again.',
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

  Future<void> _handleUpdateRole(UserModel user, UserRole newRole) async {
    // Admin and Customer roles cannot be changed; only Driver can be modified
    if (user.role == UserRole.admin) {
      Helpers.showSnackBar(
        context,
        'Admin account is protected and cannot be changed.',
        isError: true,
      );
      return;
    }
    if (user.role == UserRole.customer) {
      Helpers.showSnackBar(
        context,
        'Customer account role is permanent and cannot be changed.',
        isError: true,
      );
      return;
    }
    if (newRole == UserRole.admin) {
      Helpers.showSnackBar(
        context,
        'Cannot assign Admin role. Only Customer and Driver roles are allowed.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final success = await _apiService.updateUserRole(user.id, newRole);
      if (success && mounted) {
        Helpers.showSnackBar(
          context,
          'Updated ${user.name} to ${newRole.name}.',
        );
        final updatedUsers = await _apiService.getAdminUsers();
        setState(() {
          _allUsers = updatedUsers;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to update user role.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteUser(UserModel user, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete this account?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getRoleIcon(user.role),
                          size: 16,
                          color: _getRoleColor(user.role),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(
                              user.role,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.roleDisplayName,
                            style: TextStyle(
                              color: _getRoleColor(user.role),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This will remove this user from the system and database. This action cannot be undone.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Delete Permanently',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isActionLoading = true;
    });

    try {
      final success = await _apiService.deleteUserAccount(user.id);
      if (success && mounted) {
        setState(() {
          _allUsers.removeWhere((u) => u.id == user.id);
          _filteredUsers.removeWhere((u) => u.id == user.id);
        });
        Helpers.showSnackBar(
          context,
          'Account "${user.name}" has been permanently deleted.',
        );
      } else if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to delete user account. Please check your connection.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error deleting user: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  // Global Header Search Router
  void _handleGlobalSearch(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return;

    if (query.contains('user') ||
        query.contains('role') ||
        query.contains('account') ||
        query.contains('customer') ||
        query.contains('driver')) {
      setState(() {
        _selectedTab = 3;
        _activeSidebarMenu = 3;
        _searchController.text = rawQuery.trim();
      });
      _applyFilters();
      Helpers.showSnackBar(
        context,
        'Navigated to Users & Roles for "$rawQuery"',
      );
    } else if (query.contains('order') ||
        query.startsWith('#col') ||
        query.startsWith('#ord') ||
        query.startsWith('col') ||
        query.startsWith('ord')) {
      setState(() {
        _selectedTab = 1;
        _activeSidebarMenu = 1;
        _orderSearchController.text = rawQuery.trim();
      });
      Helpers.showSnackBar(
        context,
        'Navigated to Orders Management for "$rawQuery"',
      );
    } else if (query.contains('deliver') ||
        query.contains('fleet') ||
        query.contains('rider') ||
        query.contains('route') ||
        query.contains('track')) {
      setState(() {
        _selectedTab = 2;
        _activeSidebarMenu = 2;
        _deliveriesSearchController.text = rawQuery.trim();
      });
      Helpers.showSnackBar(
        context,
        'Navigated to Fleet Deliveries for "$rawQuery"',
      );
    } else if (query.contains('invent') ||
        query.contains('stock') ||
        query.contains('tank') ||
        query.contains('gallon') ||
        query.contains('jug')) {
      setState(() {
        _selectedTab = 4;
        _activeSidebarMenu = 4;
        _inventorySearchController.text = rawQuery.trim();
      });
      Helpers.showSnackBar(context, 'Navigated to Inventory for "$rawQuery"');
    } else if (query.contains('pay') ||
        query.contains('gcash') ||
        query.contains('cash') ||
        query.contains('sales') ||
        query.contains('revenue')) {
      setState(() {
        _selectedTab = 5;
        _activeSidebarMenu = 5;
        _paymentsSearchController.text = rawQuery.trim();
      });
      Helpers.showSnackBar(context, 'Navigated to Payments for "$rawQuery"');
    } else if (query.contains('report') ||
        query.contains('analyt') ||
        query.contains('kpi') ||
        query.contains('export')) {
      setState(() {
        _selectedTab = 6;
        _activeSidebarMenu = 6;
      });
      Helpers.showSnackBar(
        context,
        'Navigated to Analytics & Reports for "$rawQuery"',
      );
    } else if (query.contains('ai') ||
        query.contains('chat') ||
        query.contains('bot') ||
        query.contains('support') ||
        query.contains('aquabot')) {
      setState(() {
        _selectedTab = 7;
        _activeSidebarMenu = 7;
      });
      Helpers.showSnackBar(
        context,
        'Navigated to AI Chat Support for "$rawQuery"',
      );
    } else if (query.contains('setting') ||
        query.contains('permit') ||
        query.contains('sanitary') ||
        query.contains('profile') ||
        query.contains('compliance')) {
      setState(() {
        _selectedTab = 8;
        _activeSidebarMenu = 8;
      });
      Helpers.showSnackBar(context, 'Navigated to Settings for "$rawQuery"');
    } else {
      // Check if matches an order id or customer in order provider
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final hasOrder = orderProvider.orders.any(
        (o) =>
            o.id.toLowerCase().contains(query) ||
            o.customerName.toLowerCase().contains(query),
      );
      if (hasOrder) {
        setState(() {
          _selectedTab = 1;
          _activeSidebarMenu = 1;
          _orderSearchController.text = rawQuery.trim();
        });
        Helpers.showSnackBar(context, 'Found matching order for "$rawQuery"');
      } else {
        setState(() {
          _selectedTab = 3;
          _activeSidebarMenu = 3;
          _searchController.text = rawQuery.trim();
        });
        _applyFilters();
        Helpers.showSnackBar(context, 'Searching database for "$rawQuery"...');
      }
    }
  }

  // Confirmation warning dialog for permanently deleting an order transaction
  Future<void> _confirmDeleteOrder(OrderModel order, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Order Transaction',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete this order record?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ID: ${order.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer: ${_resolveCustomerDisplayName(order)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Products: ${order.itemsSummary}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grand Total: ${order.formattedTotal}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠️ Warning: This action cannot be undone and will permanently remove this transaction from the database and revenue reports.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Delete Permanently',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed == true) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success = await orderProvider.deleteOrder(order.id);
      if (!mounted) return;
      if (success) {
        Helpers.showSnackBar(
          context,
          'Order ${order.id} has been permanently deleted.',
        );
      } else {
        Helpers.showSnackBar(
          context,
          'Failed to delete order. Please check connection.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  // Create Customer or Driver Account Directly from Admin Panel without public sign-up
  void _showCreateUserDialog(bool isDark) {
    UserRole selectedRole = UserRole.customer;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'Pass1234!');
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (subContext, setDialogState) {
            final isAdmin = selectedRole == UserRole.admin;
            final isDriver = selectedRole == UserRole.driver;
            final activeColor = isAdmin
                ? const Color(0xFF6366F1)
                : (isDriver
                      ? AppTheme.secondaryColor
                      : const Color(0xFF10B981));

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : (isDriver
                                ? Icons.local_shipping_rounded
                                : Icons.person_add_rounded),
                      color: activeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAdmin
                          ? 'Create Administrator Account'
                          : (isDriver
                                ? 'Create Driver Account'
                                : 'Create Customer Account'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Selector Buttons
                      const Text(
                        'Select Account Role',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setDialogState(
                                () => selectedRole = UserRole.customer,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedRole == UserRole.customer
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.12)
                                      : (isDark
                                            ? Colors.white10
                                            : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedRole == UserRole.customer
                                        ? const Color(0xFF10B981)
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: selectedRole == UserRole.customer
                                          ? const Color(0xFF10B981)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Customer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: selectedRole == UserRole.customer
                                            ? const Color(0xFF10B981)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setDialogState(
                                () => selectedRole = UserRole.driver,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedRole == UserRole.driver
                                      ? AppTheme.secondaryColor.withValues(
                                          alpha: 0.12,
                                        )
                                      : (isDark
                                            ? Colors.white10
                                            : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedRole == UserRole.driver
                                        ? AppTheme.secondaryColor
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_shipping_rounded,
                                      size: 16,
                                      color: selectedRole == UserRole.driver
                                          ? AppTheme.secondaryColor
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Driver',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: selectedRole == UserRole.driver
                                            ? AppTheme.secondaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setDialogState(
                                () => selectedRole = UserRole.admin,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedRole == UserRole.admin
                                      ? const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.12)
                                      : (isDark
                                            ? Colors.white10
                                            : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedRole == UserRole.admin
                                        ? const Color(0xFF6366F1)
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 16,
                                      color: selectedRole == UserRole.admin
                                          ? const Color(0xFF6366F1)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: selectedRole == UserRole.admin
                                            ? const Color(0xFF6366F1)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: selectedRole == UserRole.driver
                              ? 'e.g. Juan Perez (Driver)'
                              : 'e.g. Maria Santos',
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email Address
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          hintText: 'e.g. user@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Initial Password
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Initial Login Password *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                          helperText:
                              'Password for login (at least 6 characters)',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: 'e.g. 09171234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Address / Fleet Station (Albay 1st District Scope)
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: selectedRole == UserRole.driver
                              ? 'Assigned Area (Albay 1st District) / Vehicle'
                              : 'Delivery Address (Albay 1st District)',
                          hintText: selectedRole == UserRole.driver
                              ? 'e.g. Tabaco City / Bacacay Route'
                              : 'e.g. Purok 2, Tabaco City, Albay',
                          prefixIcon: Icon(
                            selectedRole == UserRole.driver
                                ? Icons.two_wheeler_rounded
                                : Icons.location_on_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            const [
                              'Tabaco City',
                              'Bacacay',
                              'Malilipot',
                              'Malinao',
                              'Santo Domingo',
                              'Tiwi',
                            ].map((mun) {
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  mun,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () {
                                  final current = addressController.text.trim();
                                  if (!current.contains(mun)) {
                                    addressController.text = current.isEmpty
                                        ? '$mun, Albay'
                                        : '$current, $mun, Albay';
                                  }
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();
                          final phone = phoneController.text.trim();
                          final address = addressController.text.trim();

                          if (name.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'Please enter a full name.',
                              isError: true,
                            );
                            return;
                          }
                          if (email.isEmpty || !email.contains('@')) {
                            Helpers.showSnackBar(
                              context,
                              'Please enter a valid email address.',
                              isError: true,
                            );
                            return;
                          }
                          if (password.length < 6) {
                            Helpers.showSnackBar(
                              context,
                              'Password must be at least 6 characters long.',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final newUser = await _apiService.createUserAccount(
                              name: name,
                              email: email,
                              role: selectedRole,
                              password: password,
                              phone: phone.isNotEmpty ? phone : null,
                              address: address.isNotEmpty ? address : null,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (!mounted) return;
                            if (newUser != null) {
                              Helpers.showSnackBar(
                                context,
                                '${newUser.roleDisplayName} "${newUser.name}" created successfully without needing to sign up!',
                              );
                              await _loadAllDashboardData();
                            } else {
                              Helpers.showSnackBar(
                                context,
                                'Failed to create user account.',
                                isError: true,
                              );
                            }
                          } catch (e) {
                            if (subContext.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Error creating account: ${e.toString().replaceAll('Exception: ', '')}',
                                isError: true,
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    isSubmitting
                        ? 'Creating Account...'
                        : (selectedRole == UserRole.admin
                              ? 'Create Admin'
                              : (selectedRole == UserRole.driver
                                    ? 'Create Driver'
                                    : 'Create Customer')),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 1100;
    const isDark = false;

    final orderProvider = Provider.of<OrderProvider>(context);
    _syncRealtimeNotifications(orderProvider.orders);

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
              title: Column(
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
                    'JJAASS Water Market • Admin',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Colors.white),
                  tooltip: 'Sync Console',
                  onPressed: _loadAllDashboardData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: 'Log Out',
                  onPressed: _handleLogout,
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.navyColor),
                  )
                : Column(
                    children: [
                      if (isWide) _buildDesktopHeader(isDark),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
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

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 0:
        return 'System Performance Overview';
      case 1:
        return 'Orders Management';
      case 2:
        return 'Deliveries Fleet';
      case 3:
        return 'User / Roles & Permissions';
      case 4:
        return 'Inventory & Stock Tracking';
      case 5:
        return 'Payments Transactions';
      case 6:
        return 'Analytics & Reports';
      case 7:
        return 'AquaBot AI Support';
      case 8:
        return 'System Settings';
      default:
        return 'Admin Portal';
    }
  }

  Widget _buildSidebar(bool isDark, {bool isDrawer = false}) {
    final menuItems = [
      {'title': 'Dashboard', 'icon': Icons.home_rounded},
      {'title': 'Orders', 'icon': Icons.shopping_bag_rounded},
      {'title': 'Deliveries', 'icon': Icons.local_shipping_rounded},
      {
        'title': 'User / Roles & Permissions',
        'icon': Icons.manage_accounts_rounded,
      },
      {'title': 'Inventory', 'icon': Icons.inventory_2_rounded},
      {'title': 'Payments', 'icon': Icons.payment_rounded},
      {'title': 'Reports', 'icon': Icons.analytics_rounded},
      {'title': 'AI Chat Support', 'icon': Icons.chat_rounded},
      {'title': 'Settings', 'icon': Icons.settings_rounded},
    ];

    return Container(
      width: 260,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
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
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final bool isSelected = _activeSidebarMenu == index;
                return _SidebarItemTile(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _activeSidebarMenu = index;
                      _selectedTab = index;
                    });
                    if (isDrawer) {
                      Navigator.of(context).pop();
                    }
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
        return _buildOrdersTab(isDark);
      case 2:
        return _buildDeliveriesTab(isDark);
      case 3:
        return _buildUsersTab(isDark);
      case 4:
        return _buildInventoryTab(isDark);
      case 5:
        return _buildPaymentsTab(isDark);
      case 6:
        return _buildReportsTab(isDark);
      case 7:
        return _buildSupportTab(isDark);
      case 8:
        return _buildSettingsTab(isDark);
      case 99:
        return _buildCustomersTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }
}

class _SidebarItemTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;

  const _SidebarItemTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.textColor,
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
        ),
      ),
    );
  }
}

class PulsingBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool active;
  final EdgeInsetsGeometry? margin;

  const PulsingBorder({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.margin,
  });

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.1, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
