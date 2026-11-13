part of 'admin_dashboard.dart';

extension _AdminDeliveries on _AdminDashboardState {
  // TAB 2: DELIVERIES FLEET (GPS & Assignments Monitor)
  // TAB 2: DELIVERIES FLEET (Live GPS & Dispatch Command Center)
  Widget _buildDeliveriesTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;
    final driversList = _allUsers
        .where((u) => u.role == UserRole.driver)
        .toList();
    final today = DateTime.now();

    // Stats
    final activeOnRouteCount = allOrders
        .where(
          (o) =>
              o.orderStatus == OrderStatus.onDelivery ||
              o.orderStatus == OrderStatus.assigned,
        )
        .length;
    final pendingDispatchCount = allOrders
        .where(
          (o) =>
              o.orderStatus == OrderStatus.pending ||
              o.orderStatus == OrderStatus.confirmed,
        )
        .length;
    final completedCount = allOrders
        .where((o) => o.orderStatus == OrderStatus.completed)
        .length;
    final totalDriversCount = driversList.length;

    // Filter by tab selection
    List<OrderModel> categoryFiltered = allOrders;
    if (_deliveriesFilter == 'Active') {
      categoryFiltered = allOrders
          .where(
            (o) =>
                o.orderStatus == OrderStatus.onDelivery ||
                o.orderStatus == OrderStatus.assigned,
          )
          .toList();
    } else if (_deliveriesFilter == 'Pending') {
      categoryFiltered = allOrders
          .where(
            (o) =>
                o.orderStatus == OrderStatus.pending ||
                o.orderStatus == OrderStatus.confirmed,
          )
          .toList();
    } else if (_deliveriesFilter == 'Completed') {
      categoryFiltered = allOrders
          .where((o) => o.orderStatus == OrderStatus.completed)
          .toList();
    } else if (_deliveriesFilter == 'Today') {
      categoryFiltered = allOrders
          .where(
            (o) =>
                o.createdAt.year == today.year &&
                o.createdAt.month == today.month &&
                o.createdAt.day == today.day,
          )
          .toList();
    }

    // Filter by search query
    final query = _deliveriesSearchController.text.trim().toLowerCase();
    final filteredDeliveries = query.isEmpty
        ? categoryFiltered
        : categoryFiltered.where((o) {
            final id = o.id.toLowerCase();
            final customer = o.customerName.toLowerCase();
            final rider = (o.driverName ?? '').toLowerCase();
            final address = o.deliveryAddress.toLowerCase();
            final water = o.waterType.toLowerCase();
            return id.contains(query) ||
                customer.contains(query) ||
                rider.contains(query) ||
                address.contains(query) ||
                water.contains(query);
          }).toList();

    final cardBgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final titleTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final valueTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet & Deliveries Command Center',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live GPS route tracking, rider dispatches, and delivery telemetry across Albay 1st District (Tabaco City, Bacacay, Malilipot, Malinao, Santo Domingo, Tiwi).',
                    style: TextStyle(fontSize: 12, color: titleTextColor),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    avatar: Icon(
                      _mapSatelliteMode
                          ? Icons.satellite_alt_rounded
                          : Icons.map_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text(
                      _mapSatelliteMode ? 'Satellite Dark' : 'Vector Map',
                    ),
                    onPressed: () {
                      setState(() {
                        _mapSatelliteMode = !_mapSatelliteMode;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showScheduleCollectionDialog(isDark),
                    icon: const Icon(Icons.assignment_add, size: 16),
                    label: const Text('Schedule Weekly Collection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top KPI Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final crossAxisCount = isNarrow ? 2 : 4;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isNarrow ? 1.6 : 1.9,
                children: [
                  _buildDeliveryKpiCard(
                    title: 'Active On Route',
                    value: '$activeOnRouteCount Dispatches',
                    icon: Icons.local_shipping_rounded,
                    color: Colors.cyan,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                  _buildDeliveryKpiCard(
                    title: 'Riders Online',
                    value: '$totalDriversCount Available',
                    icon: Icons.delivery_dining_rounded,
                    color: AppTheme.primaryColor,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                  _buildDeliveryKpiCard(
                    title: 'Pending Dispatch',
                    value: '$pendingDispatchCount Orders',
                    icon: Icons.pending_actions_rounded,
                    color: Colors.orange,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                  _buildDeliveryKpiCard(
                    title: 'Delivered Today',
                    value: '$completedCount Completed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Live Route Map Monitor Widget
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Fleet GPS Route Monitor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedDeliveryOrder != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _selectedDeliveryOrder = null),
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text(
                          'Clear Selection',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LiveFleetGpsMapWidget(
                  orders: allOrders,
                  drivers: driversList,
                  selectedOrder: _selectedDeliveryOrder,
                  isDark: isDark,
                  satelliteMode: _mapSatelliteMode,
                  onSelectOrder: (order) {
                    setState(() {
                      _selectedDeliveryOrder = order;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Daily Delivery Assignments & Live Feed
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deliveriesSearchController,
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              'Search deliveries by ID, customer, rider, or address...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon:
                              _deliveriesSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _deliveriesSearchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDeliveryFilterChip(
                      label: 'All Deliveries (${allOrders.length})',
                      value: 'All',
                      icon: Icons.list_alt_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'On Route ($activeOnRouteCount)',
                      value: 'Active',
                      icon: Icons.local_shipping_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'Pending ($pendingDispatchCount)',
                      value: 'Pending',
                      icon: Icons.hourglass_top_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'Completed ($completedCount)',
                      value: 'Completed',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'Today\'s Feed',
                      value: 'Today',
                      icon: Icons.today_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Deliveries List
                if (filteredDeliveries.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 48,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No deliveries match your search or filter.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: titleTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 480,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        itemCount: filteredDeliveries.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: borderColor, height: 16),
                        itemBuilder: (context, index) {
                          final o = filteredDeliveries[index];
                          final isSelected = _selectedDeliveryOrder?.id == o.id;

                          Color statusColor = o.orderStatus.color;
                          IconData statusIcon = Icons.info_outline;
                          if (o.orderStatus == OrderStatus.pending) {
                            statusIcon = Icons.hourglass_empty_rounded;
                          } else if (o.orderStatus == OrderStatus.confirmed) {
                            statusIcon = Icons.assignment_turned_in_rounded;
                          } else if (o.orderStatus == OrderStatus.assigned) {
                            statusIcon = Icons.assignment_ind_rounded;
                          } else if (o.orderStatus == OrderStatus.onDelivery) {
                            statusIcon = Icons.local_shipping_rounded;
                          } else if (o.orderStatus == OrderStatus.completed) {
                            statusIcon = Icons.check_circle_rounded;
                          }

                          final bool isPending =
                              o.orderStatus == OrderStatus.pending;
                          final bool canAssign =
                              o.orderStatus == OrderStatus.pending ||
                              o.orderStatus == OrderStatus.confirmed ||
                              o.orderStatus == OrderStatus.assigned;
                          final bool canComplete =
                              o.orderStatus == OrderStatus.onDelivery ||
                              o.orderStatus == OrderStatus.assigned;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(
                                      alpha: 0.08,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Status Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Main Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            o.id,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: valueTextColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              o.orderStatus.displayName,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${o.waterType} (${o.quantity} jugs)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: titleTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${_resolveCustomerDisplayName(o)} • ${o.deliveryAddress}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: valueTextColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.two_wheeler_rounded,
                                            size: 14,
                                            color: AppTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Rider: ${o.requiresDriver ? (o.driverName ?? "Unassigned") : "Pickup / Walk-in"}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: o.driverName != null
                                                  ? AppTheme.primaryColor
                                                  : Colors.orange,
                                              fontWeight: o.driverName != null
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Distance: ${o.distance}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: titleTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Focus on Map Button
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedDeliveryOrder = o;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.pin_drop_rounded,
                                        size: 14,
                                      ),
                                      label: Text(
                                        isSelected ? 'Selected' : 'Track',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        side: BorderSide(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : borderColor,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Dispatch / Complete Button
                                    if (isPending)
                                      ElevatedButton(
                                        onPressed: () async {
                                          await orderProvider.confirmOrder(
                                            o.id,
                                          );
                                          if (context.mounted) {
                                            Helpers.showSnackBar(
                                              context,
                                              'Order ${o.id} confirmed!',
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Confirm',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    else if (canAssign)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (driversList.isEmpty) {
                                            Helpers.showSnackBar(
                                              context,
                                              'No registered riders available to dispatch.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          _showAssignDriverDialog(
                                            o,
                                            driversList,
                                            isDark,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          o.driverName != null
                                              ? 'Reassign'
                                              : 'Assign Rider',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF8B5CF6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (canComplete)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await orderProvider.updateOrderStatus(
                                            orderId: o.id,
                                            newStatus: OrderStatus.completed,
                                          );
                                          if (context.mounted) {
                                            Helpers.showSnackBar(
                                              context,
                                              'Order ${o.id} marked as Delivered!',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Delivered',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _deliveriesFilter == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _deliveriesFilter = value;
          });
        }
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
    );
  }

  void _showAssignDriverDialog(
    OrderModel order,
    List<UserModel> driversList,
    bool isDark,
  ) {
    UserModel selectedDriver = driversList.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: const Text('Dispatch Order Delivery'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign a rider for Order ${order.id}:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserModel>(
                    isExpanded: true,
                    initialValue: selectedDriver,
                    dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Select Available Rider',
                      prefixIcon: Icon(Icons.delivery_dining_rounded),
                    ),
                    items: driversList.map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(
                          '${d.name} (${d.email})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedDriver = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    try {
                      await orderProvider.assignDriver(
                        orderId: order.id,
                        driverId: selectedDriver.id,
                        driverName: selectedDriver.name,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Helpers.showSnackBar(
                          context,
                          'Rider ${selectedDriver.name} assigned successfully!',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Helpers.showSnackBar(
                          context,
                          'Dispatch failed: $e',
                          isError: true,
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Confirm Dispatch',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGcashPaymentDialog(OrderModel order, bool isDark) {
    GCashPaymentModal.show(
      context,
      order: order,
      paymentService: _paymentService,
      isDark: isDark,
      role: 'admin',
    );
  }
}
