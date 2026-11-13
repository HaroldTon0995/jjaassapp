import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'compliance_permit_service.dart';
import 'delivery_issue_service.dart';

class AiSupportService {
  static const List<String> _geminiModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];
  static const String marketAddress = 'Pili Iraya, Bacacay, Albay';
  static const double _depotLat = 14.5995;
  static const double _depotLng = 120.9842;

  // Runtime Gemini API key override (can be set in-app or via chat)
  static String _runtimeApiKey = '';

  // Multi-turn conversation memory per user role/session
  static final Map<String, List<Map<String, dynamic>>> _conversationHistory = {};

  static String get activeApiKey {
    if (_runtimeApiKey.trim().isNotEmpty) {
      return _runtimeApiKey.trim();
    }
    return AppConstants.geminiApiKey.trim();
  }

  static bool get hasConfiguredApiKey => activeApiKey.isNotEmpty;

  static void setApiKey(String key) {
    _runtimeApiKey = key.trim();
  }

  /// Fetches response from Gemini AI support engine.
  /// Falls back to a comprehensive omniscient role-aware engine if Gemini API key is not set or network fails.
  static Future<String> getChatResponse({
    required String query,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) async {
    final trimmed = query.trim();
    final cleanQuery = trimmed.toLowerCase();

    // Allow setting Gemini API key directly in chat by pasting an AIza... key
    final apiKeyMatch =
        RegExp(r'(AIza[0-9A-Za-z\-_]{31,45})').firstMatch(trimmed);
    if (apiKeyMatch != null) {
      final extractedKey = apiKeyMatch.group(1)!;
      setApiKey(extractedKey);
      return "✅ **Gemini AI Key Activated!**\n\nAquaBot is now connected to **Google Gemini (`gemini-2.5-flash`)** with full live knowledge of **Admin, Driver, and Customer** workflows. Ask me anything about orders, inventory, deliveries, defect claims, permits, or station operations!";
    }

    // Quick intercept for route optimization if requested by driver or admin
    if ((isDriver || isAdmin) &&
        (cleanQuery.contains('optimize route') ||
            cleanQuery.contains('optimal route') ||
            cleanQuery.contains('route sequence') ||
            (isDriver &&
                (cleanQuery == 'route' ||
                    cleanQuery.contains('optimize') ||
                    cleanQuery.contains('sequence'))))) {
      await Future.delayed(const Duration(milliseconds: 400));
      return _optimizeRouteResponse(userId, orderProvider);
    }

    if (hasConfiguredApiKey) {
      try {
        return await _getGeminiResponse(
          query: trimmed,
          isDriver: isDriver,
          isAdmin: isAdmin,
          userId: userId,
          userName: userName,
          orderProvider: orderProvider,
        );
      } catch (e) {
        debugPrint(
          'Gemini API request failed, falling back to omniscient local engine: $e',
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 450));

    // Unified Omniscient Cross-Role Local Engine
    return _getLocalFallbackResponse(
      query: cleanQuery,
      rawQuery: trimmed,
      isDriver: isDriver,
      isAdmin: isAdmin,
      userId: userId,
      userName: userName,
      orderProvider: orderProvider,
    );
  }

  /// Builds full cross-role context payload & requests Google Gemini API with automatic model fallback
  static Future<String> _getGeminiResponse({
    required String query,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) async {
    final String contextData = _gatherSystemContext(
      isDriver: isDriver,
      isAdmin: isAdmin,
      userId: userId,
      userName: userName,
      orderProvider: orderProvider,
    );

    final roleLabel = isDriver
        ? 'Driver'
        : isAdmin
            ? 'Admin'
            : 'Customer';
    final sessionKey = '${roleLabel}_$userId';
    final history = _conversationHistory.putIfAbsent(sessionKey, () => []);

    final String systemInstructions =
        "You are AquaBot 💧, the omniscient, friendly AI support assistant for 'JJAASS Water Market' (JJAASSApp).\n"
        "Store Location: $marketAddress (serving Albay 1st District: Tabaco City, Bacacay, Malilipot, Malinao, Santo Domingo, Tiwi).\n"
        "Operating Hours: Monday to Sunday, 7:00 AM – 7:00 PM.\n"
        "Available Jug Types: 5-Gallon Slim (with faucet & handle) and 5-Gallon Round (for water dispensers).\n"
        "Available Payment Methods: Cash on Delivery (COD) and GCash Mobile Payment (via PayMongo).\n"
        "You are currently assisting '$userName' (Current Role: $roleLabel).\n"
        "You know EVERYTHING about all three roles (Admin, Driver, and Customer), their screens, features, and live system data.\n\n"
        "LIVE APPLICATION DATA & ROLE MANUALS:\n"
        "$contextData\n\n"
        "GUIDELINES:\n"
        "- Answer any question about Admin, Driver, or Customer features accurately, conversationally, and concisely using the live data and role manuals above.\n"
        "- Format currency in Philippine Pesos (₱).\n"
        "- Use clean Markdown formatting (bullet points and bold text for key details).\n"
        "- Never invent fake order IDs that are not in the live data.";

    final List<Map<String, dynamic>> contents = [
      ...history.skip(max(0, history.length - 6)),
      {
        "role": "user",
        "parts": [
          {"text": query}
        ],
      },
    ];

    Exception? lastError;

    for (final model in _geminiModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$activeApiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                "system_instruction": {
                  "parts": [
                    {"text": systemInstructions}
                  ]
                },
                "contents": contents,
                "generationConfig": {
                  "temperature": 0.35,
                  "maxOutputTokens": 700,
                },
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text =
              data['candidates']?[0]?['content']?[0]?['text'] ??
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
              '';
          final reply = text.toString().trim();
          if (reply.isNotEmpty) {
            history.add({
              "role": "user",
              "parts": [
                {"text": query}
              ],
            });
            history.add({
              "role": "model",
              "parts": [
                {"text": reply}
              ],
            });
            return reply;
          }
        } else {
          lastError = Exception(
            'Model $model returned status ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        lastError = Exception('Model $model error: $e');
      }
    }

    throw lastError ?? Exception('All Gemini models failed.');
  }

  /// Omniscient cross-role conversational engine referencing live OrderProvider, DeliveryIssueService, and CompliancePermitService data
  static String _getLocalFallbackResponse({
    required String query,
    required String rawQuery,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) {
    final issueService = DeliveryIssueService.instance;
    final permitService = CompliancePermitService.instance;

    // 0. Specific Order ID Lookup (e.g. ORD-008447, #ORD-003796)
    final ordMatch = RegExp(r'ord[-_]?\d+', caseSensitive: false).firstMatch(rawQuery);
    if (ordMatch != null) {
      final token = ordMatch.group(0)!.toUpperCase().replaceAll('_', '-');
      final matched = orderProvider.orders.where(
        (o) => o.id.toUpperCase().contains(token),
      );
      if (matched.isNotEmpty) {
        final o = matched.first;
        final claim = issueService.getIssueByOrderId(o.id);
        return "📦 **Live Order Details (${o.id})**\n\n"
            "- **Customer**: ${o.customerName} (${o.customerPhone})\n"
            "- **Items**: ${o.itemsSummary}\n"
            "- **Total Amount**: **${o.formattedTotal}**\n"
            "- **Status**: **${o.orderStatus.displayName}**\n"
            "- **Assigned Driver**: ${o.driverName ?? 'Unassigned'}\n"
            "- **Payment**: ${o.paymentMethod} (${o.paymentStatus})\n"
            "- **Delivery Address**: ${o.deliveryAddress}\n"
            "${claim != null ? '- **Defect Claim (${claim.id})**: ${claim.status.toUpperCase()} (${claim.affectedGallons} gallon(s) • ${claim.issueType})' : '- **Defect Claim**: None reported'}";
      }
    }

    // 1. Greetings & Role-Aware Welcome
    if (RegExp(
      r'^(hi|hello|hey|good morning|good afternoon|good evening|kumusta|kamusta)\b',
    ).hasMatch(query)) {
      if (isAdmin) {
        return "Hello Admin **$userName**! 👋 I'm **AquaBot 💧**, your omniscient JJAASS Water Market assistant.\n\n"
            "📊 **Live Station Snapshot**:\n"
            "- **Total Revenue**: ₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}\n"
            "- **Orders**: ${orderProvider.getPendingCount()} Pending • ${orderProvider.getActiveDeliveriesCount()} Active • ${orderProvider.getCompletedCount()} Completed\n"
            "- **Bulk Reservoir**: ${orderProvider.waterReservoirLiters.toInt()}L / ${orderProvider.waterReservoirCapacity.toInt()}L (${orderProvider.availableRefillsCount} refills available)\n"
            "- **Active Defect Claims**: ${issueService.activeCount} (${issueService.pendingCount} pending review)\n\n"
            "Ask me anything about **Admin**, **Driver**, or **Customer** workflows!";
      }
      if (isDriver) {
        final activeJob = orderProvider.getActiveDriverJob(
          userId,
          driverName: userName,
        );
        final available = orderProvider.getAvailableDriverJobs(
          userId,
          driverName: userName,
        );
        return "Hello Driver **$userName**! 🚚 I'm **AquaBot 💧**, your dispatch & operations assistant.\n\n"
            "- **Active Delivery**: ${activeJob != null ? '${activeJob.id} (${activeJob.customerName} • ${activeJob.formattedTotal})' : 'None right now'}\n"
            "- **Available Jobs in Queue**: ${available.length}\n\n"
            "Ask me about **dispatch & GPS navigation**, **borrowed gallon returns**, **COD/GCash verification**, **defect swaps**, or how **Admin & Customer** features work!";
      }
      final swapCredits = issueService.getCustomerApprovedSwapGallons(
        userId,
        userName,
      );
      return "Hello **$userName**! 👋 Welcome to **JJAASS Water Market** 💧\n\n"
          "I know everything across our **Customer, Driver, and Station Admin** systems! I can help you with:\n"
          "- 💧 **Water Products & Prices** (Refill ₱30 vs Set A ₱230, Slim & Round Jugs)\n"
          "- 📦 **Live Order Tracking & Pinned GPS Delivery**\n"
          "- 📸 **Reporting Delivery Defects** (with Camera/Gallery photo evidence)${swapCredits > 0 ? '\n- ✅ **You have $swapCredits Approved Free Swap Gallon(s) ready to redeem!**' : ''}\n"
          "- 🛡️ **Station Safety & Compliance Permits**\n"
          "- 💳 **GCash (PayMongo) & Cash on Delivery (COD)**\n\n"
          "What would you like to ask?";
    }

    // 2. Gratitude / Closing
    if (query.contains('thank') ||
        query.contains('salamat') ||
        query.contains('thanks')) {
      return "You're very welcome, **$userName**! 💧 Thank you for using **JJAASS Water Market**. Ask me anytime if you need help with Customer, Driver, or Admin operations!";
    }

    // 3. Gemini API setup instructions
    if (query.contains('gemini') ||
        query.contains('api key') ||
        query.contains('apikey')) {
      return "🔑 **How to Enable Live Google Gemini AI**\n\n"
          "1. Get an API key from Google AI Studio: https://aistudio.google.com/app/apikey\n"
          "2. Paste your `AIza...` key directly here in the chat, or set `geminiApiKey` in `app_constants.dart`.\n\n"
          "Current status: **${hasConfiguredApiKey ? 'Connected to Gemini 2.5 Flash ✅' : 'Omniscient Built-in Mode (All Admin, Driver & Customer data active ✅)'}**";
    }

    // 4. Cross-Role Overview ("all roles", "what can admin/driver/customer do", "roles")
    if (query.contains('all role') ||
        query.contains('each role') ||
        query.contains('every role') ||
        query.contains('three role') ||
        (query.contains('what can') &&
            (query.contains('admin') ||
                query.contains('driver') ||
                query.contains('customer')))) {
      return "👥 **Complete JJAASS Water Market Role Guide**\n\n"
          "1. **Station Admin (Web Admin Panel)**:\n"
          "   - **Dashboard & Orders**: Monitor live orders, assign drivers, and update statuses.\n"
          "   - **Defect & Swap Claims**: Inspect customer photo evidence, approve/decline swap claims, and click **Complete Transaction & Dismiss** (or let completed orders auto-dismiss).\n"
          "   - **Inventory & 10,000L Reservoir**: Manage water stock, Slim/Round containers, and track **Customer Borrowed Gallons**.\n"
          "   - **Deliveries, Payments & Reports**: Track live driver GPS fleet, verify GCash/COD payments, and export **CSV / PDF** reports.\n"
          "   - **Settings & Compliance Permits**: Upload/replace Mayor's Permit, DOH Sanitary Permit, Lab Tests, DTI, and FSIC directly from a laptop.\n\n"
          "2. **Delivery Driver (Mobile App)**:\n"
          "   - **Job Invitations**: Accept single jobs or tap **Accept All** to accept all pending dispatches with real-time order prices.\n"
          "   - **Live GPS Navigation**: View customer pinned coordinates, optimize multi-stop routes, and progress status (`Assigned` → `Out for Delivery` → `Delivered`).\n"
          "   - **Gallon Returns & Payments**: Log returned Slim/Round borrowed gallons, verify GCash/COD, and message Customer or **Station Admin Desk**.\n\n"
          "3. **Customer (Mobile App)**:\n"
          "   - **Order Water**: Order Refills (₱30) or Set A w/ New Jug (₱230), choose 5-Gallon Slim or Round, pin house GPS, and pay via **GCash (PayMongo)** or **COD**.\n"
          "   - **Track & Chat**: Track the rider on the live map and chat with the Driver or Station Admin.\n"
          "   - **Defect Claims & Permits**: Submit defect claims with **Camera/Gallery photo evidence**, redeem approved free swaps, and view official **Station Safety Permits**.";
    }

    // 5. Delivery Defect & Swap Claims (Admin, Driver, and Customer)
    if (query.contains('defect') ||
        query.contains('claim') ||
        query.contains('swap') ||
        query.contains('damaged') ||
        query.contains('broken seal') ||
        query.contains('leak') ||
        query.contains('murky') ||
        query.contains('evidence') ||
        query.contains('replace')) {
      final activeClaims = issueService.activeCount;
      final pendingClaims = issueService.pendingCount;
      final approvedClaims = issueService.activeIssues.where((i) => i.isApproved).length;
      final custSwapCredits = issueService.getCustomerApprovedSwapGallons(
        userId,
        userName,
      );

      return "🔄 **Delivery Defect & Gallon Swap Claims (Real-Time)**\n\n"
          "📊 **Live Claims Status**:\n"
          "- **Active Unresolved Claims**: **$activeClaims** ($pendingClaims Pending Review • $approvedClaims Swap Approved)\n"
          "${!isAdmin && !isDriver ? '- **Your Approved Free Swap Credits**: **$custSwapCredits gallon(s)**\n' : ''}\n"
          "📸 **How It Works Across Roles**:\n"
          "- **For Customers**: On any **Completed** order, tap **Report Issue / Request Swap**, select the defect type (*Seal Damaged, Container Leak, Murky Water, Broken Cap*), take a photo using **Take Photo (Camera)** or **From Gallery** (required evidence), and submit.\n"
          "- **For Admins**: Go to **Orders → Delivery Defect & Swap Claims**. Inspect the customer's uploaded photo, then click **Approve Swap** or **Decline**. Once the replacement transaction is done, it automatically moves to **Done & History** (or click **Complete Transaction & Dismiss**).\n"
          "- **For Drivers & Next Delivery**: When a customer toggles **Redeem Free Replacement Swap** on their next order, the replacement gallon(s) are priced at **₱0** and tagged on the driver's delivery note for free container swap.";
    }

    // 6. Station Compliance & Safety Permits (Admin & Customer)
    if (query.contains('permit') ||
        query.contains('sanitary') ||
        query.contains('doh') ||
        query.contains('potability') ||
        query.contains('lab test') ||
        query.contains('mayor') ||
        query.contains('dti') ||
        query.contains('fsic') ||
        query.contains('fire safety') ||
        query.contains('certificate') ||
        query.contains('compliance')) {
      final permits = permitService.permits;
      final permitLines = permits
          .map(
            (p) =>
                "- **${p.title}**: ${p.isUploaded ? '✅ ${p.status}' : '⚠️ Not Uploaded'} *(Expires: ${p.expiryDate})*",
          )
          .join('\n');
      return "🛡️ **Station Safety & Regulatory Compliance Permits**\n\n"
          "$permitLines\n\n"
          "- **How Customers View Permits**: On the Customer Dashboard, scroll to **Verified Station Compliance & Permits** and tap any document to inspect the high-resolution certificate.\n"
          "- **How Admins Replace Permits (Laptop/Desktop)**: Go to **Settings → Station Compliance & Regulatory Permits**, click **Replace / Upload**, drag-and-drop or browse an image (`.png`, `.jpg`, `.webp`) from your laptop, set the expiry date, and save.";
    }

    // 7. 10,000L Bulk Water Reservoir & Depletion
    if (query.contains('reservoir') ||
        query.contains('10,000') ||
        query.contains('10000') ||
        query.contains('deplete') ||
        query.contains('bulk water') ||
        query.contains('tank')) {
      final currentLiters = orderProvider.waterReservoirLiters.toInt();
      final maxLiters = orderProvider.waterReservoirCapacity.toInt();
      final availableRefills = orderProvider.availableRefillsCount;
      return "💧 **10,000L Bulk Water Reservoir & Refill Depletion**\n\n"
          "- **Current Reservoir Level**: **$currentLiters L / $maxLiters L**\n"
          "- **Available 5-Gallon Refills**: **$availableRefills jugs** *(19 Liters per 5-gallon jug)*\n\n"
          "**How Depletion Works**:\n"
          "1. Every time a 5-gallon (19L) water refill order is placed, **19 Liters** are automatically deducted from the **10,000L Bulk Water Reservoir**.\n"
          "2. If an order is cancelled, the 19L per jug is refunded back to the reservoir.\n"
          "3. **How Admin Refills the Tank**: Open **Inventory → Bulk Water Reservoir** card and click **Refill Tank** to replenish the water volume back up to 10,000L.";
    }

    // 8. Borrowed Gallons, Returns, Collection & Partial Returns (Admin, Driver, Customer)
    if (query.contains('borrow') ||
        query.contains('unreturned') ||
        query.contains('return gallon') ||
        query.contains('returned slim') ||
        query.contains('collected borrowed') ||
        query.contains('3 out of 5') ||
        query.contains('partial return') ||
        query.contains('empty container')) {
      final totalActive = orderProvider.totalActiveBorrowedGallons;
      final activeSlim = orderProvider.activeSlimBorrowedGallons;
      final activeRound = orderProvider.activeRoundBorrowedGallons;
      return "🔄 **Borrowed Gallons Tracking, Collection & Auto-Restock**\n\n"
          "📊 **Live Borrowed Containers**:\n"
          "- **Total Active Borrowed**: **$totalActive gallons** (*$activeSlim Slim* • *$activeRound Round*)\n"
          "- **Station Empty Reserves**: ${orderProvider.emptyContainerStocks} jugs\n\n"
          "📋 **How It Works Across All Roles**:\n"
          "- **For Customers**: When ordering a ₱30 refill without your own jug, you can borrow station **5-Gallon Slim** or **Round** containers. They are logged under your account until returned.\n"
          "- **For Drivers (Logging Returns & Partial Returns)**: In the Driver App, tap **Log Return / Collect Gallons** on the customer's record. If a customer only returns **3 out of 5 borrowed gallons**, enter `3`—the system automatically deducts 3 and keeps the remaining **2 gallons** marked as **Active Borrowed**.\n"
          "- **Auto-Restocking**: Returned Slim and Round containers are automatically added back to the station's physical container inventory (`+${orderProvider.remainingSlimGallons.toInt()} Slim / ${orderProvider.remainingRoundGallons.toInt()} Round` available).\n"
          "- **For Admins**: Go to **Inventory → Customer Borrowed Gallons Log** to filter by *Active, Returned, Slim, or Round*, mark gallons as returned, or click **Schedule Collection** to dispatch a driver.";
    }

    // 9. Restocking Physical Slim & Round Container Inventory
    if (query.contains('restock') ||
        query.contains('inventory') ||
        query.contains('stock') ||
        query.contains('capacity') ||
        query.contains('vehicle gallon')) {
      final productsInfo = orderProvider.waterProducts.map((p) {
        return "- **${p['name']}**: ${(p['stock'] as num).toInt()} / ${(p['capacity'] as num).toInt()} units (**₱${(p['price'] as num).toStringAsFixed(2)}**)";
      }).join('\n');
      return "📦 **Live Inventory & Physical Container Stock Levels**\n\n"
          "$productsInfo\n"
          "- **Available Slim Containers**: **${orderProvider.remainingSlimGallons.toInt()} / ${orderProvider.slimGallonCapacity.toInt()}**\n"
          "- **Available Round Containers**: **${orderProvider.remainingRoundGallons.toInt()} / ${orderProvider.roundGallonCapacity.toInt()}**\n"
          "- **Refilled Reserves**: ${orderProvider.refilledContainerStocks} • **Empty Reserves**: ${orderProvider.emptyContainerStocks}\n\n"
          "**How to Manage Inventory**:\n"
          "- **Admin Restocking**: Open the **Inventory** tab, click **Restock** or **Set Stock** on any item (or **Set All Inventory** in the top bar) to update quantities, capacities, or prices in real time.\n"
          "- **Driver Vehicle Capacity**: Standard delivery tricycles/vans load up to **20–30 5-gallon jugs** per trip. Drivers can check assigned job quantities on the **Driver Dispatch Dashboard** before departing.";
    }

    // 10. Driver Dispatch, Assigning Orders, GPS Navigation, & Customer Not Home
    if (query.contains('assign') ||
        query.contains('out for delivery') ||
        query.contains('pinned gps') ||
        query.contains('permanent gps') ||
        query.contains('not at the delivery') ||
        query.contains('not home') ||
        query.contains('accept all') ||
        query.contains('switch between available') ||
        query.contains('driver status')) {
      final activeJob = orderProvider.getActiveDriverJob(
        userId,
        driverName: userName,
      );
      final availableJobs = orderProvider.getAvailableDriverJobs(
        userId,
        driverName: userName,
      );
      return "🚚 **Dispatch, Live GPS Navigation & Delivery Guide**\n\n"
          "📊 **Live Dispatch Queue**:\n"
          "- **Pending Unassigned Orders**: ${orderProvider.getPendingCount()}\n"
          "- **Active Deliveries in Transit**: ${orderProvider.getActiveDeliveriesCount()}\n"
          "${isDriver ? '- **Your Active Job**: ${activeJob?.id ?? "None"} • **Your Queue**: ${availableJobs.length} job(s)\n' : ''}\n"
          "🧭 **Step-by-Step Workflows**:\n"
          "- **Admin — Assigning a Driver**: Go to **Orders** or **Deliveries Fleet**, click **Assign Driver** on a pending order, and pick an available rider.\n"
          "- **Driver — Accepting Jobs & Marking Out for Delivery**: On the **Driver Dashboard**, tap **Accept Job** on an individual card or tap **Accept All** to accept all job invitations at once. Tap **Start Delivery / Out for Delivery** when departing.\n"
          "- **Driver — Navigating with Pinned GPS**: Tap the **Live Map / Navigate** button on the active order card to follow the route to the customer's exact pinned GPS coordinates.\n"
          "- **Customer — Permanent GPS Pin**: When ordering in **Order Water**, tap the map pin to lock your exact house coordinates so drivers always have turn-by-turn directions to your doorstep.\n"
          "- **What if the Customer is Not at the Delivery Address?**: Open the order's **Delivery Chat** or call the customer's phone number listed on the job card, and use the **Message Admin (Station Admin Desk)** quick action to coordinate rescheduling.\n"
          "- **Switching Driver Status**: Your status automatically switches to **On Delivery** when you have an active in-transit order and returns to **Available** once all active deliveries are marked **Delivered**.";
    }

    // 11. Refill (₱30) vs Set A (₱230), Slim vs Round, Max Quantity, & Product Prices
    if (query.contains('set a') ||
        query.contains('230') ||
        query.contains('difference between refill') ||
        query.contains('slim or 5-gallon round') ||
        query.contains('slim or round') ||
        query.contains('slim') ||
        query.contains('round') ||
        query.contains('jug') ||
        query.contains('maximum quantity') ||
        query.contains('max quantity') ||
        query.contains('price') ||
        query.contains('magkano') ||
        query.contains('how much') ||
        query.contains('product')) {
      final list = orderProvider.inventoryItems.map((p) {
        return "- **${p['name']}**: **₱${(p['price'] as num).toStringAsFixed(2)}** *(Stock: ${(p['stock'] as num).toInt()})*";
      }).join('\n');
      return "💧 **Products, Pricing, Jug Types & Order Limits**\n\n"
          "**Live Catalog & Prices**:\n$list\n\n"
          "🏺 **Key Comparisons**:\n"
          "- **Water Refill (₱30) vs. Set A (₱230)**:\n"
          "  - **Purified Water Refill (₱30)**: Refills an existing 5-gallon (19L) container (either your own jug or a borrowed station jug).\n"
          "  - **Set A — Brand-New Container + Water (₱230)**: Includes **1 brand-new 5-Gallon container (₱200)** + **19L Purified Water Refill (₱30)** that you own permanently.\n"
          "- **5-Gallon Slim vs. 5-Gallon Round**:\n"
          "  - **5-Gallon Slim**: Rectangular container with a **built-in bottom faucet** and top carry handle—ideal for tabletops and kitchens without a dispenser.\n"
          "  - **5-Gallon Round**: Standard cylindrical bottle without a side faucet—designed specifically to sit upside-down on **hot & cold water dispensers**.\n"
          "- **Maximum Quantity per Order**: Customers can order up to **50 jugs per single order** (subject to live reservoir & container stock).";
    }

    // 12. Revenue, Sales, Liters Dispensed, GCash vs COD, & Reports (CSV/PDF)
    if (query.contains('revenue') ||
        query.contains('sales') ||
        query.contains('liters') ||
        query.contains('dispensed') ||
        query.contains('gcash') ||
        query.contains('paymongo') ||
        query.contains('cod') ||
        query.contains('cash on delivery') ||
        query.contains('payment') ||
        query.contains('report') ||
        query.contains('csv') ||
        query.contains('pdf')) {
      final completedOrders = orderProvider.orders
          .where((o) => o.orderStatus == OrderStatus.completed)
          .toList();
      final totalRev = orderProvider.getTotalRevenue();
      final gcashRev = completedOrders
          .where((o) => o.paymentMethod.toLowerCase().contains('gcash'))
          .fold<double>(0.0, (s, o) => s + o.totalAmount);
      final codRev = completedOrders
          .where((o) => !o.paymentMethod.toLowerCase().contains('gcash'))
          .fold<double>(0.0, (s, o) => s + o.totalAmount);
      final totalGallons = completedOrders.fold<int>(
        0,
        (s, o) => s + (o.quantity > 0 ? o.quantity : 1),
      );
      final totalLiters = totalGallons * 19;

      return "💰 **Payments, Revenue Analytics & Water Volume Dispensed**\n\n"
          "📊 **Live Financial & Volume Metrics**:\n"
          "- **Total Completed Revenue**: **₱${totalRev.toStringAsFixed(2)}** (${completedOrders.length} completed orders)\n"
          "- **GCash (PayMongo) Revenue**: **₱${gcashRev.toStringAsFixed(2)}**\n"
          "- **Cash on Delivery (COD) Revenue**: **₱${codRev.toStringAsFixed(2)}**\n"
          "- **Total Water Dispensed**: **$totalLiters Liters** ($totalGallons × 19L 5-gallon jugs)\n\n"
          "💳 **Payment & Verification Guidelines**:\n"
          "- **Customer — Paying via GCash (PayMongo)**: Select **GCash** at checkout to complete instant digital payment, or pay via **Cash on Delivery (COD)** when the driver arrives.\n"
          "- **Driver — Verifying COD vs. GCash**: Check the order badge on your Driver Dashboard—online GCash orders show **Paid (GCash)**, while **COD (Pending)** orders require collecting exact cash upon delivery and tapping **Mark as Delivered & Paid**.\n"
          "- **Admin — Reports & Exports**: Open **Payments** to filter by *GCash, COD, Paid, or Pending*, or open **Reports** to filter by *Daily, Weekly, Monthly, or Annually* and click **Export CSV** or **Download PDF**.";
    }

    // 13. Accounts, Roles, Security Lockout & Password Reset
    if (query.contains('account') ||
        query.contains('create user') ||
        query.contains('manage driver') ||
        query.contains('lockout') ||
        query.contains('5-attempt') ||
        query.contains('password') ||
        query.contains('security') ||
        query.contains('permission')) {
      return "🔐 **User Accounts, Role Permissions & Security Protection**\n\n"
          "- **Creating & Managing Accounts (Admin)**: Go to **User / Roles & Permissions** in the Admin Panel. Click **+ Create User** to register a new **Customer, Driver, or Admin**, or use the role dropdown on any user row to update their role or delete inactive accounts.\n"
          "- **5-Attempt Security Lockout**: To prevent brute-force attacks, after **5 consecutive failed login attempts**, the account is temporarily locked for security cooldown.\n"
          "- **OTP Password Reset**: Users can tap **Forgot Password?** on the login screen to receive a One-Time Password (OTP) via their registered email/phone to securely set a new bcrypt-hashed password.\n"
          "- **Audit-Locked Chats**: Once an order reaches **Completed**, its delivery chat channel automatically locks into **Read-Only** mode for tamper-proof audit retention.";
    }

    // 14. Store Location, Hours, & Customer Service Hotlines
    if (query.contains('address') ||
        query.contains('location') ||
        query.contains('located') ||
        query.contains('where is jjaass') ||
        query.contains('where are you') ||
        query.contains('store') ||
        query.contains('hours') ||
        query.contains('open') ||
        query.contains('hotline') ||
        query.contains('contact') ||
        query.contains('phone')) {
      return "📍 **JJAASS Water Market Location, Hours & Hotlines**\n\n"
          "- **Station Address**: **$marketAddress**\n"
          "- **Service Coverage**: Albay 1st District (*Bacacay, Tabaco City, Malilipot, Malinao, Santo Domingo, Tiwi*)\n"
          "- **Operating Hours**: Monday – Sunday, **7:00 AM to 7:00 PM**\n"
          "- **Station Hotline / Admin Desk**: **+63 995 113 3652** (`admin@jjaasswater.com`)\n"
          "- **In-App Direct Support**: Customers and Drivers can also message the dispatcher directly anytime using the **Message Station Admin** tab!";
    }

    // 15. Order Status & Tracking ("where is my order", "orders", "how to order")
    if (query.contains('how to order') ||
        query.contains('place order') ||
        query.contains('buy water')) {
      return "🛒 **How to Order Water in JJAASSApp**\n\n"
          "1. Open the **Order Water** tab.\n"
          "2. Choose **Purified Water Refill (₱30)** or **Set A w/ Brand-New Jug (₱230)** (or add standalone containers/caps).\n"
          "3. Select your container type (**5-Gallon Slim** or **5-Gallon Round**) and quantity.\n"
          "4. If you have an **Approved Defect Swap**, toggle the green **Redeem Free Replacement Swap** switch.\n"
          "5. Confirm your **Delivery Address & Pinned GPS Location**, choose **Cash on Delivery (COD)** or **GCash**, and tap **Confirm Order**!";
    }

    if (query.contains('where') ||
        query.contains('track') ||
        query.contains('status') ||
        query.contains('order') ||
        query.contains('delivery') ||
        query.contains('active') ||
        query.contains('job')) {
      if (isAdmin) {
        final recent = orderProvider.orders.take(3).map((o) {
          return "- **${o.id}** (${o.customerName}): ${o.itemsSummary} • **${o.formattedTotal}** • *${o.orderStatus.displayName}*";
        }).join('\n');
        return "📊 **Live System Orders Overview**\n\n"
            "- **Pending Orders**: ${orderProvider.getPendingCount()}\n"
            "- **Active Deliveries**: ${orderProvider.getActiveDeliveriesCount()}\n"
            "- **Completed Orders**: ${orderProvider.getCompletedCount()}\n"
            "- **Total Orders**: ${orderProvider.orders.length}\n\n"
            "**Latest Orders**:\n$recent";
      }
      if (isDriver) {
        final activeJob = orderProvider.getActiveDriverJob(
          userId,
          driverName: userName,
        );
        final available = orderProvider.getAvailableDriverJobs(
          userId,
          driverName: userName,
        );
        if (activeJob == null) {
          return "🚚 **Driver Dispatch Status**\n\n"
              "- **Active Delivery**: None right now\n"
              "- **Available Jobs in Queue**: **${available.length}**\n\n"
              "Go to the **Driver Dashboard** and tap **Accept Job** or **Accept All** to start delivering!";
        }
        return "🚚 **Your Current Active Delivery (${activeJob.id})**\n\n"
            "- **Customer**: ${activeJob.customerName} (${activeJob.customerPhone})\n"
            "- **Address**: ${activeJob.deliveryAddress}\n"
            "- **Items**: ${activeJob.itemsSummary}\n"
            "- **Total**: **${activeJob.formattedTotal}** (${activeJob.paymentMethod} • ${activeJob.paymentStatus})\n"
            "${activeJob.deliveryNote != null && activeJob.deliveryNote!.isNotEmpty ? '- **Note**: ${activeJob.deliveryNote}\n' : ''}";
      }
      final custOrders = orderProvider.getCustomerOrders(userId);
      if (custOrders.isEmpty) {
        return "📦 You don't have any orders yet! Open the **Order Water** tab to place your first water refill or container order.";
      }
      final latest = custOrders.first;
      return "📦 **Your Latest Order (${latest.id})**\n\n"
          "- **Items**: ${latest.itemsSummary}\n"
          "- **Total**: **${latest.formattedTotal}**\n"
          "- **Status**: **${latest.orderStatus.displayName}**\n"
          "- **Driver**: ${latest.driverName ?? 'Assigning station driver soon'}\n"
          "- **Payment**: ${latest.paymentMethod} (${latest.paymentStatus})\n"
          "- **Delivery Address**: ${latest.deliveryAddress}";
    }

    // 16. Loyalty Rewards Points
    if (query.contains('point') ||
        query.contains('reward') ||
        query.contains('loyalty')) {
      final pts = orderProvider.getCustomerRewardPoints(userId);
      return "⭐ **AquaLoyalty Rewards**\n\n"
          "- **Current Points**: **$pts pts** (+10 points earned per completed 5-gallon jug).\n"
          "- Keep ordering refills to accumulate points toward loyalty perks!";
    }

    // 17. Smart Role-Aware Default Summary (with Cross-Role Prompt Suggestions)
    final roleTitle = isAdmin
        ? 'Admin'
        : isDriver
            ? 'Driver'
            : 'Customer';
    return "Hello $roleTitle **$userName**! 💧 I'm **AquaBot**, and I have complete live access to **Admin, Driver, and Customer** data.\n\n"
        "Here are topics you can ask me right now:\n"
        "- 📦 **Orders & Tracking**: *'Where is my order?'*, *'Show pending orders'*, or type any order ID like *'#ORD-008447'*\n"
        "- 💧 **Products, Reservoir & Stock**: *'Refill vs Set A'*, *'Slim vs Round jug'*, or *'How does the 10,000L reservoir deplete?'*\n"
        "- 🔄 **Borrowed Gallons & Defect Swaps**: *'How do I report a damaged gallon with photo evidence?'* or *'How many active borrowed gallons?'*\n"
        "- 🚚 **Driver Dispatch & GPS**: *'Optimize route'*, *'How do drivers accept all jobs?'*, or *'What if the customer is not home?'*\n"
        "- 🛡️ **Permits, Payments & Security**: *'Show station permits'*, *'GCash vs COD revenue'*, or *'What can Admin, Driver, and Customer do?'*";
  }

  /// Formats all live system details and complete role manuals into a prompt-friendly context string for Gemini
  static String _gatherSystemContext({
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) {
    final issueService = DeliveryIssueService.instance;
    final permitService = CompliancePermitService.instance;
    final buffer = StringBuffer();

    buffer.writeln("=== BUSINESS & STATION INFORMATION ===");
    buffer.writeln("Business Name: JJAASS Water Market");
    buffer.writeln("Address: $marketAddress");
    buffer.writeln(
      "Service Areas: Albay 1st District (Tabaco City, Bacacay, Malilipot, Malinao, Santo Domingo, Tiwi)",
    );
    buffer.writeln("Operating Hours: Monday to Sunday, 7:00 AM – 7:00 PM");
    buffer.writeln("Station Hotline: +63 995 113 3652 | Email: admin@jjaasswater.com");
    buffer.writeln(
      "Jug Types: 5-Gallon Slim (with built-in faucet & carry handle) and 5-Gallon Round (for hot/cold dispensers)",
    );
    buffer.writeln(
      "Pricing Key: Purified Refill = ₱30 (19L), Set A = ₱230 (Brand-new 5-gallon jug ₱200 + 19L water refill ₱30). Max 50 jugs/order.",
    );

    buffer.writeln("\n=== COMPLETE CROSS-ROLE WORKFLOW MANUAL ===");
    buffer.writeln(
      "1. ADMIN ROLE: Manages Dashboard KPIs, Orders Log, Delivery Defect & Swap Claims (inspects customer photo evidence, approves/declines swaps, clicks 'Complete Transaction & Dismiss' or lets completed orders auto-archive to 'Done & History'), Deliveries Fleet GPS map, User/Roles & Permissions (Admin, Driver, Customer), Inventory & 10,000L Bulk Water Reservoir (deducts 19L per 5-gallon refill) + Customer Borrowed Gallons Log, Payments (GCash/COD), Analytics & Reports (Export CSV & Download PDF), and Settings (Laptop drag-and-drop Compliance Permit upload/replacement).",
    );
    buffer.writeln(
      "2. DRIVER ROLE: Uses Driver Dispatch Dashboard to accept single jobs or 'Accept All' invitations with real-time order prices, navigates via Live GPS to customer pinned coordinates, optimizes multi-stop delivery sequences, updates order status (Assigned -> Out for Delivery -> Delivered), logs returned Slim/Round borrowed gallons (supports partial returns like 3 of 5), verifies GCash Paid vs COD collection, and messages Customer or Station Admin Desk.",
    );
    buffer.writeln(
      "3. CUSTOMER ROLE: Orders water refills or Set A containers in 'Order Water', pins exact house GPS location, pays via GCash (PayMongo) or Cash on Delivery (COD), tracks driver live on map, chats with Driver or Station Admin, reports Delivery Defect Claims on completed orders with required Camera/Gallery photo evidence, toggles 'Redeem Free Replacement Swap' on next order when approved, and views high-res Station Safety Permits.",
    );

    buffer.writeln("\n=== LIVE SYSTEM ANALYTICS & INVENTORY ===");
    buffer.writeln(
      "Total Completed Revenue: ₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}",
    );
    buffer.writeln(
      "Order Counts: ${orderProvider.getPendingCount()} Pending, ${orderProvider.getActiveDeliveriesCount()} Active Deliveries, ${orderProvider.getCompletedCount()} Completed (Total: ${orderProvider.orders.length})",
    );
    buffer.writeln(
      "Bulk Water Reservoir: ${orderProvider.waterReservoirLiters.toInt()}L / ${orderProvider.waterReservoirCapacity.toInt()}L (${orderProvider.availableRefillsCount} 5-gallon refills available)",
    );
    buffer.writeln(
      "Container Stocks: Slim ${orderProvider.remainingSlimGallons.toInt()}/${orderProvider.slimGallonCapacity.toInt()}, Round ${orderProvider.remainingRoundGallons.toInt()}/${orderProvider.roundGallonCapacity.toInt()}, Refilled Reserves: ${orderProvider.refilledContainerStocks}, Empty Reserves: ${orderProvider.emptyContainerStocks}",
    );
    buffer.writeln(
      "Active Borrowed Gallons by Customers: ${orderProvider.totalActiveBorrowedGallons} total (${orderProvider.activeSlimBorrowedGallons} Slim, ${orderProvider.activeRoundBorrowedGallons} Round)",
    );
    for (var p in orderProvider.inventoryItems) {
      buffer.writeln(
        "- Item: ${p['name']}, Price: ₱${p['price']}, Stock: ${p['stock']}/${p['capacity']}",
      );
    }

    buffer.writeln("\n=== LIVE DELIVERY DEFECT & SWAP CLAIMS ===");
    buffer.writeln(
      "Active Claims: ${issueService.activeCount} (Pending: ${issueService.pendingCount}, Approved: ${issueService.activeIssues.where((i) => i.isApproved).length}, Completed/Archived: ${issueService.completedIssues.length})",
    );
    for (var c in issueService.activeIssues.take(5)) {
      buffer.writeln(
        "- Claim ${c.id} (Order ${c.orderId}, Customer: ${c.customerName}): ${c.issueType}, ${c.affectedGallons} gallon(s), Status: ${c.status}",
      );
    }

    buffer.writeln("\n=== LIVE STATION COMPLIANCE PERMITS ===");
    for (var permit in permitService.permits) {
      buffer.writeln(
        "- ${permit.title}: ${permit.status} (Expires: ${permit.expiryDate})",
      );
    }

    buffer.writeln("\n=== CURRENT USER SESSION CONTEXT ===");
    if (isAdmin) {
      buffer.writeln("Current User: Admin '$userName' (ID: $userId)");
    } else if (isDriver) {
      buffer.writeln("Current User: Driver '$userName' (ID: $userId)");
      final activeJob = orderProvider.getActiveDriverJob(
        userId,
        driverName: userName,
      );
      if (activeJob != null) {
        buffer.writeln(
          "Driver Active Job: ${activeJob.id}, Customer: ${activeJob.customerName}, Phone: ${activeJob.customerPhone}, Address: ${activeJob.deliveryAddress}, Items: ${activeJob.itemsSummary}, Total: ${activeJob.formattedTotal} (${activeJob.paymentMethod} • ${activeJob.paymentStatus})",
        );
      } else {
        buffer.writeln("Driver Active Job: None");
      }
      final available = orderProvider.getAvailableDriverJobs(
        userId,
        driverName: userName,
      );
      buffer.writeln("Driver Available Queue Count: ${available.length}");
      for (var job in available.take(5)) {
        buffer.writeln(
          "- Queue Job ${job.id}: Customer ${job.customerName}, Address: ${job.deliveryAddress}, Items: ${job.itemsSummary}, Total: ${job.formattedTotal}",
        );
      }
    } else {
      buffer.writeln("Current User: Customer '$userName' (ID: $userId)");
      buffer.writeln(
        "Customer Loyalty Points: ${orderProvider.getCustomerRewardPoints(userId)}",
      );
      buffer.writeln(
        "Customer Approved Free Swap Credits: ${issueService.getCustomerApprovedSwapGallons(userId, userName)} gallon(s)",
      );
      final customerOrders = orderProvider.getCustomerOrders(userId);
      buffer.writeln("Customer Order Count: ${customerOrders.length}");
      for (var o in customerOrders.take(5)) {
        buffer.writeln(
          "- Order ${o.id}: ${o.itemsSummary}, Total: ${o.formattedTotal}, Status: ${o.orderStatus.displayName}, Driver: ${o.driverName ?? 'Unassigned'}, Payment: ${o.paymentMethod} (${o.paymentStatus}), Address: ${o.deliveryAddress}",
        );
      }
    }

    return buffer.toString();
  }

  /// Resolves coordinates deterministically matching GoogleMapWidget formula
  static Map<String, double> _getCoordinatesForAddress(
    String address,
    double? latitude,
    double? longitude,
  ) {
    if (latitude != null && longitude != null) {
      return {'lat': latitude, 'lng': longitude};
    }
    final hash = address.hashCode;
    final latOffset = (hash % 100) / 1000.0 - 0.05;
    final lngOffset = ((hash >> 4) % 100) / 1000.0 - 0.05;
    return {
      'lat': _depotLat + latOffset,
      'lng': _depotLng + lngOffset,
    };
  }

  /// Nearest Neighbor TSP Algorithm to optimize route path
  static String _optimizeRouteResponse(
    String driverId,
    OrderProvider orderProvider,
  ) {
    final List<OrderModel> jobs = orderProvider.orders.where((o) {
      return (o.driverId == driverId || driverId.isEmpty) &&
          (o.orderStatus == OrderStatus.onDelivery ||
              o.orderStatus == OrderStatus.assigned);
    }).toList();

    if (jobs.isEmpty) {
      return "⚠️ **Route Optimization Notice**\n\nThere are currently no assigned or active delivery jobs to optimize. Accept jobs from the dispatch queue first!";
    }

    final List<Map<String, dynamic>> stops = [];
    for (var job in jobs) {
      final coords = _getCoordinatesForAddress(
        job.deliveryAddress,
        job.latitude,
        job.longitude,
      );
      stops.add({
        'order': job,
        'lat': coords['lat']!,
        'lng': coords['lng']!,
        'visited': false,
      });
    }

    double currentLat = _depotLat;
    double currentLng = _depotLng;
    final List<Map<String, dynamic>> optimizedPath = [];
    double totalDistance = 0.0;

    double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
    ) {
      const double r = 6371.0;
      final double dLat = (lat2 - lat1) * pi / 180.0;
      final double dLon = (lon2 - lon1) * pi / 180.0;
      final double a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * pi / 180.0) *
              cos(lat2 * pi / 180.0) *
              sin(dLon / 2) *
              sin(dLon / 2);
      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return r * c;
    }

    while (optimizedPath.length < stops.length) {
      double minDistance = double.maxFinite;
      int nearestIndex = -1;

      for (int i = 0; i < stops.length; i++) {
        if (!stops[i]['visited']) {
          final dist = calculateDistance(
            currentLat,
            currentLng,
            stops[i]['lat'] as double,
            stops[i]['lng'] as double,
          );
          if (dist < minDistance) {
            minDistance = dist;
            nearestIndex = i;
          }
        }
      }

      if (nearestIndex != -1) {
        stops[nearestIndex]['visited'] = true;
        stops[nearestIndex]['distanceFromPrev'] = minDistance;
        optimizedPath.add(stops[nearestIndex]);

        currentLat = stops[nearestIndex]['lat'] as double;
        currentLng = stops[nearestIndex]['lng'] as double;
        totalDistance += minDistance;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln("📍 **AquaBot Optimal Delivery Route Dispatch** 📍");
    buffer.writeln(
      "Optimal sequence planned starting from **JJAASS Water Market ($marketAddress)**:\n",
    );
    buffer.writeln("🏠 **1. JJAASS Water Market Depot**");
    buffer.writeln("   - Start Coordinate: ($_depotLat, $_depotLng)");

    for (int i = 0; i < optimizedPath.length; i++) {
      final stop = optimizedPath[i];
      final OrderModel order = stop['order'] as OrderModel;
      final distPrev = stop['distanceFromPrev'] as double;
      final estTimeMins = (distPrev * 6).round() + 5;

      buffer.writeln(
        "\n➡️ **${i + 2}. Stop: Customer ${order.customerName}** (Order: ${order.id})",
      );
      buffer.writeln("   - **Address**: ${order.deliveryAddress}");
      buffer.writeln("   - **Quantity**: ${order.itemsSummary} (${order.formattedTotal})");
      buffer.writeln(
        "   - **Distance from previous point**: ${distPrev.toStringAsFixed(2)} km",
      );
      buffer.writeln("   - **Estimated travel time**: ~$estTimeMins mins");
    }

    final double unoptimizedDistance = jobs.fold(0.0, (sum, o) {
      final parsedDist =
          double.tryParse(o.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.5;
      return sum + parsedDist;
    });
    final double savings = max(0.2, unoptimizedDistance - totalDistance);

    buffer.writeln("\n📊 **Optimization Stats**");
    buffer.writeln("- **Total stops**: ${optimizedPath.length}");
    buffer.writeln(
      "- **Total optimized distance**: **${totalDistance.toStringAsFixed(2)} km**",
    );
    buffer.writeln(
      "- **Estimated route travel time**: **${(totalDistance * 6).round() + (optimizedPath.length * 5)} mins**",
    );
    buffer.writeln(
      "- **Optimization Benefit**: Saved approximately **${savings.toStringAsFixed(2)} km** of driving!",
    );

    return buffer.toString();
  }
}
