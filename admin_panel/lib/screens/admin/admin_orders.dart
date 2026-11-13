part of 'admin_dashboard.dart';

extension _AdminOrders on _AdminDashboardState {
  // TAB 1: ORDERS MANAGEMENT (Interactive Order status updater)
  Widget _buildOrdersTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    final filtered = _activeOrderFilter == 'All'
        ? allOrders
        : allOrders
              .where((o) => o.orderStatus.displayName == _activeOrderFilter)
              .toList();

    final searchQuery = _orderSearchController.text.trim().toLowerCase();
    final searchFiltered = searchQuery.isEmpty
        ? filtered
        : filtered.where((o) {
            return o.id.toLowerCase().contains(searchQuery) ||
                o.customerName.toLowerCase().contains(searchQuery) ||
                o.customerPhone.toLowerCase().contains(searchQuery) ||
                o.deliveryAddress.toLowerCase().contains(searchQuery) ||
                o.itemsSummary.toLowerCase().contains(searchQuery);
          }).toList();

    // Group orders by Customer Division
    final Map<String, List<OrderModel>> customerDivisions = {};
    for (var o in searchFiltered) {
      final key = _resolveCustomerDisplayName(o);
      customerDivisions.putIfAbsent(key, () => []).add(o);
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrdersTopSubTabs(isDark, allOrders.length),
          if (_ordersSubTab == 1) ...[
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildDeliveryIssueClaimsTab(isDark),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Orders Management Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateOrderDialog(isDark),
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'New Order',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search & Filter Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _orderSearchController,
                      onChanged: (_) => setState(() {}),
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText:
                            'Search orders by ID (#COL, #ORD), customer name, address...',
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        suffixIcon: _orderSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 14),
                                onPressed: () => setState(
                                  () => _orderSearchController.clear(),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'All',
                      'Pending',
                      'On Delivery',
                      'Completed',
                      'Cancelled',
                    ].map((status) {
                      final isSel = _activeOrderFilter == status;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSel,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _activeOrderFilter = status;
                            });
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: searchFiltered.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders match this status or search query.',
                      ),
                    )
                  : ListView(
                      children: [
                        for (var entry in customerDivisions.entries) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.badge_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 17,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Customer Division: ${entry.key}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.navyColor,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${entry.value.length} Order${entry.value.length > 1 ? "s" : ""}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value.map((order) {
                            final bool isPending =
                                order.orderStatus == OrderStatus.pending;
                            return PulsingBorder(
                              active: isPending,
                              color: Colors.orange,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            order.id,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: order.orderStatus.color
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: order.orderStatus.color
                                                    .withValues(alpha: 0.2),
                                              ),
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
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Customer: ${_resolveCustomerDisplayName(order)} (${order.customerPhone})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('Products: ${order.itemsSummary}'),
                                      Text(
                                        'Delivery Address: ${order.deliveryAddress}',
                                      ),
                                      if (order.deliveryNote != null)
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFF59E0B),
                                            ),
                                          ),
                                          child: Text(
                                            '📝 Customer Note: ${order.deliveryNote}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF78350F),
                                            ),
                                          ),
                                        ),
                                      Text(
                                        'Assigned Driver: ${order.requiresDriver ? (order.driverName ?? "Unassigned") : "Not Needed (Walk-in/Pickup)"}',
                                      ),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Total Amount: ${order.formattedTotal} (${order.paymentMethod} • ${order.paymentStatus})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (order.paymentStatus ==
                                                  'Pending' &&
                                              order.paymentMethod ==
                                                  'GCash') ...[
                                            InkWell(
                                              onTap: () =>
                                                  _showGcashPaymentDialog(
                                                    order,
                                                    isDark,
                                                  ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.blue
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.qr_code_2_rounded,
                                                      size: 12,
                                                      color: Colors.blue,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Scan QR',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (order.orderStatus ==
                                          OrderStatus.pending) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final orderProvider =
                                                  Provider.of<OrderProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              await orderProvider.confirmOrder(
                                                order.id,
                                              );
                                              if (!mounted) return;
                                              Helpers.showSnackBar(
                                                context,
                                                'Order ${order.id} confirmed successfully!',
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                            child: const Text(
                                              'Confirm Order',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else if (order.orderStatus ==
                                          OrderStatus.confirmed) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              if (order.requiresDriver) {
                                                final driversList = _allUsers
                                                    .where(
                                                      (u) =>
                                                          u.role ==
                                                          UserRole.driver,
                                                    )
                                                    .toList();
                                                if (driversList.isEmpty) {
                                                  Helpers.showSnackBar(
                                                    context,
                                                    'No registered riders available to dispatch.',
                                                    isError: true,
                                                  );
                                                  return;
                                                }
                                                _showAssignDriverDialog(
                                                  order,
                                                  driversList,
                                                  isDark,
                                                );
                                              } else {
                                                final orderProvider =
                                                    Provider.of<OrderProvider>(
                                                      context,
                                                      listen: false,
                                                    );
                                                await orderProvider
                                                    .updateOrderStatus(
                                                      orderId: order.id,
                                                      newStatus:
                                                          OrderStatus.completed,
                                                    );
                                                if (!mounted) return;
                                                Helpers.showSnackBar(
                                                  context,
                                                  'Order ${order.id} completed successfully!',
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  order.paymentMethod ==
                                                      'Cash on Delivery'
                                                  ? const Color(0xFF8B5CF6)
                                                  : const Color(0xFF10B981),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                            child: Text(
                                              order.paymentMethod ==
                                                      'Cash on Delivery'
                                                  ? 'Assign Rider'
                                                  : 'Complete Order',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _showInboxDialog(
                                              isDark,
                                              targetConversationId:
                                                  'order_${order.id}',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primaryColor,
                                              side: const BorderSide(
                                                color: AppTheme.primaryColor,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.chat_bubble_outline_rounded,
                                              size: 14,
                                              color: AppTheme.primaryColor,
                                            ),
                                            label: const Text(
                                              'Live Chat',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _confirmDeleteOrder(
                                                  order,
                                                  isDark,
                                                ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(
                                                color: Colors.redAccent,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 14,
                                              color: Colors.redAccent,
                                            ),
                                            label: const Text(
                                              'Delete Order',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // Top Sub-Tabs Switcher: Orders Log vs Delivery Defect & Swap Claims
  Widget _buildOrdersTopSubTabs(bool isDark, int allOrdersCount) {
    return ListenableBuilder(
      listenable: DeliveryIssueService.instance,
      builder: (context, _) {
        final pendingCount = DeliveryIssueService.instance.pendingCount;
        final activeCount = DeliveryIssueService.instance.activeCount;

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _ordersSubTab = 0),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _ordersSubTab == 0
                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _ordersSubTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: _ordersSubTab == 0
                              ? AppTheme.primaryColor
                              : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Orders Log ($allOrdersCount)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _ordersSubTab == 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _ordersSubTab == 0
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A))
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _ordersSubTab = 1),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _ordersSubTab == 1
                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _ordersSubTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_horizontal_circle_rounded,
                          size: 16,
                          color: _ordersSubTab == 1
                              ? (pendingCount > 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669))
                              : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delivery Defect & Swap Claims ($activeCount)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _ordersSubTab == 1
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _ordersSubTab == 1
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A))
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount New',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
