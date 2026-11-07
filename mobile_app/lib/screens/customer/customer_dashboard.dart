import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/data/ph_provinces.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../services/psgc_service.dart';
import '../../services/ai_support_service.dart';
import '../../services/customer_location_storage.dart';
import '../../widgets/water_widgets.dart';
import '../../widgets/google_map_widget.dart';
import '../../widgets/gcash_payment_modal.dart';
import '../../widgets/location_picker_modal.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'customer_styles.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final ApiService _apiService = ApiService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  int _selectedTab = 0;
  int _activeSidebarMenu = 0;

  // Order Water Form States
  String _selectedWaterType = '19L Purified Water';
  int _slimQuantity = 1;
  int _roundQuantity = 0;

  int get _totalOrderQuantity => _slimQuantity + _roundQuantity;

  String get _jugSelectionSummary {
    if (_slimQuantity > 0 && _roundQuantity > 0) {
      return '$_slimQuantity Slim, $_roundQuantity Round';
    } else if (_slimQuantity > 0) {
      return '$_slimQuantity Slim';
    } else if (_roundQuantity > 0) {
      return '$_roundQuantity Round';
    }
    return '0 Jugs';
  }
  String? _selectedProvince;
  String? _selectedCityCode;
  String? _selectedBarangayCode;
  List<PsgcPlace> _cities = [];
  List<PsgcPlace> _barangays = [];
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _orderAddressController = TextEditingController();
  LatLng? _pinnedLocation;
  bool _showManualAddressFields = false;
  String _selectedPaymentMethod = 'Cash on Delivery';

  // Support Chat States
  final List<Map<String, dynamic>> _chatMessages = [
    {
      'sender': 'AquaBot',
      'message':
          "Hello! I'm **AquaBot 💧**, your JJAASS Water Market virtual assistant.\n\nTap any inquiry topic in the **Quick Inquiry Guide** above or type your question below for instant detailed assistance!",
    },
  ];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  // Settings profile fields (persisted across rebuilds and sessions until changed again)
  static String _savedProfileName = '';
  static String _savedProfilePhone = '+63 912 345 6789';
  late TextEditingController _profileNameController;
  late TextEditingController _profilePhoneController;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final initialName = auth.currentUser?.name.isNotEmpty == true
        ? auth.currentUser!.name
        : (_savedProfileName.isNotEmpty ? _savedProfileName : 'Customer User');
    final initialPhone = _savedProfilePhone.isNotEmpty
        ? _savedProfilePhone
        : auth.currentPhone;
    _savedProfileName = initialName;
    _savedProfilePhone = initialPhone;

    _profileNameController = TextEditingController(text: initialName);
    _profilePhoneController = TextEditingController(text: initialPhone);

    // Initialize selected water type dynamically from OrderProvider catalog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (orderProvider.waterProducts.isNotEmpty) {
        setState(() {
          _selectedWaterType =
              orderProvider.waterProducts.first['name'] as String;
        });
      }
    });

    _loadDashboardData();
    _loadSavedCustomerLocation();
  }

  @override
  void dispose() {
    _orderAddressController.dispose();
    _deliveryNoteController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCustomerLocation() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final saved = await CustomerLocationStorage.loadPinnedLocation(
        userId: auth.currentUser?.id,
      );
      if (saved != null && mounted) {
        setState(() {
          _pinnedLocation = LatLng(saved.latitude, saved.longitude);
          if (saved.landmark != null &&
              saved.landmark!.isNotEmpty &&
              _deliveryNoteController.text.trim().isEmpty) {
            _deliveryNoteController.text = saved.landmark!;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _updatePinnedLocation(LatLng newCoord, {String? landmark}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _pinnedLocation = newCoord;
    });
    await CustomerLocationStorage.savePinnedLocation(
      latitude: newCoord.latitude,
      longitude: newCoord.longitude,
      landmark: landmark ??
          (_deliveryNoteController.text.trim().isNotEmpty
              ? _deliveryNoteController.text.trim()
              : null),
      userId: auth.currentUser?.id,
    );
  }

  Future<void> _clearPinnedLocation() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _pinnedLocation = null;
    });
    await CustomerLocationStorage.clearPinnedLocation(
      userId: auth.currentUser?.id,
    );
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.getCustomerDashboardData();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to load statistics.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _boxedInputDecoration({String? hint, String? label}) {
    OutlineInputBorder border(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
      labelText: label,
      labelStyle: const TextStyle(
        color: AppTheme.navyColor,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(const Color(0xFFCBD5E1)),
      enabledBorder: border(const Color(0xFFCBD5E1)),
      focusedBorder: border(AppTheme.navyColor, 2),
    );
  }

  Future<void> _onProvinceChanged(String? provinceName) async {
    if (provinceName == null) return;
    final province = phProvinces.firstWhere((p) => p.name == provinceName);
    setState(() {
      _selectedProvince = provinceName;
      _selectedCityCode = null;
      _selectedBarangayCode = null;
      _cities = [];
      _barangays = [];
      _loadingCities = true;
    });
    try {
      final cities = await PsgcService.getCitiesMunicipalities(province.code);
      if (!mounted || _selectedProvince != provinceName) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCities = false);
      Helpers.showSnackBar(
        context,
        'Could not load cities/municipalities. Check your internet connection.',
        isError: true,
      );
    }
  }

  Future<void> _onCityChanged(String? cityCode) async {
    if (cityCode == null) return;
    setState(() {
      _selectedCityCode = cityCode;
      _selectedBarangayCode = null;
      _barangays = [];
      _loadingBarangays = true;
    });
    try {
      final barangays = await PsgcService.getBarangays(cityCode);
      if (!mounted || _selectedCityCode != cityCode) return;
      setState(() {
        _barangays = barangays;
        _loadingBarangays = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBarangays = false);
      Helpers.showSnackBar(
        context,
        'Could not load barangays. Check your internet connection.',
        isError: true,
      );
    }
  }

  String _composeAddress() {
    // If manual address fields are fully filled, format standard address
    if (_selectedProvince != null &&
        _selectedCityCode != null &&
        _selectedBarangayCode != null &&
        _orderAddressController.text.trim().isNotEmpty) {
      final cityMatch = _cities.where((c) => c.code == _selectedCityCode);
      final cityName = cityMatch.isNotEmpty ? cityMatch.first.name : _selectedCityCode!;
      final brgyMatch = _barangays.where((b) => b.code == _selectedBarangayCode);
      final barangayName = brgyMatch.isNotEmpty ? brgyMatch.first.name : _selectedBarangayCode!;
      final base = '${_orderAddressController.text.trim()}, Brgy. $barangayName, $cityName, $_selectedProvince';
      if (_pinnedLocation != null) {
        return '$base (GPS: ${_pinnedLocation!.latitude.toStringAsFixed(6)}, ${_pinnedLocation!.longitude.toStringAsFixed(6)})';
      }
      return base;
    }

    // If customer used map pin without filling manual address dropdowns
    if (_pinnedLocation != null) {
      final lat = _pinnedLocation!.latitude.toStringAsFixed(6);
      final lng = _pinnedLocation!.longitude.toStringAsFixed(6);
      final houseOrLandmark = _orderAddressController.text.trim().isNotEmpty
          ? _orderAddressController.text.trim()
          : _deliveryNoteController.text.trim();

      if (houseOrLandmark.isNotEmpty) {
        return '📍 Pinned GPS Delivery ($lat, $lng) — $houseOrLandmark';
      }
      return '📍 Pinned GPS Delivery ($lat, $lng)';
    }

    return 'Pending Delivery Pin';
  }

  void _resetOrderForm(OrderProvider orderProvider) {
    _selectedWaterType = orderProvider.waterProducts.isNotEmpty
        ? orderProvider.waterProducts.first['name'] as String
        : '19L Purified Water';
    _slimQuantity = 1;
    _roundQuantity = 0;
    _selectedProvince = null;
    _selectedCityCode = null;
    _selectedBarangayCode = null;
    _cities = [];
    _barangays = [];
    _loadingCities = false;
    _loadingBarangays = false;
    _orderAddressController.clear();
    _deliveryNoteController.clear();
    // Do NOT clear _pinnedLocation: customer's permanent pinned location is retained!
    _selectedPaymentMethod = 'Cash on Delivery';
  }

  void _submitWaterOrder() async {
    // If GPS pin is NOT set, require manual address fields
    if (_pinnedLocation == null) {
      if (_selectedProvince == null) {
        Helpers.showSnackBar(
          context,
          'Please pin your delivery location on the map or select a province.',
          isError: true,
        );
        return;
      }
      if (_selectedCityCode == null) {
        Helpers.showSnackBar(
          context,
          'Please select a city / municipality.',
          isError: true,
        );
        return;
      }
      if (_selectedBarangayCode == null) {
        Helpers.showSnackBar(context, 'Please select a barangay.', isError: true);
        return;
      }
      if (_orderAddressController.text.trim().isEmpty) {
        Helpers.showSnackBar(
          context,
          'Please enter your house no. / street or pin your location.',
          isError: true,
        );
        return;
      }
    }

    if (_totalOrderQuantity < 1) {
      Helpers.showSnackBar(
        context,
        'Please select at least 1 container (Slim or Round).',
        isError: true,
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    final match = orderProvider.waterProducts.firstWhere(
      (p) => p['name'] == _selectedWaterType,
      orElse: () => orderProvider.waterProducts.first,
    );
    final pricePerJug = (match['price'] as num).toDouble();
    final waterTypeName = match['name'] as String;
    final submittedPaymentMethod = _selectedPaymentMethod;

    final customerName = _savedProfileName.isNotEmpty
        ? _savedProfileName
        : (user?.name ?? 'Customer');
    final customerPhone = _savedProfilePhone.isNotEmpty
        ? _savedProfilePhone
        : '+63 912 345 6789';

    final jugDescription = _slimQuantity > 0 && _roundQuantity > 0
        ? '($_slimQuantity Slim, $_roundQuantity Round)'
        : (_slimQuantity > 0 ? '($_slimQuantity Slim)' : '($_roundQuantity Round)');

    final newOrder = await orderProvider.placeOrder(
      customerId: user?.id ?? '',
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: _composeAddress(),
      waterType: '$waterTypeName $jugDescription',
      quantity: _totalOrderQuantity,
      pricePerUnit: pricePerJug,
      paymentMethod: submittedPaymentMethod,
      deliveryNote: _deliveryNoteController.text.trim(),
      latitude: _pinnedLocation?.latitude,
      longitude: _pinnedLocation?.longitude,
    );

    if (mounted) {
      Helpers.showSnackBar(
        context,
        'Order ${newOrder.id} placed successfully!',
      );
      setState(() {
        _resetOrderForm(orderProvider);
        _selectedTab = 2; // Route directly to My Deliveries
        _activeSidebarMenu = 2;
      });

      if (submittedPaymentMethod == 'GCash') {
        _showGcashPaymentDialog(
          newOrder,
          Theme.of(context).brightness == Brightness.dark,
        );
      }
    }
  }

  void _showGcashPaymentDialog(OrderModel order, bool isDark) {
    GCashPaymentModal.show(
      context,
      order: order,
      paymentService: _paymentService,
      isDark: isDark,
      role: 'customer',
      onPaymentSuccess: () {
        if (mounted) {
          setState(() {
            _selectedTab = 2; // Switch to My Deliveries
            _activeSidebarMenu = 2;
          });
        }
      },
    );
  }

  Future<void> _showCancelOrderDialog(OrderModel order) async {
    final reasons = <String>[
      'Pinned wrong location on map',
      'Entered wrong delivery address',
      'Want to change water/jug type or quantity',
      'Changed my mind',
    ];
    String selectedReason = reasons.first;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cancel Order ${order.id}?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navyColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.itemsSummary,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppTheme.navyColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.deliveryAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select a reason for cancelling:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...reasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedReason = reason;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFEF2F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFCBD5E1),
                                width: isSelected ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text(
                    'Keep Order',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('reorder'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel & Re-Order',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel Order',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == null || !mounted) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.cancelCustomerOrder(
      orderId: order.id,
      reason: selectedReason,
    );

    if (!mounted) return;
    if (success) {
      Helpers.showSnackBar(
        context,
        'Order ${order.id} has been cancelled ($selectedReason).',
      );
      if (action == 'reorder') {
        setState(() {
          _selectedTab = 1; // Switch directly to Order Water tab
          _activeSidebarMenu = 1;
        });
      }
    } else {
      Helpers.showSnackBar(
        context,
        'Could not cancel order ${order.id}. It may already be completed or cancelled.',
        isError: true,
      );
    }
  }

  void _sendSupportMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isChatLoading) return; // Prevent multiple requests at once
    final userQuery = text.trim();

    setState(() {
      _chatMessages.add({'sender': 'Customer', 'message': userQuery});
      _chatInputController.clear();
      _isChatLoading = true;
      _chatMessages.add({'sender': 'AquaBot', 'message': 'Thinking...'});
    });

    _scrollToBottom();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    try {
      final response = await AiSupportService.getChatResponse(
        query: userQuery,
        isDriver: false,
        isAdmin: false,
        userId: user?.id ?? '',
        userName: user?.name ?? 'Customer',
        orderProvider: orderProvider,
      );

      if (mounted) {
        setState(() {
          if (_chatMessages.isNotEmpty &&
              _chatMessages.last['message'] == 'Thinking...') {
            _chatMessages.removeLast();
          }
          _chatMessages.add({'sender': 'AquaBot', 'message': response});
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_chatMessages.isNotEmpty &&
              _chatMessages.last['message'] == 'Thinking...') {
            _chatMessages.removeLast();
          }
          _chatMessages.add({
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
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const WaterDropletLogo(size: 28),
                  ),
                  const SizedBox(width: 10),
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
                          'JJAASS Water Market',
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
                    child: CircularProgressIndicator(color: AppTheme.navyColor),
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
                    '${auth.currentUser?.name ?? "Customer"}!',
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
              style: const TextStyle(
                color: AppTheme.navyColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search orders, services...',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 19,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 8),
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
          IconButton(
            onPressed: () {
              setState(() {
                _selectedTab = 4;
                _activeSidebarMenu = 4;
              });
            },
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.navyColor,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              setState(() {
                _profileNameController.text = _savedProfileName;
                _profilePhoneController.text = _savedProfilePhone;
                _selectedTab = 5;
                _activeSidebarMenu = 5;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: AppTheme.navyColor,
              child: Text(
                (auth.currentUser?.name ?? 'C').substring(0, 1).toUpperCase(),
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
        return 'Customer Portal Dashboard';
      case 1:
        return 'Order Fresh Water Delivery';
      case 2:
        return 'My Deliveries Status';
      case 3:
        return 'Payment Transactions History';
      case 4:
        return 'AquaBot Support Desk';
      case 5:
        return 'Profile Settings';
      default:
        return 'Customer Dashboard';
    }
  }

  Widget _buildSidebar(bool isDark, {bool isDrawer = false}) {
    final menuItems = [
      {'title': 'Dashboard', 'icon': Icons.home_rounded},
      {'title': 'Order Water', 'icon': Icons.local_drink_rounded},
      {'title': 'My Deliveries', 'icon': Icons.local_shipping_rounded},
      {'title': 'Payment History', 'icon': Icons.payment_rounded},
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
                      if (index == 5) {
                        _profileNameController.text = _savedProfileName;
                        _profilePhoneController.text = _savedProfilePhone;
                      }
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Column(
                children: [
                  WaterJugIllustration(width: 68, height: 76),
                  SizedBox(height: 8),
                  Text(
                    'Fresh & Pure Water',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Stay hydrated, stay healthy.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ),
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
        return _buildOrderWaterTab(isDark);
      case 2:
        return _buildDeliveriesTab(isDark);
      case 3:
        return _buildPaymentHistoryTab(isDark);
      case 4:
        return _buildAiSupportTab(isDark);
      case 5:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }

  // TAB 0: DASHBOARD / OVERVIEW
  Widget _buildOverviewTab(bool isDark, double width) {
    final isDesktop = width >= 1100;
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final customerId = user?.id ?? '';

    final myOrders = orderProvider.getCustomerOrders(customerId);
    final activeOrdersCount = myOrders
        .where(
          (o) =>
              o.orderStatus != OrderStatus.completed &&
              o.orderStatus != OrderStatus.cancelled,
        )
        .length;

    final pendingGcashOrders = myOrders
        .where(
          (o) =>
              o.paymentStatus == 'Pending' &&
              o.paymentMethod == 'GCash' &&
              o.orderStatus != OrderStatus.cancelled,
        )
        .toList();

    final isSmall = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 12.0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingGcashOrders.isNotEmpty) ...[
            InkWell(
              onTap: () =>
                  _showGcashPaymentDialog(pendingGcashOrders.first, isDark),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: CustomerDecorations.gcashBanner,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unpaid Order ${pendingGcashOrders.first.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Total: ₱${pendingGcashOrders.first.totalAmount.toStringAsFixed(2)} • Tap to open GCash checkout',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFF007DFE),
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Pay Now',
                            style: TextStyle(
                              color: Color(0xFF007DFE),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildStatCard(
                'Active Orders',
                '$activeOrdersCount',
                'Current deliveries',
                Icons.local_drink_rounded,
                isDark ? const Color(0xFF38BDF8) : AppTheme.primaryColor,
                isDark,
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(children: [_buildTransactionsCard(isDark)]),
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
                _buildTransactionsCard(isDark),
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

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return CustomerStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      color: color,
      isDark: isDark,
    );
  }

  Widget _buildTransactionsCard(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final myOrders = orderProvider.getCustomerOrders(user?.id ?? '');

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: CustomerDecorations.card(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedTab = 3),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          myOrders.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No transactions yet.',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: min(myOrders.length, 4),
                  itemBuilder: (context, index) {
                    final tx = myOrders[index];
                    final isCancelled = tx.orderStatus == OrderStatus.cancelled;
                    final canCancel =
                        tx.orderStatus != OrderStatus.completed && !isCancelled;
                    final isCompleted =
                        tx.orderStatus == OrderStatus.completed ||
                        tx.paymentStatus == 'Paid';
                    final color = isCancelled
                        ? const Color(0xFFDC2626)
                        : isCompleted
                        ? (isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7))
                        : (isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: isDark ? 0.2 : 0.08,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCancelled
                                    ? Icons.cancel_rounded
                                    : Icons.payment_rounded,
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.txnId.isNotEmpty
                                        ? tx.txnId
                                        : (tx.id.startsWith('#') ? tx.id : 'Order #${tx.id}'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${tx.id.startsWith('#') ? tx.id : 'Order #${tx.id}'} • ${tx.createdAt.toString().split(' ')[0]}',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  tx.formattedTotal,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: isDark ? 0.22 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: color.withValues(
                                        alpha: isDark ? 0.45 : 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isCancelled
                                        ? 'Cancelled'
                                        : tx.paymentStatus,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (canCancel) ...[
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _showCancelOrderDialog(tx),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFECACA),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel Order',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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

  Widget _buildQuickActionsCard(bool isDark) {
    final actions = [
      {
        'title': 'Order Water',
        'icon': Icons.local_drink_rounded,
        'color': AppTheme.navyColor,
        'tab': 1,
      },
      {
        'title': 'Track Deliveries',
        'icon': Icons.local_shipping_rounded,
        'color': AppTheme.primaryColor,
        'tab': 2,
      },
      {
        'title': 'Chat Support',
        'icon': Icons.support_agent_rounded,
        'color': AppTheme.accentColor,
        'tab': 4,
      },
      {
        'title': 'Profile Settings',
        'icon': Icons.manage_accounts_rounded,
        'color': const Color(0xFF059669),
        'tab': 5,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: CustomerDecorations.card(isDark: isDark),
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
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTab = act['tab'] as int;
                    _activeSidebarMenu = act['tab'] as int;
                  });
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
                      Icon(act['icon'] as IconData, color: color, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        act['title'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
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
      decoration: CustomerDecorations.card(isDark: isDark),
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
                        'Hello! I\'m AquaBot 💧 How can I help you today?',
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
                    controller: _chatInputController,
                    onSubmitted: (val) {
                      _sendSupportMessage(val);
                      setState(() {
                        _selectedTab = 4; // Route to full support tab
                        _activeSidebarMenu = 4;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.navyColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 10),
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
                    _sendSupportMessage(_chatInputController.text);
                    setState(() {
                      _selectedTab = 4; // Route to full support tab
                      _activeSidebarMenu = 4;
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

  // TAB 1: ORDER WATER FORM
  Widget _buildOrderWaterTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final screenPadding = isMobile ? 12.0 : 24.0;
    final cardPadding = isMobile ? 14.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Place a Fresh Water Order',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppTheme.navyColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: CustomerDecorations.card(isDark: isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product / Order Type Selection (Refill vs Set A)
                const Text(
                  'Select Product / Order Type',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyColor,
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  children: orderProvider.waterProducts.map((prod) {
                    final name = prod['name'] as String;
                    final price = (prod['price'] as num).toDouble();
                    final desc = (prod['description'] as String?) ?? '';
                    final isSelected = _selectedWaterType == name;
                    final isSetA = name.toLowerCase().contains('set a');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedWaterType = name;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.navyColor
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 2.0 : 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.navyColor
                                      : AppTheme.primaryColor.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isSetA
                                      ? Icons.inventory_2_rounded
                                      : Icons.water_drop_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.navyColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF475569),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₱${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.navyColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppTheme.navyColor
                                        : const Color(0xFF94A3B8),
                                    size: 19,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Jug Type Selection with Dedicated Quantities
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Select Jug Types & Quantity',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Max: 20 jugs total',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.navyColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 205,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      SizedBox(
                        width: isMobile ? 150.0 : 180.0,
                        child: _buildJugTypeOptionCard(
                          title: '5-Gallon Slim',
                          subtitle: 'Faucet & Handle',
                          imageAsset: 'assets/images/slim_container.jpg',
                          quantity: _slimQuantity,
                          onDecrement: () {
                            if (_slimQuantity > 0) {
                              setState(() => _slimQuantity--);
                            }
                          },
                          onIncrement: () {
                            if (_totalOrderQuantity < 20) {
                              setState(() => _slimQuantity++);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: isMobile ? 150.0 : 180.0,
                        child: _buildJugTypeOptionCard(
                          title: '5-Gallon Round',
                          subtitle: 'For Dispenser',
                          imageAsset: 'assets/images/round_container.jpg',
                          quantity: _roundQuantity,
                          onDecrement: () {
                            if (_roundQuantity > 0) {
                              setState(() => _roundQuantity--);
                            }
                          },
                          onIncrement: () {
                            if (_totalOrderQuantity < 20) {
                              setState(() => _roundQuantity++);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Simple Total Badge
                Builder(
                  builder: (context) {
                    final match = orderProvider.waterProducts.firstWhere(
                      (p) => p['name'] == _selectedWaterType,
                      orElse: () => orderProvider.waterProducts.isNotEmpty
                          ? orderProvider.waterProducts.first
                          : {'price': 35.0},
                    );
                    final pricePerJug = (match['price'] as num?)?.toDouble() ?? 35.0;
                    final totalCost = _totalOrderQuantity * pricePerJug;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _totalOrderQuantity > 0
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _totalOrderQuantity > 0
                              ? AppTheme.primaryColor.withValues(alpha: 0.3)
                              : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _totalOrderQuantity > 0
                                ? Icons.shopping_bag_outlined
                                : Icons.warning_amber_rounded,
                            size: 20,
                            color: _totalOrderQuantity > 0
                                ? AppTheme.navyColor
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _totalOrderQuantity > 0
                                  ? 'Total: $_totalOrderQuantity ${_totalOrderQuantity == 1 ? 'jug' : 'jugs'} ($_jugSelectionSummary) • ₱${totalCost.toStringAsFixed(2)}'
                                  : 'Please select at least 1 jug above (Slim or Round)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _totalOrderQuantity > 0
                                    ? AppTheme.navyColor
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Delivery Location Section
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Delivery Location',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    if (_pinnedLocation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                            SizedBox(width: 4),
                            Text(
                              'Permanent Pin Active',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Primary Address Summary Badge (when Pinned)
                if (_pinnedLocation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Exact GPS Location Pinned',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF15803D),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pin: ${_pinnedLocation!.latitude.toStringAsFixed(6)}, ${_pinnedLocation!.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF166534),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await LocationPickerModal.show(
                                  context,
                                  initialLocation: _pinnedLocation,
                                );
                                if (result != null) {
                                  await _updatePinnedLocation(result);
                                  if (!mounted) return;
                                  Helpers.showSnackBar(
                                    context,
                                    'Permanent pin updated and saved successfully!',
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
                              label: const Text(
                                'Edit Pin',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF15803D)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Delivery is set to your map pin! No need to fill address dropdowns below.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF166534),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Optional House / Landmark field
                  const Text(
                    'Landmark or House Note (optional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _orderAddressController,
                    maxLines: 1,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: _boxedInputDecoration(
                      hint: 'e.g. Near blue gate, Purok 4, 2nd floor...',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Toggle to enter manual address if customer wants to override
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showManualAddressFields = !_showManualAddressFields;
                        });
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF475569),
                      ),
                      icon: Icon(
                        _showManualAddressFields
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _showManualAddressFields
                            ? 'Hide manual address dropdowns'
                            : 'Or specify province / city manually (optional)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ] else ...[
                  // When NOT pinned yet: Prompt to pin on map first (Recommended)
                  InkWell(
                    onTap: () async {
                      final result = await LocationPickerModal.show(
                        context,
                        initialLocation: _pinnedLocation,
                      );
                      if (result != null) {
                        await _updatePinnedLocation(result);
                        if (!mounted) return;
                        Helpers.showSnackBar(
                          context,
                          'Permanent delivery location saved! Address section auto-completed.',
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.2),
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
                              Icons.add_location_alt_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pin Delivery Location on Map (Recommended)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tap map to set your house once — permanent & no typing needed!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await LocationPickerModal.show(
                                context,
                                initialLocation: _pinnedLocation,
                              );
                              if (result != null) {
                                await _updatePinnedLocation(result);
                                if (!mounted) return;
                                Helpers.showSnackBar(
                                  context,
                                  'Permanent delivery location saved! Address section auto-completed.',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Set Pin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Manual dropdowns: Shown if not pinned, OR if customer explicitly expanded manual address
                if (_pinnedLocation == null || _showManualAddressFields) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Province',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('province_$_selectedProvince'),
                    initialValue: _selectedProvince,
                    isExpanded: true,
                    decoration: _boxedInputDecoration(hint: 'Select Province'),
                    items: phProvincesSorted
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.name,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _onProvinceChanged,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'City / Municipality',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('city_${_selectedProvince}_${_cities.length}'),
                    initialValue: _selectedCityCode,
                    isExpanded: true,
                    decoration: _boxedInputDecoration(
                      hint: _loadingCities
                          ? 'Loading cities/municipalities...'
                          : 'Select City / Municipality',
                    ),
                    items: _cities
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.code,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _cities.isEmpty ? null : _onCityChanged,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Barangay',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'brgy_${_selectedCityCode}_${_barangays.length}',
                    ),
                    initialValue: _selectedBarangayCode,
                    isExpanded: true,
                    decoration: _boxedInputDecoration(
                      hint: _loadingBarangays
                          ? 'Loading barangays...'
                          : 'Select Barangay',
                    ),
                    items: _barangays
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.code,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _barangays.isEmpty
                        ? null
                        : (val) => setState(() => _selectedBarangayCode = val),
                  ),
                  if (_pinnedLocation == null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'House No. / Street / Purok',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _orderAddressController,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: _boxedInputDecoration(
                        hint: 'House no., street, purok / landmark',
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),

                // Delivery Note / Preference
                const Text(
                  'Delivery Note / Preference (optional)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _deliveryNoteController,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(color: AppTheme.navyColor),
                  decoration: _boxedInputDecoration(
                    hint:
                        'e.g. Leave at the gate, call upon arrival, deliver after 5 PM...',
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Method
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyColor,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('payment_$_selectedPaymentMethod'),
                  initialValue: _selectedPaymentMethod,
                  isExpanded: true,
                  style: const TextStyle(
                    color: AppTheme.navyColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  decoration: _boxedInputDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'Cash on Delivery',
                      child: Text(
                        'Cash on Delivery (COD)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'GCash',
                      child: Text(
                        'GCash Mobile Payment',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPaymentMethod = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _submitWaterOrder,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: AppTheme.navyColor,
                  ),
                  child: const Text(
                    'Confirm Order Delivery',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  Widget _buildJugTypeOptionCard({
    required String title,
    required String subtitle,
    required String imageAsset,
    required int quantity,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final isSelected = quantity > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.navyColor : const Color(0xFFCBD5E1),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 80,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Image.asset(imageAsset, fit: BoxFit.contain),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.navyColor : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isSelected ? '$quantity' : '0',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Stepper Quantity Row for this Jug Type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.navyColor : const Color(0xFFCBD5E1),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: quantity > 0 ? onDecrement : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: quantity > 0 ? AppTheme.navyColor : Colors.grey.shade400,
                    ),
                  ),
                ),
                Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? AppTheme.navyColor : const Color(0xFF64748B),
                  ),
                ),
                InkWell(
                  onTap: _totalOrderQuantity < 20 ? onIncrement : null,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: AppTheme.navyColor,
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

  // TAB 2: MY DELIVERIES STATUS TRACKER
  Widget _buildDeliveriesTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final myOrders = orderProvider.getCustomerOrders(user?.id ?? '');

    final activeDelivery =
        myOrders.any((o) => o.orderStatus == OrderStatus.onDelivery)
        ? myOrders.firstWhere((o) => o.orderStatus == OrderStatus.onDelivery)
        : (myOrders.any((o) => o.orderStatus == OrderStatus.assigned)
            ? myOrders.firstWhere((o) => o.orderStatus == OrderStatus.assigned)
            : null);
    final pendingGcashOrders = myOrders
        .where(
          (o) =>
              o.paymentStatus == 'Pending' &&
              o.paymentMethod == 'GCash' &&
              o.orderStatus != OrderStatus.cancelled,
        )
        .toList();

    final isSmall = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isSmall ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Track Deliveries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (pendingGcashOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007DFE).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF007DFE).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 14,
                        color: Color(0xFF007DFE),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pendingGcashOrders.length} Unpaid GCash',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007DFE),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (pendingGcashOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () =>
                  _showGcashPaymentDialog(pendingGcashOrders.first, isDark),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007DFE), Color(0xFF0056B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007DFE).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payment_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Action Required: Pay GCash for ${pendingGcashOrders.first.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Amount: ₱${pendingGcashOrders.first.totalAmount.toStringAsFixed(2)} • Tap to complete payment',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(
                          color: Color(0xFF007DFE),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (activeDelivery != null) ...[
            _buildActiveDeliveryTracker(activeDelivery, isDark),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: myOrders.isEmpty
                ? const Center(child: Text('No orders yet.'))
                : ListView.builder(
                    itemCount: myOrders.length,
                    itemBuilder: (context, index) {
                      final order = myOrders[index];
                      final isDone = order.orderStatus == OrderStatus.completed;
                      final isCancelled =
                          order.orderStatus == OrderStatus.cancelled;
                      final canCancel = !isDone && !isCancelled;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: order.orderStatus.color.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isDone
                                      ? Icons.check_circle_rounded
                                      : isCancelled
                                      ? Icons.cancel_rounded
                                      : Icons.local_shipping_rounded,
                                  color: order.orderStatus.color,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.itemsSummary,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      order.deliveryAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    if (order.driverName != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_pin_rounded,
                                            size: 14,
                                            color: AppTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Driver: ${order.driverName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    order.createdAt.toString().split(' ')[0],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  if (order.paymentStatus == 'Pending' &&
                                      order.paymentMethod == 'GCash' &&
                                      !isCancelled) ...[
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _showGcashPaymentDialog(
                                        order,
                                        isDark,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF007DFE),
                                              Color(0xFF0056B3),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF007DFE,
                                              ).withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bolt_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              '⚡ Pay GCash',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: order.orderStatus.color.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      order.orderStatus.displayName,
                                      style: TextStyle(
                                        color: order.orderStatus.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  if (canCancel) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () =>
                                          _showCancelOrderDialog(order),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.cancel_outlined,
                                              size: 13,
                                              color: Color(0xFFDC2626),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Cancel Order',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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

  // TAB 3: PAYMENT HISTORY
  Widget _buildPaymentHistoryTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final myOrders = orderProvider.getCustomerOrders(user?.id ?? '');

    final isSmall = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isSmall ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoices & Transactions History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: myOrders.isEmpty
                ? const Center(child: Text('No transaction history yet.'))
                : ListView.builder(
                    itemCount: myOrders.length,
                    itemBuilder: (context, index) {
                      final tx = myOrders[index];
                      final isPaid = tx.paymentStatus == 'Paid';
                      final color = isPaid
                          ? Colors.green
                          : Colors.amber.shade700;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.08),
                            child: Icon(Icons.payment_rounded, color: color),
                          ),
                          title: Text(
                            tx.txnId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            'Order: ${tx.id} • ${tx.paymentMethod}\nDate: ${tx.createdAt.toString().split('.')[0]}',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                tx.formattedTotal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (tx.paymentStatus == 'Pending' &&
                                  tx.paymentMethod == 'GCash') ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () =>
                                      _showGcashPaymentDialog(tx, isDark),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF007DFE),
                                          Color(0xFF0056B3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          '⚡ Pay GCash',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.paymentStatus,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  // TAB 4: AI SUPPORT DESK (Selection-type inquiry accordion & Logo-themed interface)
  Widget _buildAiSupportTab(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.all(isSmall ? 8.0 : 20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          // Dynamically scale max accordion height so it NEVER exceeds available view space
          final maxAccordionHeight = totalHeight > 550
              ? (isSmall ? 180.0 : 230.0)
              : (totalHeight * 0.32).clamp(110.0, 160.0);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navyColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // JJAASS Water Market Logo Brand Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.navyColor, AppTheme.primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo_icon.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, error, stackTrace) => const Icon(
                              Icons.water_drop_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AquaBot AI Assistant',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 7, height: 7),
                                ),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'JJAASS Water Market • Online',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
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
                        tooltip: 'Reset Chat',
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _chatMessages.clear();
                            _chatMessages.add({
                              'sender': 'AquaBot',
                              'message':
                                  "Hello! I'm **AquaBot 💧**, your JJAASS Water Market assistant.\n\nChoose any topic from the **Quick Inquiry Guide** above, or type your question below for instant detailed guidance!",
                            });
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Collapsible Quick Inquiry FAQ Accordion with Safe Bounded Height
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
                      key: const PageStorageKey('ai_inquiry_accordion_main'),
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
                        'Tap to browse 5 inquiry topics for instant answers',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxAccordionHeight,
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(right: 6),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  _buildInquiryCategoryTile(
                                    title: '💧 Products & Pricing',
                                    color: const Color(0xFF0284C7),
                                    questions: [
                                      'What is the difference between Refill (₱30) and Set A (₱230)?',
                                      'Should I choose 5-Gallon Slim or 5-Gallon Round?',
                                      'What are all your water products and prices?',
                                    ],
                                  ),
                                  _buildInquiryCategoryTile(
                                    title: '🚚 Live Orders & Tracking',
                                    color: const Color(0xFF1D63B8),
                                    questions: [
                                      'Where is my order / delivery right now?',
                                      'How does the permanent GPS location pin work?',
                                      'What is the maximum quantity of jugs per order?',
                                    ],
                                  ),
                                  _buildInquiryCategoryTile(
                                    title: '💳 Payment & Checkout',
                                    color: const Color(0xFF0F2B5C),
                                    questions: [
                                      'How do I pay using GCash (PayMongo)?',
                                      'What are the guidelines for Cash on Delivery (COD)?',
                                    ],
                                  ),
                                  _buildInquiryCategoryTile(
                                    title: '📍 Store Location & Hours',
                                    color: const Color(0xFF0369A1),
                                    questions: [
                                      'Where is JJAASS Water Market located and what are your store hours?',
                                      'What are the customer service hotlines?',
                                    ],
                                  ),
                                  _buildInquiryCategoryTile(
                                    title: '⭐ AquaLoyalty Points & Perks',
                                    color: const Color(0xFFD97706),
                                    questions: [
                                      'How do AquaLoyalty points work and how do I earn rewards?',
                                      'How many points do I currently have?',
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

                // Scrollable Chat Message List with JJAASS Logo-Themed Bubbles
                Expanded(
                  child: ListView.builder(
                    controller: _chatScrollController,
                padding: const EdgeInsets.all(14.0),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
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
                                    ClipOval(
                                      child: Image.asset(
                                        'assets/images/logo_icon.jpg',
                                        width: 14,
                                        height: 14,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, error, stackTrace) => const Icon(
                                          Icons.water_drop_rounded,
                                          size: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
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

            // Chat Input Bar with Logo Colors
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      onSubmitted: _sendSupportMessage,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type your question here...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
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
                    onTap: () => _sendSupportMessage(_chatInputController.text),
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
        ),
      );
    },
  ),
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
          dense: true,
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
                      color: AppTheme.primaryColor,
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

  // TAB 6: SETTINGS
  Widget _buildSettingsTab(bool isDark) {
    final isSmall = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _profileNameController,
                  style: const TextStyle(color: AppTheme.navyColor),
                  decoration: _boxedInputDecoration(label: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _profilePhoneController,
                  style: const TextStyle(color: AppTheme.navyColor),
                  decoration: _boxedInputDecoration(label: 'Phone Number'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final newName = _profileNameController.text.trim();
                    final newPhone = _profilePhoneController.text.trim();
                    if (newName.isEmpty || newPhone.isEmpty) {
                      Helpers.showSnackBar(
                        context,
                        'Name and Phone Number cannot be empty.',
                        isError: true,
                      );
                      return;
                    }
                    setState(() {
                      _savedProfileName = newName;
                      _savedProfilePhone = newPhone;
                    });
                    final auth = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await auth.updateProfile(name: newName, phone: newPhone);
                    if (!mounted) return;
                    Helpers.showSnackBar(
                      context,
                      'Profile information saved successfully!',
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Permanent Delivery Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your permanent pinned location is used automatically across all orders without having to re-enter your address.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pinnedLocation != null
                    ? const Color(0xFF86EFAC)
                    : (isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _pinnedLocation != null
                            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _pinnedLocation != null
                            ? Icons.location_on_rounded
                            : Icons.add_location_alt_rounded,
                        color: _pinnedLocation != null
                            ? const Color(0xFF16A34A)
                            : AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pinnedLocation != null
                                ? 'Saved Permanent Pin'
                                : 'No Location Pinned Yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _pinnedLocation != null
                                  ? const Color(0xFF15803D)
                                  : (isDark ? Colors.white : AppTheme.navyColor),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _pinnedLocation != null
                                ? 'Coordinates: ${_pinnedLocation!.latitude.toStringAsFixed(6)}, ${_pinnedLocation!.longitude.toStringAsFixed(6)}'
                                : 'Pin your house/building on the map to enable fast 1-tap ordering.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _pinnedLocation != null
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await LocationPickerModal.show(
                          context,
                          initialLocation: _pinnedLocation,
                        );
                        if (result != null) {
                          await _updatePinnedLocation(result);
                          if (!mounted) return;
                          Helpers.showSnackBar(
                            context,
                            'Permanent delivery location saved successfully!',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        _pinnedLocation != null
                            ? Icons.edit_location_alt_rounded
                            : Icons.pin_drop_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _pinnedLocation != null
                            ? 'Change Permanent Pin'
                            : 'Set Permanent Pin',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_pinnedLocation != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _clearPinnedLocation();
                          if (!mounted) return;
                          Helpers.showSnackBar(
                            context,
                            'Saved permanent location cleared.',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Clear Pin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryTracker(OrderModel activeDelivery, bool isDark) {
    int currentStep = 0;
    switch (activeDelivery.orderStatus) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        currentStep = 0;
        break;
      case OrderStatus.assigned:
        currentStep = 1;
        break;
      case OrderStatus.onDelivery:
        currentStep = 2;
        break;
      case OrderStatus.completed:
        currentStep = 3;
        break;
      case OrderStatus.cancelled:
        currentStep = -1;
        break;
    }

    final steps = [
      {'title': 'Confirmed', 'icon': Icons.receipt_long_rounded},
      {'title': 'Assigned', 'icon': Icons.inventory_2_rounded},
      {'title': 'On the Way', 'icon': Icons.two_wheeler_rounded},
      {'title': 'Delivered', 'icon': Icons.check_circle_rounded},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live Order #${activeDelivery.id.replaceAll(RegExp(r"^#+"), "")}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F2B5C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeDelivery.orderStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activeDelivery.orderStatus.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: activeDelivery.orderStatus.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grab-style 4-step progress tracker
          Row(
            children: List.generate(steps.length, (idx) {
              final step = steps[idx];
              final isDone = currentStep > idx;
              final isCurrent = currentStep == idx;
              final color = isDone
                  ? const Color(0xFF10B981)
                  : (isCurrent ? const Color(0xFF1D63B8) : const Color(0xFF94A3B8));

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (idx > 0)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: isDone || isCurrent
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone || isCurrent
                                ? color
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone || isCurrent
                                  ? color
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            isDone ? Icons.check_rounded : (step['icon'] as IconData),
                            color: isDone || isCurrent ? Colors.white : const Color(0xFF94A3B8),
                            size: 14,
                          ),
                        ),
                        if (idx < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent
                            ? const Color(0xFF1D63B8)
                            : (isDone ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Rider info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFF1D63B8),
                  child: Icon(
                    Icons.two_wheeler_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeDelivery.driverName?.isNotEmpty == true
                            ? activeDelivery.driverName!
                            : 'Assigning Delivery Rider...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        activeDelivery.itemsSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeDelivery.latitude != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text(
                          'Pin Set',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Live Google Map Widget with OSRM road polyline & live ETA
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GoogleMapWidget(
                destinationLat: activeDelivery.latitude,
                destinationLng: activeDelivery.longitude,
                destinationAddress: activeDelivery.deliveryAddress,
                isDriverView: false,
                orderId: activeDelivery.id,
              ),
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
