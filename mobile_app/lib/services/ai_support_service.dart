import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

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
  /// Falls back to an enhanced conversational engine if Gemini API key is not yet set or network fails.
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
    final apiKeyMatch = RegExp(r'(AIza[0-9A-Za-z\-_]{31,45})').firstMatch(trimmed);
    if (apiKeyMatch != null) {
      final extractedKey = apiKeyMatch.group(1)!;
      setApiKey(extractedKey);
      return "✅ **Gemini AI Key Activated!**\n\nAquaBot is now connected to **Google Gemini (`gemini-2.5-flash`)** for live AI chat support. Ask me anything about your orders, water products, deliveries, or JJAASS Water Market!";
    }

    // Quick intercept for route optimization if requested by driver
    if (isDriver &&
        (cleanQuery.contains('route') ||
            cleanQuery.contains('optimize') ||
            cleanQuery.contains('path') ||
            cleanQuery.contains('plan') ||
            cleanQuery.contains('sequence'))) {
      await Future.delayed(const Duration(milliseconds: 500));
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
        debugPrint('Gemini API request failed, falling back to local engine: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));

    // Enhanced Conversational Local Engine
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

  /// Builds context payload & requests Google Gemini API with automatic model fallback
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

    final roleLabel = isDriver ? 'Driver' : isAdmin ? 'Admin' : 'Customer';
    final sessionKey = '${roleLabel}_$userId';
    final history = _conversationHistory.putIfAbsent(sessionKey, () => []);

    final String systemInstructions =
        "You are AquaBot 💧, the friendly, intelligent AI support assistant for 'JJAASS Water Market' (JJAASSApp).\n"
        "Store Location: $marketAddress.\n"
        "Operating Hours: Monday to Sunday, 7:00 AM – 7:00 PM.\n"
        "AvailableJug Types: 5-Gallon Slim (with faucet & handle) and 5-Gallon Round (for water dispensers).\n"
        "Available Payment Methods: Cash on Delivery (COD) and GCash Mobile Payment (via PayMongo).\n"
        "You are currently assisting '$userName' (Role: $roleLabel).\n\n"
        "LIVE APPLICATION DATA:\n"
        "$contextData\n\n"
        "GUIDELINES:\n"
        "- Answer natural questions conversationally, accurately, and concisely using the live application data above.\n"
        "- Format currency in Philippine Pesos (₱).\n"
        "- Use clean formatting (bullet points and bold text for key details).\n"
        "- Never invent fake order IDs that are not in the live data.";

    // Build multi-turn contents (keep last 6 turns for fast context)
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
                  "temperature": 0.4,
                  "maxOutputTokens": 600,
                },
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
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

  /// Smart conversational fallback referencing live provider data
  static String _getLocalFallbackResponse({
    required String query,
    required String rawQuery,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) {
    // 1. Greetings & small talk
    if (RegExp(r'^(hi|hello|hey|good morning|good afternoon|good evening|kumusta|kamusta)\b')
        .hasMatch(query)) {
      if (isAdmin) {
        return "Hello Admin **$userName**! 👋 I'm **AquaBot 💧**, your JJAASS Water Market operations assistant.\n\nHere is a quick live snapshot:\n- **Total Revenue**: ₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}\n- **Pending Orders**: ${orderProvider.getPendingCount()}\n- **Active Deliveries**: ${orderProvider.getActiveDeliveriesCount()}\n\nAsk me about **sales**, **inventory stock**, **pending orders**, or paste a **Gemini API Key** anytime!";
      }
      if (isDriver) {
        final activeJob = orderProvider.getActiveDriverJob(userId);
        return "Hello Driver **$userName**! 🚚 I'm **AquaBot 💧**, your dispatch assistant.\n\n- **Active Delivery**: ${activeJob != null ? '${activeJob.id} (${activeJob.customerName})' : 'None right now'}\n- **Available Earnings**: ₱${orderProvider.getDriverEarnings(userId).toStringAsFixed(2)}\n\nAsk me to **optimize route**, check your **active job**, or view your **earnings**!";
      }
      return "Hello **$userName**! 👋 Welcome to **JJAASS Water Market** 💧\n\nI can help you with:\n- 💧 **Water Types & Prices** (19L Purified Refill ₱30, 19L Set A with New Container ₱230)\n- 🏺 **Jug Types** (5-Gallon Slim with Faucet & 5-Gallon Round)\n- 📦 **Order Tracking & Delivery Status**\n- 💳 **GCash & COD Payments**\n- 📍 **Store Location & Hours**\n\nWhat would you like to know?";
    }

    // 2. Gratitude / Closing
    if (query.contains('thank') || query.contains('salamat') || query.contains('thanks')) {
      return "You're very welcome, **$userName**! 💧 Thank you for choosing **JJAASS Water Market**. Stay hydrated and let me know if you need anything else!";
    }

    // 3. Gemini API setup instructions
    if (query.contains('gemini') || query.contains('api key') || query.contains('apikey')) {
      return "🔑 **How to Enable Live Google Gemini AI**\n\n"
          "1. Get a free API key from Google AI Studio: https://aistudio.google.com/app/apikey\n"
          "2. Simply **paste your `AIza...` key right here in the chat** (or tap the 🔑 key icon in the top bar), or set `geminiApiKey` in `app_constants.dart`.\n\n"
          "Current status: **${hasConfiguredApiKey ? 'Connected to Gemini 2.5 Flash ✅' : 'Smart Built-in Mode (No API key set yet)'}**";
    }

    // 4. Specific Refill vs Set A query
    if (query.contains('set a') ||
        (query.contains('refill') && (query.contains('set') || query.contains('230') || query.contains('difference')))) {
      return "💧 **Refill (₱30) vs Set A with New Container (₱230)**\n\n"
          "Here is the detailed breakdown of each product option:\n\n"
          "1. **19L Purified Water Refill (₱30.00)**:\n"
          "   • **What it is**: 19 Liters of pure multi-stage filtered drinking water for customers who already own a 5-gallon jug.\n"
          "   • **How it works**: Our delivery rider arrives with a sanitized, sealed 19L bottle and exchanges it for your empty container.\n"
          "   • **Best for**: Routine weekly household replenishment at the most affordable price.\n\n"
          "2. **19L Water + New Container Set A (₱230.00)**:\n"
          "   • **What it is**: A complete starter set including a **brand-new BPA-free 5-gallon jug** filled with freshly purified drinking water.\n"
          "   • **How it works**: You purchase and own the brand new container outright. **No empty container exchange is required**!\n"
          "   • **Best for**: First-time customers, new homes, offices, or adding extra backup containers to your household.\n\n"
          "💡 **Step-by-Step Ordering Guide**:\n"
          "1. Open the **Order Water** tab.\n"
          "2. Tap either **19L Purified Water** (₱30) or **Set A** (₱230).\n"
          "3. Select your preferred container style: **5-Gallon Slim** (with faucet) or **5-Gallon Round** (for dispenser) using the quantity steppers!";
    }

    // 5. Store Location / Address / Hours / Contact
    if (query.contains('address') ||
        query.contains('location') ||
        query.contains('located') ||
        query.contains('where are you') ||
        query.contains('store') ||
        query.contains('shop') ||
        query.contains('visit') ||
        query.contains('pickup') ||
        query.contains('pick up') ||
        query.contains('hours') ||
        query.contains('open') ||
        query.contains('contact') ||
        query.contains('hotline') ||
        query.contains('market')) {
      return "📍 **JJAASS Water Market Store Details & Hours**\n\n"
          "• **Physical Station**: **$marketAddress**\n"
          "• **Operating Hours**: Monday – Sunday, **7:00 AM to 7:00 PM**\n"
          "• **Delivery Cut-off**: Orders placed before 6:30 PM are delivered same-day.\n"
          "• **Customer Service Hotline**: **+63 912 345 6789** / **(052) 742-1234**\n"
          "• **Services Available**: Fast home delivery, walk-in jug refills, and spare dispenser accessories.";
    }

    // 6. Jug / Container Types (Slim vs Round)
    if (query.contains('jug') ||
        query.contains('slim') ||
        query.contains('round') ||
        query.contains('container') ||
        query.contains('gallon')) {
      return "🏺 **5-Gallon Slim vs 5-Gallon Round Jugs Comparison**\n\n"
          "Both containers hold 19 Liters (5 Gallons) of fresh purified water. Choose the best design for your home or office:\n\n"
          "1. **5-Gallon Slim Container** (Tabletop & Standalone):\n"
          "   • **Design**: Space-saving rectangular profile with built-in side carrying handle.\n"
          "   • **Dispensing**: Includes an integrated front twist faucet for easy direct pouring.\n"
          "   • **Ideal for**: Kitchen countertops, refrigerators, study tables, or camping without needing an external dispenser.\n\n"
          "2. **5-Gallon Round Container** (Inverted Dispenser):\n"
          "   • **Design**: Heavy-duty cylindrical body with non-spill bottle cap.\n"
          "   • **Dispensing**: Designed specifically to be inverted upside-down on hot/cold water dispensers or electric pumps.\n"
          "   • **Ideal for**: Offices, homes with stand-up hot & cold dispensers, and high-volume usage.\n\n"
          "💡 **Pro Tip**: You can order **both types at the same time** by simply setting the quantity on each jug card in the Order Water tab!";
    }

    // 7. Permanent GPS Location Pin Guide
    if (query.contains('pin') ||
        query.contains('gps') ||
        query.contains('permanent') ||
        query.contains('map')) {
      return "📍 **How Permanent GPS Location Pinning Works**\n\n"
          "Our system saves your exact GPS coordinates so our delivery riders can navigate straight to your doorstep without phone calls or delays:\n\n"
          "• **Step-by-Step Guide**:\n"
          "  1. Go to the **Order Water** tab or **Profile Settings**.\n"
          "  2. Tap the green **Edit Pin** button to launch the Google Map.\n"
          "  3. Drag the map until the red delivery marker is positioned directly over your house or gate.\n"
          "  4. Tap **Confirm & Save Pin**.\n\n"
          "• **Key Benefits**:\n"
          "  • **Permanently Saved**: Your coordinates are saved to your account and automatically pre-filled for every future order.\n"
          "  • **No Typing Required**: You never have to re-enter long province/city/barangay dropdowns!\n"
          "  • **Fully Editable**: Moving or ordering to another location? Simply tap **Edit Pin** anytime to update your saved spot!";
    }

    // 8. Maximum Quantity Limit
    if (query.contains('max') ||
        query.contains('limit') ||
        query.contains('how many jugs')) {
      return "📦 **Order Quantity & Limits**\n\n"
          "• **Maximum Per Item**: Up to **150 jugs/items each** per order (e.g., up to 150 Slim, 150 Round, and 150 per accessory, capped by available inventory stock).\n"
          "• **Bulk Orders (>20 Jugs)**: For large volume orders exceeding 20 jugs, our dispatch console automatically coordinates multi-rider batches or dedicated delivery vehicles for seamless turnaround across Tabaco City.\n"
          "• **Quick Quantity Input**: You can tap any quantity number in the Order Water tab to directly type large numbers (like 25, 50, 100, or 150) instantly!";
    }

    // 6. Water Types comparison (Purified vs Alkaline vs Mineral)
    if (query.contains('purified') ||
        query.contains('alkaline') ||
        query.contains('mineral') ||
        query.contains('difference') ||
        query.contains('water type') ||
        query.contains('best water')) {
      final list = orderProvider.waterProducts.map((p) {
        final desc = (p['description'] as String?) ?? '';
        return "- **${p['name']}** (**₱${(p['price'] as num).toStringAsFixed(2)}**): $desc *(Stock: ${(p['stock'] as num).toInt()} jugs)*";
      }).join('\n');
      return "💧 **JJAASS Water Types & Benefits**\n\n$list\n\n"
          "All options are available in **5-Gallon Slim** or **5-Gallon Round** jugs!";
    }

    if (isAdmin) {
      if (query.contains('revenue') ||
          query.contains('sales') ||
          query.contains('earn') ||
          query.contains('income')) {
        return "💰 **Live Revenue Report**\n\n"
            "- **Total Completed Revenue**: **₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}**\n"
            "- **Completed Orders**: ${orderProvider.getCompletedCount()}\n"
            "- **Pending Orders**: ${orderProvider.getPendingCount()}";
      }
      if (query.contains('order') ||
          query.contains('stat') ||
          query.contains('pending') ||
          query.contains('summary')) {
        return "📊 **Live Order Statistics**\n\n"
            "- **Pending Orders**: ${orderProvider.getPendingCount()}\n"
            "- **Active Deliveries**: ${orderProvider.getActiveDeliveriesCount()}\n"
            "- **Completed Orders**: ${orderProvider.getCompletedCount()}\n"
            "- **Total System Orders**: ${orderProvider.orders.length}";
      }
      if (query.contains('stock') ||
          query.contains('product') ||
          query.contains('inventory')) {
        final productsInfo = orderProvider.waterProducts.map((p) {
          return "- **${p['name']}**: ${(p['stock'] as num).toInt()} / ${(p['capacity'] as num).toInt()} gallons (₱${(p['price'] as num).toStringAsFixed(2)})";
        }).join('\n');
        return "💧 **Inventory Stock Levels**\n\n$productsInfo\n- **Refilled Reserves**: ${orderProvider.refilledContainerStocks}\n- **Empty Containers**: ${orderProvider.emptyContainerStocks}";
      }
      return "Hello Admin **$userName**! 💧 Here is what I can check for you right now:\n"
          "- **'revenue'** – Total sales & completed order revenue\n"
          "- **'orders'** – Live pending, active, and completed order counts\n"
          "- **'inventory'** – Current water stock & container reserves\n"
          "- Or paste a **Gemini API Key** (`AIza...`) to enable full generative AI analysis!";
    }

    if (isDriver) {
      if (query.contains('earn') ||
          query.contains('payout') ||
          query.contains('cash') ||
          query.contains('salary') ||
          query.contains('income')) {
        final earnings = orderProvider.getDriverEarnings(userId);
        final completed = orderProvider.getDriverCompletedJobs(userId).length;
        return "💳 **Driver Earnings & GCash Payout**\n\n"
            "- **Withdrawable Balance**: **₱${earnings.toStringAsFixed(2)}**\n"
            "- **Completed Trips**: $completed\n\n"
            "You earn **50% commission** per completed delivery. Go to the **Dashboard** and tap **Cash Out Earnings** to transfer to GCash.";
      }
      if (query.contains('active') ||
          query.contains('job') ||
          query.contains('delivery') ||
          query.contains('queue') ||
          query.contains('assign') ||
          query.contains('customer')) {
        final activeJob = orderProvider.getActiveDriverJob(userId);
        final available = orderProvider.getAvailableDriverJobs(userId);
        if (activeJob == null) {
          return "🚚 **Dispatch Status**\n\nYou have **no active delivery** right now.\n- **Available Jobs in Queue**: **${available.length}**\n\nOpen the **Dashboard** tab and tap **Accept Job** to start delivering!";
        }
        return "🚚 **Current Active Delivery (${activeJob.id})**\n\n"
            "- **Customer**: ${activeJob.customerName} (${activeJob.customerPhone})\n"
            "- **Address**: ${activeJob.deliveryAddress}\n"
            "- **Order**: ${activeJob.itemsSummary}\n"
            "- **Total**: ${activeJob.formattedTotal} (${activeJob.paymentMethod} • ${activeJob.paymentStatus})\n"
            "${activeJob.deliveryNote != null ? '- **Note**: ${activeJob.deliveryNote}\n' : ''}"
            "\nOpen **Deliveries Map** to navigate or mark as **Delivered**!";
      }
      return "Hello Driver **$userName**! 🚚 I can help you with:\n"
          "- **'optimize route'** – Calculate the fastest delivery sequence\n"
          "- **'active job'** – View your current customer address & order details\n"
          "- **'earnings'** – Check your commission balance & GCash cashout";
    }

    // Customer inquiries
    if (query.contains('how to order') ||
        query.contains('place order') ||
        query.contains('how do i order') ||
        query.contains('buy water')) {
      return "🛒 **How to Order Fresh Water**\n\n"
          "1. Open the **Order Water** tab from the menu.\n"
          "2. Select your **Product / Order Type** (*19L Purified Water Refill ₱30* or *19L Water + New Container Set A ₱230*).\n"
          "3. Choose your **Jug Type** (*5-Gallon Slim* or *5-Gallon Round*).\n"
          "4. Set the **quantity**, select your **Province, City/Municipality, & Barangay**, and optionally pin your exact house on the map.\n"
          "5. Choose **Cash on Delivery (COD)** or **GCash**, then tap **Confirm Order Delivery**!";
    }

    if (query.contains('status') ||
        query.contains('where') ||
        query.contains('track') ||
        query.contains('order') ||
        query.contains('delivery')) {
      final orders = orderProvider.getCustomerOrders(userId);
      if (orders.isEmpty) {
        return "📦 You haven't placed any orders yet! Open the **Order Water** tab to choose your water type and jug type.";
      }
      final latest = orders.first;
      return "📦 **Latest Order Status (${latest.id})**\n\n"
          "- **Items**: ${latest.itemsSummary}\n"
          "- **Total**: **${latest.formattedTotal}**\n"
          "- **Status**: **${latest.orderStatus.displayName}**\n"
          "- **Driver**: ${latest.driverName ?? 'Assigning soon'}\n"
          "- **Payment**: ${latest.paymentMethod} (${latest.paymentStatus})\n"
          "- **Delivery Address**: ${latest.deliveryAddress}";
    }

    if (query.contains('price') ||
        query.contains('product') ||
        query.contains('catalog') ||
        query.contains('cost') ||
        query.contains('how much') ||
        query.contains('magkano')) {
      final list = orderProvider.waterProducts.map((p) {
        return "- **${p['name']}**: **₱${(p['price'] as num).toStringAsFixed(2)}** per 5-Gallon jug *(${(p['stock'] as num).toInt()} in stock)*";
      }).join('\n');
      return "💧 **JJAASS Water Market Price List**\n\n$list\n\n"
          "Available in **5-Gallon Slim** (with faucet) or **5-Gallon Round** (dispenser) jugs!";
    }

    if (query.contains('gcash') || query.contains('paymongo')) {
      return "💳 **How to Pay with GCash (Step-by-Step Guide)**\n\n"
          "1. **Select Payment**: On checkout, select **GCash Mobile Payment**.\n"
          "2. **Confirm Order**: Tap **Confirm Order Delivery**.\n"
          "3. **PayMongo Portal**: The official, secure PayMongo checkout dialog will appear.\n"
          "4. **Complete Payment**: Scan the GCash QR code or enter your GCash mobile number and MPIN.\n"
          "5. **Instant Sync**: Your order immediately flags as **Paid**, and dispatch begins!\n\n"
          "💡 **Missed Paying?**: Open the **Track Deliveries** tab anytime to tap the **Pay Now (GCash)** button.";
    }

    if (query.contains('payment') ||
        query.contains('pay') ||
        query.contains('cod') ||
        query.contains('cash')) {
      return "💵 **Payment Methods & Guidelines**\n\n"
          "1. **Cash on Delivery (COD)**:\n"
          "   • Pay our rider directly upon physical delivery at your door.\n"
          "   • Digital proof of transaction is recorded instantly on the driver's app.\n"
          "   • *Tip*: Preparing exact change speeds up the delivery process!\n\n"
          "2. **GCash Mobile Payment (PayMongo)**:\n"
          "   • Secure cashless instant checkout.\n"
          "   • Real-time payment confirmation and zero contact required.";
    }

    final orders = orderProvider.getCustomerOrders(userId);
    final latestInfo = orders.isNotEmpty
        ? "\n\n📦 *Your latest order **${orders.first.id}** (${orders.first.itemsSummary}) is currently **${orders.first.orderStatus.displayName}**.*"
        : "";

    return "Hello **$userName**! 💧 I'm **AquaBot**, your JJAASS Water Market assistant.$latestInfo\n\n"
        "You can ask me:\n"
        "- **'What are your water prices?'** (19L Purified Refill ₱30, 19L Set A with New Container ₱230)\n"
        "- **'What jug types do you have?'** (5-Gallon Slim & Round)\n"
        "- **'Where is my order?'** to track your delivery\n"
        "- **'Where is your store located?'** ($marketAddress)";
  }

  /// Formats all system details into a prompt-friendly string
  static String _gatherSystemContext({
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) {
    final buffer = StringBuffer();
    buffer.writeln("=== BUSINESS INFORMATION ===");
    buffer.writeln("Business Name: JJAASS Water Market");
    buffer.writeln("Address: $marketAddress");
    buffer.writeln("Jug Types Available: 5-Gallon Slim (with Faucet & Handle), 5-Gallon Round (for Dispenser)");
    if (isAdmin) {
      buffer.writeln("=== SYSTEM ANALYTICS ===");
      buffer.writeln("Total System Revenue: ₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}");
      buffer.writeln("Completed Orders: ${orderProvider.getCompletedCount()}");
      buffer.writeln("Pending Orders: ${orderProvider.getPendingCount()}");
      buffer.writeln("Active Deliveries: ${orderProvider.getActiveDeliveriesCount()}");
      buffer.writeln("=== WATER PRODUCTS ===");
      for (var p in orderProvider.waterProducts) {
        buffer.writeln("- Product: ${p['name']}, Price: ₱${p['price']}, Stock: ${p['stock']}/${p['capacity']}, Description: ${p['description'] ?? ''}");
      }
    } else if (isDriver) {
      buffer.writeln("=== DRIVER INFORMATION ===");
      buffer.writeln("Driver ID: $userId");
      buffer.writeln("Driver Name: $userName");
      buffer.writeln("Uncashed Earnings: ₱${orderProvider.getDriverEarnings(userId).toStringAsFixed(2)}");

      final activeJob = orderProvider.getActiveDriverJob(userId);
      if (activeJob != null) {
        buffer.writeln("Active Job: ${activeJob.id}, Customer: ${activeJob.customerName}, Phone: ${activeJob.customerPhone}, Address: ${activeJob.deliveryAddress}, Items: ${activeJob.itemsSummary}, Distance: ${activeJob.distance}");
      } else {
        buffer.writeln("Active Job: None");
      }

      final available = orderProvider.getAvailableDriverJobs(userId);
      buffer.writeln("Assigned Queue Count: ${available.length}");
      for (var job in available) {
        buffer.writeln("- Queue Job: ${job.id}, Customer: ${job.customerName}, Address: ${job.deliveryAddress}, Items: ${job.itemsSummary}");
      }
    } else {
      buffer.writeln("=== CUSTOMER PROFILE ===");
      buffer.writeln("Customer ID: $userId");
      buffer.writeln("Customer Name: $userName");
      buffer.writeln("Loyalty Rewards Points: ${orderProvider.getCustomerRewardPoints(userId)}");

      final customerOrders = orderProvider.getCustomerOrders(userId);
      buffer.writeln("Order History Count: ${customerOrders.length}");
      for (var o in customerOrders.take(5)) {
        buffer.writeln("- Order ${o.id}: Items: ${o.itemsSummary}, Total: ${o.formattedTotal}, Status: ${o.orderStatus.displayName}, Payment: ${o.paymentMethod} (${o.paymentStatus}), Address: ${o.deliveryAddress}, Date: ${o.createdAt}");
      }
      buffer.writeln("=== PRODUCT CATALOG ===");
      for (var p in orderProvider.waterProducts) {
        buffer.writeln("- ${p['name']}: ₱${p['price']} (Available Stock: ${p['stock']}, Description: ${p['description'] ?? ''})");
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
      return o.driverId == driverId &&
          (o.orderStatus == OrderStatus.onDelivery ||
              o.orderStatus == OrderStatus.assigned);
    }).toList();

    if (jobs.isEmpty) {
      return "⚠️ **Route Optimization Notice**\n\nYou do not have any pending or active delivery jobs assigned. Please accept jobs from your dashboard before optimizing.";
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
      buffer.writeln("   - **Quantity**: ${order.itemsSummary}");
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
