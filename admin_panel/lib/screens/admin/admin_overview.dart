part of 'admin_dashboard.dart';

extension _AdminOverview on _AdminDashboardState {
  // TAB 0: OVERVIEW/DASHBOARD
  Widget _buildOverviewTab(bool isDark, double screenWidth) {
    final bool isDesktop = screenWidth >= 1100;
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;
    final totalRevenue = orderProvider.getTotalRevenue();
    final activeDeliveries = orderProvider.getActiveDeliveriesCount();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final crossCount = width > 1000 ? 4 : (width > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: width > 1000 ? 1.6 : 1.8,
                children: [
                  _buildStatCard(
                    'Total Orders',
                    '${orders.length}',
                    '18% from last week',
                    Icons.local_drink_rounded,
                    const Color(0xFF0284C7),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Active Deliveries',
                    '$activeDeliveries',
                    'Out for delivery',
                    Icons.local_shipping_rounded,
                    const Color(0xFF0284C7),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Total Users',
                    '${_allUsers.length}',
                    'Customers & Drivers',
                    Icons.group_rounded,
                    const Color(0xFF0EA5E9),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Total Revenue',
                    '₱${totalRevenue.toStringAsFixed(2)}',
                    'Gross sales',
                    Icons.payments_rounded,
                    const Color(0xFF10B981),
                    isDark,
                    isUpTrend: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Main Charts and Orders Grid
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildSalesOverviewCard(isDark)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildRecentOrdersListCard(isDark)),
              ],
            )
          else
            Column(
              children: [
                _buildSalesOverviewCard(isDark),
                const SizedBox(height: 16),
                _buildRecentOrdersListCard(isDark),
              ],
            ),
          const SizedBox(height: 20),

          // Bottom Table & Quick Actions Layout
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildRecentOrdersTableCard(isDark)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildQuickActionsCard(isDark),
                      const SizedBox(height: 16),
                      _buildAiSupportCard(isDark),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildRecentOrdersTableCard(isDark),
                const SizedBox(height: 16),
                _buildQuickActionsCard(isDark),
                const SizedBox(height: 16),
                _buildAiSupportCard(isDark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String trend,
    IconData icon,
    Color color,
    bool isDark, {
    required bool isUpTrend,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isUpTrend
                        ? const Color(
                            0xFF10B981,
                          ).withValues(alpha: isDark ? 0.2 : 0.1)
                        : Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isUpTrend
                          ? const Color(
                              0xFF10B981,
                            ).withValues(alpha: isDark ? 0.45 : 0.25)
                          : Colors.red.withValues(alpha: isDark ? 0.45 : 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUpTrend
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isUpTrend ? const Color(0xFF10B981) : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trend,
                        style: TextStyle(
                          color: isUpTrend
                              ? (isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF047857))
                              : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.4 : 0.2),
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  // Helper to compute live Sales Overview data based on selected timeframe
  Map<String, dynamic> _computeSalesOverviewData(List<OrderModel> orders) {
    final now = DateTime.now();
    List<double> dataPoints = [];
    List<String> labels = [];

    if (_salesTimeframe == 'This Week') {
      final currentWeekday = now.weekday; // 1 to 7
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: currentWeekday - 1));
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dataPoints = List.filled(7, 0.0);

      for (var order in orders) {
        final orderDate = order.createdAt;
        final diffDays = orderDate.difference(monday).inDays;
        if (diffDays >= 0 &&
            diffDays < 7 &&
            orderDate.isAfter(monday.subtract(const Duration(seconds: 1)))) {
          final dayIdx = (orderDate.weekday - 1).clamp(0, 6);
          dataPoints[dayIdx] += order.totalAmount;
        }
      }
    } else if (_salesTimeframe == 'Last 7 Days') {
      labels = [];
      dataPoints = List.filled(7, 0.0);
      final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        if (i == 0) {
          labels.add('Today');
        } else {
          labels.add(daysOfWeek[d.weekday - 1]);
        }
      }
      for (var order in orders) {
        final diffDays = now.difference(order.createdAt).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          final idx = 6 - diffDays;
          if (idx >= 0 && idx < 7) {
            dataPoints[idx] += order.totalAmount;
          }
        }
      }
    } else if (_salesTimeframe == 'This Month') {
      labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
      dataPoints = List.filled(4, 0.0);

      for (var order in orders) {
        if (order.createdAt.year == now.year &&
            order.createdAt.month == now.month) {
          final day = order.createdAt.day;
          final weekIdx = ((day - 1) ~/ 7).clamp(0, 3);
          dataPoints[weekIdx] += order.totalAmount;
        }
      }
    } else {
      // 'All Time' -> Last 6 Months
      labels = [];
      dataPoints = List.filled(6, 0.0);
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      for (int i = 5; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        labels.add(monthNames[m.month - 1]);
      }
      for (var order in orders) {
        final monthsAgo =
            (now.year - order.createdAt.year) * 12 +
            (now.month - order.createdAt.month);
        if (monthsAgo >= 0 && monthsAgo < 6) {
          final idx = 5 - monthsAgo;
          if (idx >= 0 && idx < 6) {
            dataPoints[idx] += order.totalAmount;
          }
        }
      }
    }

    return {'dataPoints': dataPoints, 'labels': labels};
  }

  Widget _buildSalesOverviewCard(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final salesInfo = _computeSalesOverviewData(orderProvider.orders);
    final List<double> dataPoints = salesInfo['dataPoints'] as List<double>;
    final List<String> labels = salesInfo['labels'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _salesTimeframe,
                tooltip: 'Select Timeframe',
                onSelected: (val) {
                  setState(() {
                    _salesTimeframe = val;
                    _selectedSalesPointIndex = null;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: isDark ? AppTheme.darkSurface : Colors.white,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'This Week',
                    child: Text('This Week (Mon-Sun)'),
                  ),
                  const PopupMenuItem(
                    value: 'Last 7 Days',
                    child: Text('Last 7 Days'),
                  ),
                  const PopupMenuItem(
                    value: 'This Month',
                    child: Text('This Month'),
                  ),
                  const PopupMenuItem(
                    value: 'All Time',
                    child: Text('All Time (6 Months)'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _salesTimeframe,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: SalesOverviewLineChart(
                dataPoints: dataPoints,
                labels: labels,
                selectedIndex: _selectedSalesPointIndex,
                isDark: isDark,
                onPointSelected: (idx) {
                  setState(() {
                    _selectedSalesPointIndex = idx;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((entry) {
              final idx = entry.key;
              final day = entry.value;
              final isSelected = _selectedSalesPointIndex == idx;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSalesPointIndex = idx;
                  });
                },
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersListCard(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedTab = 1;
                  _activeSidebarMenu = 1;
                }),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: min(orders.length, 5),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: order.orderStatus.color.withValues(
                            alpha: isDark ? 0.25 : 0.1,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 14,
                            color: order.orderStatus.color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.id,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${order.customerName} • ${order.itemsSummary}',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: order.orderStatus.color.withValues(
                                  alpha: isDark ? 0.25 : 0.1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: order.orderStatus.color.withValues(
                                    alpha: isDark ? 0.5 : 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                order.orderStatus.displayName,
                                style: TextStyle(
                                  color: order.orderStatus.color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.createdAt.toString().split(' ')[0],
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF475569),
                                fontSize: 9,
                              ),
                            ),
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

  Widget _buildRecentOrdersTableCard(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _selectedTab = 1;
                  _activeSidebarMenu = 1;
                }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  children: const [
                    Text(
                      'View All Orders',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    horizontalMargin: 0,
                    headingRowHeight: 40,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 48,
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Order ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Products',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Address',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    rows: orders.map((data) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              data.id,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data.customerName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data.itemsSummary,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data.deliveryAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: data.orderStatus.color.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: data.orderStatus.color.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Text(
                                data.orderStatus.displayName,
                                style: TextStyle(
                                  color: data.orderStatus.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data.formattedTotal,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data.createdAt.toString().split(' ')[0],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _buildQuickActionItem(
                'New Order',
                Icons.add_shopping_cart_rounded,
                const Color(0xFF0284C7),
                () {
                  setState(() {
                    _selectedTab = 1;
                    _activeSidebarMenu = 1;
                  });
                  _showCreateOrderDialog(isDark);
                },
              ),
              _buildQuickActionItem(
                'Users & Roles',
                Icons.manage_accounts_rounded,
                const Color(0xFF0284C7),
                () => setState(() {
                  _selectedTab = 3;
                  _activeSidebarMenu = 3;
                }),
              ),
              _buildQuickActionItem(
                'New Delivery',
                Icons.local_shipping_rounded,
                const Color(0xFF0EA5E9),
                () => setState(() {
                  _selectedTab = 2;
                  _activeSidebarMenu = 2;
                }),
              ),
              _buildQuickActionItem(
                'Add Inventory',
                Icons.add_box_rounded,
                const Color(0xFF10B981),
                () => setState(() {
                  _selectedTab = 4;
                  _activeSidebarMenu = 4;
                }),
              ),
              _buildQuickActionItem(
                'View Reports',
                Icons.analytics_rounded,
                const Color(0xFF6366F1),
                () => setState(() {
                  _selectedTab = 6;
                  _activeSidebarMenu = 6;
                }),
              ),
              _buildQuickActionItem(
                'Payments',
                Icons.payments_rounded,
                const Color(0xFFEC4899),
                () => setState(() {
                  _selectedTab = 5;
                  _activeSidebarMenu = 5;
                }),
              ),
              _buildQuickActionItem(
                'AI Support',
                Icons.support_agent_rounded,
                const Color(0xFF8B5CF6),
                () => setState(() {
                  _selectedTab = 7;
                  _activeSidebarMenu = 7;
                }),
              ),
              _buildQuickActionItem(
                'Settings',
                Icons.settings_rounded,
                const Color(0xFF64748B),
                () => setState(() {
                  _selectedTab = 8;
                  _activeSidebarMenu = 8;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSupportCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.psychology_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'AI Chat Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: const Color(0xFFE2F0F3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.adb_rounded, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AquaBot',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hello! I\'m AquaBot 💧 How can I help you today?',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          height: 1.3,
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
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _supportInputController,
                    onSubmitted: (text) {
                      setState(() {
                        _selectedTab = 7;
                        _activeSidebarMenu = 7;
                      });
                      _sendSupportMessage(text);
                    },
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Color(0xFF64748B)),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    final text = _supportInputController.text;
                    setState(() {
                      _selectedTab = 7;
                      _activeSidebarMenu = 7;
                    });
                    _sendSupportMessage(text);
                  },
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 14,
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

  // Dialog helper to create a New Order (Delivery or Store Pickup)
  void _showCreateOrderDialog(bool isDark) {
    final customersList = _allUsers
        .where((u) => u.role == UserRole.customer)
        .toList();
    final driversList = _allUsers
        .where((u) => u.role == UserRole.driver)
        .toList();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    // Fulfillment choice: 'Delivery' vs 'Pickup'
    String fulfillmentType = 'Delivery';

    // Customer mode: isRegistered vs isUnregistered
    bool isRegistered = false;
    UserModel? selectedCustomer;

    // Delivery Driver selection (only for Delivery)
    UserModel? selectedDriver;
    if (driversList.isNotEmpty) {
      selectedDriver = driversList.first;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+63 ');
    final addressController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    bool isBorrowingContainers = false;
    final slimBorrowController = TextEditingController(text: '0');
    final roundBorrowController = TextEditingController(text: '0');

    String selectedWaterType = orderProvider.waterProducts.isNotEmpty
        ? (orderProvider.waterProducts.first['name'] as String)
        : '19L Purified';
    double pricePerUnit = orderProvider.waterProducts.isNotEmpty
        ? (orderProvider.waterProducts.first['price'] as double)
        : 30.0;
    String selectedPaymentMethod = 'Cash on Delivery';
    String selectedPaymentStatus = 'Pending';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDelivery = fulfillmentType == 'Delivery';
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth < 580
                ? (screenWidth * 0.92)
                : 520.0;
            final isMobile = screenWidth < 480;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create New Order',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: dialogWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. FULFILLMENT TYPE TOGGLE (Delivery vs Store Pickup)
                      Text(
                        'ORDER FULFILLMENT TYPE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  fulfillmentType = 'Delivery';
                                  if (addressController.text.contains(
                                    'Store Pickup',
                                  )) {
                                    addressController.clear();
                                  }
                                  if (selectedPaymentMethod == 'Cash') {
                                    selectedPaymentMethod = 'Cash on Delivery';
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDelivery
                                      ? AppTheme.primaryColor.withValues(
                                          alpha: 0.1,
                                        )
                                      : (isDark
                                            ? Colors.white10
                                            : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDelivery
                                        ? AppTheme.primaryColor
                                        : (isDark
                                              ? Colors.white24
                                              : const Color(0xFFCBD5E1)),
                                    width: isDelivery ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_shipping_rounded,
                                      size: 20,
                                      color: isDelivery
                                          ? AppTheme.primaryColor
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Home Delivery',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDelivery
                                              ? AppTheme.primaryColor
                                              : (isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  fulfillmentType = 'Pickup';
                                  addressController.text =
                                      'Store Pickup / Walk-in (JJAASS Water Station)';
                                  if (selectedPaymentMethod ==
                                      'Cash on Delivery') {
                                    selectedPaymentMethod = 'Cash';
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: !isDelivery
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.1)
                                      : (isDark
                                            ? Colors.white10
                                            : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !isDelivery
                                        ? const Color(0xFF10B981)
                                        : (isDark
                                              ? Colors.white24
                                              : const Color(0xFFCBD5E1)),
                                    width: !isDelivery ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      size: 20,
                                      color: !isDelivery
                                          ? const Color(0xFF10B981)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Store Pickup',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: !isDelivery
                                              ? const Color(0xFF10B981)
                                              : (isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. CUSTOMER DETAILS (Registered vs Unregistered)
                      Text(
                        'CUSTOMER INFORMATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Unregistered / Walk-in'),
                            selected: !isRegistered,
                            onSelected: (val) {
                              setDialogState(() {
                                isRegistered = false;
                                selectedCustomer = null;
                                nameController.clear();
                                phoneController.text = '+63 ';
                                if (isDelivery) {
                                  addressController.clear();
                                }
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Registered Customer'),
                            selected: isRegistered,
                            onSelected: (val) {
                              setDialogState(() {
                                isRegistered = true;
                                if (customersList.isNotEmpty) {
                                  selectedCustomer = customersList.first;
                                  nameController.text = selectedCustomer!.name;
                                  phoneController.text = '+63 912 345 6789';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isRegistered) ...[
                        if (customersList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              'No registered customer accounts found. You can enter details manually below.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<UserModel>(
                            isExpanded: true,
                            initialValue: selectedCustomer,
                            dropdownColor: isDark
                                ? AppTheme.darkSurface
                                : Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Select Registered Customer',
                              prefixIcon: Icon(Icons.account_circle_rounded),
                            ),
                            items: customersList.map((cust) {
                              return DropdownMenuItem<UserModel>(
                                value: cust,
                                child: Text(
                                  '${cust.name} (${cust.email})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedCustomer = val;
                                  nameController.text = val.name;
                                });
                              }
                            },
                          ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Full Name *',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        enabled: isDelivery,
                        decoration: InputDecoration(
                          labelText: isDelivery
                              ? 'Delivery Address (Albay 1st District) *'
                              : 'Pickup Location',
                          hintText: isDelivery
                              ? 'e.g. Purok 1, Tabaco City, Albay'
                              : null,
                          prefixIcon: Icon(
                            isDelivery
                                ? Icons.location_on
                                : Icons.storefront_rounded,
                          ),
                          helperText: !isDelivery
                              ? 'Store pickup orders are collected at the station'
                              : 'Service Scope: Tabaco City, Bacacay, Malilipot, Malinao, Santo Domingo, Tiwi',
                        ),
                      ),
                      if (isDelivery) ...[
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
                                    setDialogState(() {
                                      final current = addressController.text
                                          .trim();
                                      if (!current.contains(mun)) {
                                        addressController.text = current.isEmpty
                                            ? '$mun, Albay'
                                            : '$current, $mun, Albay';
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // 3. DRIVER ASSIGNMENT (Only shown for Home Delivery)
                      if (isDelivery) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.delivery_dining_rounded,
                                    color: Color(0xFF8B5CF6),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'ASSIGN DELIVERY DRIVER',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (driversList.isEmpty)
                                const Text(
                                  'No registered drivers found. The order will be created as Confirmed (Open for dispatch).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7C3AED),
                                  ),
                                )
                              else
                                DropdownButtonFormField<UserModel?>(
                                  isExpanded: true,
                                  initialValue: selectedDriver,
                                  dropdownColor: isDark
                                      ? AppTheme.darkSurface
                                      : Colors.white,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Driver to Dispatch',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: [
                                    const DropdownMenuItem<UserModel?>(
                                      value: null,
                                      child: Text(
                                        'Leave Unassigned (Open for Drivers to Accept)',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    ...driversList.map((d) {
                                      return DropdownMenuItem<UserModel?>(
                                        value: d,
                                        child: Text(
                                          '🛵 ${d.name} (${d.email})',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setDialogState(() {
                                      selectedDriver = val;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF059669),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isBorrowingContainers
                                      ? 'Walk-in Bulk Borrow: Station containers will be borrowed by this registered customer.'
                                      : 'Walk-in Refill: Customer brings own containers. Station container inventory will NOT be deducted.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isRegistered) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isBorrowingContainers
                                    ? AppTheme.primaryColor
                                    : (isDark
                                          ? Colors.white12
                                          : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Borrow Station Containers (Bulk Order)',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Enable if registered customer borrows station gallons',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: isBorrowingContainers,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          isBorrowingContainers = val;
                                          if (val) {
                                            final currentQty =
                                                int.tryParse(
                                                  qtyController.text,
                                                ) ??
                                                1;
                                            slimBorrowController.text =
                                                currentQty.toString();
                                            roundBorrowController.text = '0';
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                if (isBorrowingContainers) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: slimBorrowController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Slim Gallons Borrowed',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: roundBorrowController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Round Gallons Borrowed',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 6),
                      ],

                      // 4. ORDER & PRODUCT DETAILS
                      Text(
                        'PRODUCTS & PAYMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isMobile) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedWaterType,
                          dropdownColor: isDark
                              ? AppTheme.darkSurface
                              : Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Water Product',
                          ),
                          items: orderProvider.waterProducts.map((prod) {
                            final name = prod['name'] as String;
                            final price = prod['price'] as double;
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(
                                '$name (₱${price.toStringAsFixed(0)})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedWaterType = val;
                                final match = orderProvider.waterProducts
                                    .firstWhere((p) => p['name'] == val);
                                pricePerUnit = match['price'] as double;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: Icon(Icons.water_drop_rounded),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedWaterType,
                                dropdownColor: isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white,
                                decoration: const InputDecoration(
                                  labelText: 'Water Product',
                                ),
                                items: orderProvider.waterProducts.map((prod) {
                                  final name = prod['name'] as String;
                                  final price = prod['price'] as double;
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(
                                      '$name (₱${price.toStringAsFixed(0)})',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedWaterType = val;
                                      final match = orderProvider.waterProducts
                                          .firstWhere((p) => p['name'] == val);
                                      pricePerUnit = match['price'] as double;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: qtyController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setDialogState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  prefixIcon: Icon(Icons.water_drop_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedPaymentMethod,
                          dropdownColor: isDark
                              ? AppTheme.darkSurface
                              : Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'Cash',
                              child: Text(
                                'Cash',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const DropdownMenuItem(
                              value: 'GCash',
                              child: Text(
                                'GCash',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (isDelivery)
                              const DropdownMenuItem(
                                value: 'Cash on Delivery',
                                child: Text(
                                  'Cash on Delivery (COD)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedPaymentMethod = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedPaymentStatus,
                          dropdownColor: isDark
                              ? AppTheme.darkSurface
                              : Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Payment Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Pending',
                              child: Text(
                                'Pending',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Paid',
                              child: Text(
                                'Paid',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedPaymentStatus = val;
                              });
                            }
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedPaymentMethod,
                                dropdownColor: isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Method',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'Cash',
                                    child: Text(
                                      'Cash',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'GCash',
                                    child: Text(
                                      'GCash',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (isDelivery)
                                    const DropdownMenuItem(
                                      value: 'Cash on Delivery',
                                      child: Text(
                                        'Cash on Delivery (COD)',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedPaymentMethod = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedPaymentStatus,
                                dropdownColor: isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Status',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Pending',
                                    child: Text(
                                      'Pending',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Paid',
                                    child: Text(
                                      'Paid',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedPaymentStatus = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final qty = int.tryParse(qtyController.text) ?? 1;
                          final total = qty * pricePerUnit;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Order Amount:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '₱${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();
                        String address = addressController.text.trim();
                        final qty = int.tryParse(qtyController.text) ?? 1;

                        if (name.isEmpty) {
                          Helpers.showSnackBar(
                            context,
                            'Please enter customer name.',
                            isError: true,
                          );
                          return;
                        }
                        if (isDelivery && address.isEmpty) {
                          Helpers.showSnackBar(
                            context,
                            'Please enter delivery address for home delivery.',
                            isError: true,
                          );
                          return;
                        }
                        if (!isDelivery && address.isEmpty) {
                          address =
                              'Store Pickup / Walk-in (JJAASS Water Station)';
                        }

                        final orderProvider = Provider.of<OrderProvider>(
                          context,
                          listen: false,
                        );
                        final custId = isRegistered && selectedCustomer != null
                            ? selectedCustomer!.id
                            : 'usr_walkin_guest';

                        // Determine order status & driver assignment based on user request:
                        // If Delivery: Confirm & Assign driver if selected (OrderStatus.assigned), or Confirmed
                        // If Pickup: Confirmed, and NO rider assigned
                        final OrderStatus orderStatus = isDelivery
                            ? (selectedDriver != null
                                  ? OrderStatus.assigned
                                  : OrderStatus.confirmed)
                            : OrderStatus.confirmed;

                        final String? driverId = isDelivery
                            ? selectedDriver?.id
                            : null;
                        final String? driverName = isDelivery
                            ? selectedDriver?.name
                            : 'Not Needed (Walk-in/Pickup)';

                        try {
                          final int borrowedSlim = isBorrowingContainers
                              ? (int.tryParse(slimBorrowController.text) ?? 0)
                              : 0;
                          final int borrowedRound = isBorrowingContainers
                              ? (int.tryParse(roundBorrowController.text) ?? 0)
                              : 0;
                          final newOrder = await orderProvider.placeOrder(
                            customerId: custId,
                            customerName: name,
                            customerPhone: phone.isNotEmpty
                                ? phone
                                : '+63 Guest',
                            deliveryAddress: address,
                            waterType: selectedWaterType,
                            quantity: qty,
                            pricePerUnit: pricePerUnit,
                            paymentMethod: selectedPaymentMethod,
                            paymentStatus: selectedPaymentStatus,
                            orderStatus: orderStatus,
                            driverId: driverId,
                            driverName: driverName,
                            isWalkIn: !isDelivery,
                            isBorrowingContainers: isBorrowingContainers,
                            borrowedSlimQty: borrowedSlim,
                            borrowedRoundQty: borrowedRound,
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            final String successMsg = isDelivery
                                ? (selectedDriver != null
                                      ? 'Order ${newOrder.id} created & assigned to ${selectedDriver!.name}!'
                                      : 'Order ${newOrder.id} created for delivery (confirmed)!')
                                : 'Store pickup order ${newOrder.id} created successfully!';
                            Helpers.showSnackBar(context, successMsg);

                            if (selectedPaymentMethod == 'GCash' &&
                                selectedPaymentStatus == 'Pending') {
                              _showGcashPaymentDialog(newOrder, isDark);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Helpers.showSnackBar(
                              context,
                              'Failed to create order: $e',
                              isError: true,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Confirm & Create Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
