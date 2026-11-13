part of 'admin_dashboard.dart';

extension _AdminReports on _AdminDashboardState {
  // TAB 6: ANALYTICS & REPORTS (Realtime Income and Sales reports)
  Widget _buildReportsTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    // 1. Filter orders matching report criteria (excluding Gallon Collection jobs)
    final reportOrders = allOrders.where((o) {
      if (o.isCollectionJob ||
          o.waterType.toLowerCase().contains('gallon collection')) {
        return false;
      }
      // Only count completed or paid orders as income
      if (o.orderStatus != OrderStatus.completed && o.paymentStatus != 'Paid') {
        return false;
      }

      final date = o.createdAt;
      switch (_reportInterval) {
        case 'Daily':
          return date.year == _selectedReportDate.year &&
              date.month == _selectedReportDate.month &&
              date.day == _selectedReportDate.day;
        case 'Weekly':
          // Start of selected date's week (assuming Sunday is start of week)
          final startOfWeek = DateTime(
            _selectedReportDate.year,
            _selectedReportDate.month,
            _selectedReportDate.day,
          ).subtract(Duration(days: _selectedReportDate.weekday % 7));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          return date.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              date.isBefore(endOfWeek);
        case 'Monthly':
          return date.year == _selectedReportDate.year &&
              date.month == _selectedReportDate.month;
        case 'Annually':
          return date.year == _selectedReportDate.year;
        default:
          return false;
      }
    }).toList();

    // 2. Calculations
    double totalRevenue = 0;
    int purifiedJugQty = 0;
    int setProductQty = 0;
    for (var o in reportOrders) {
      totalRevenue += o.totalAmount;
      if (o.waterType.toLowerCase().contains('set a') ||
          o.waterType.toLowerCase().contains('new container')) {
        setProductQty += o.quantity;
      } else {
        purifiedJugQty += o.quantity;
      }
    }
    double averageOrderValue = reportOrders.isEmpty
        ? 0
        : totalRevenue / reportOrders.length;
    String popularType = (purifiedJugQty >= setProductQty)
        ? 'Purified Water'
        : '19L + Container';

    // 3. Group income for Chart Visualizer
    final List<Map<String, dynamic>> chartData = [];
    if (_reportInterval == 'Daily') {
      // Group by 6-hour slots
      final slots = [
        {
          'label': '12AM - 6AM',
          'hours': [0, 1, 2, 3, 4, 5],
          'amount': 0.0,
        },
        {
          'label': '6AM - 12PM',
          'hours': [6, 7, 8, 9, 10, 11],
          'amount': 0.0,
        },
        {
          'label': '12PM - 6PM',
          'hours': [12, 13, 14, 15, 16, 17],
          'amount': 0.0,
        },
        {
          'label': '6PM - 12AM',
          'hours': [18, 19, 20, 21, 22, 23],
          'amount': 0.0,
        },
      ];
      for (var o in reportOrders) {
        final hr = o.createdAt.hour;
        for (var slot in slots) {
          if ((slot['hours'] as List<int>).contains(hr)) {
            slot['amount'] = (slot['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(slots);
    } else if (_reportInterval == 'Weekly') {
      // Group by Day of the Week
      final days = [
        {'label': 'Sun', 'weekday': 7, 'amount': 0.0},
        {'label': 'Mon', 'weekday': 1, 'amount': 0.0},
        {'label': 'Tue', 'weekday': 2, 'amount': 0.0},
        {'label': 'Wed', 'weekday': 3, 'amount': 0.0},
        {'label': 'Thu', 'weekday': 4, 'amount': 0.0},
        {'label': 'Fri', 'weekday': 5, 'amount': 0.0},
        {'label': 'Sat', 'weekday': 6, 'amount': 0.0},
      ];
      for (var o in reportOrders) {
        final wd = o.createdAt.weekday;
        for (var day in days) {
          if (day['weekday'] == wd) {
            day['amount'] = (day['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(days);
    } else if (_reportInterval == 'Monthly') {
      // Group by Weeks of Month
      final weeks = [
        {
          'label': 'Week 1',
          'range': [1, 2, 3, 4, 5, 6, 7],
          'amount': 0.0,
        },
        {
          'label': 'Week 2',
          'range': [8, 9, 10, 11, 12, 13, 14],
          'amount': 0.0,
        },
        {
          'label': 'Week 3',
          'range': [15, 16, 17, 18, 19, 20, 21],
          'amount': 0.0,
        },
        {
          'label': 'Week 4',
          'range': [22, 23, 24, 25, 26, 27, 28],
          'amount': 0.0,
        },
        {
          'label': 'Week 5',
          'range': [29, 30, 31],
          'amount': 0.0,
        },
      ];
      for (var o in reportOrders) {
        final d = o.createdAt.day;
        for (var week in weeks) {
          if ((week['range'] as List<int>).contains(d)) {
            week['amount'] = (week['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(weeks);
    } else {
      // Group by Quarter of the Year
      final quarters = [
        {
          'label': 'Q1 (Jan-Mar)',
          'months': [1, 2, 3],
          'amount': 0.0,
        },
        {
          'label': 'Q2 (Apr-Jun)',
          'months': [4, 5, 6],
          'amount': 0.0,
        },
        {
          'label': 'Q3 (Jul-Sep)',
          'months': [7, 8, 9],
          'amount': 0.0,
        },
        {
          'label': 'Q4 (Oct-Dec)',
          'months': [10, 11, 12],
          'amount': 0.0,
        },
      ];
      for (var o in reportOrders) {
        final m = o.createdAt.month;
        for (var q in quarters) {
          if ((q['months'] as List<int>).contains(m)) {
            q['amount'] = (q['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(quarters);
    }

    // Maximum value in chart for percentage calculation
    double maxVal = 0.0;
    for (var data in chartData) {
      if ((data['amount'] as double) > maxVal) {
        maxVal = data['amount'] as double;
      }
    }
    if (maxVal == 0.0) maxVal = 100.0; // avoid divide by zero

    String reportFormattedDate = '';
    if (_reportInterval == 'Daily') {
      reportFormattedDate =
          '${_selectedReportDate.month}/${_selectedReportDate.day}/${_selectedReportDate.year}';
    } else if (_reportInterval == 'Weekly') {
      final start = _selectedReportDate.subtract(
        Duration(days: _selectedReportDate.weekday % 7),
      );
      final end = start.add(const Duration(days: 6));
      reportFormattedDate =
          'Week of ${start.month}/${start.day} to ${end.month}/${end.day}';
    } else if (_reportInterval == 'Monthly') {
      final months = [
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
      reportFormattedDate =
          '${months[_selectedReportDate.month - 1]} ${_selectedReportDate.year}';
    } else {
      reportFormattedDate = 'Year ${_selectedReportDate.year}';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final int metricCrossCount = screenWidth < 550
        ? 1
        : (screenWidth < 900 ? 2 : 4);
    final double metricAspectRatio = screenWidth < 550
        ? 3.8
        : (screenWidth < 900 ? 3.0 : 2.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Date Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Realtime Financial Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Viewing income generated for $reportFormattedDate',
                      style: TextStyle(
                        color: const Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedReportDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedReportDate = date;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: const Text('Change Date'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Interval Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['Daily', 'Weekly', 'Monthly', 'Annually'].map((
                interval,
              ) {
                final isSel = _reportInterval == interval;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _reportInterval = interval),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          interval == 'Annually' ? 'Annually' : interval,
                          style: TextStyle(
                            color: isSel
                                ? Colors.white
                                : (isDark
                                      ? const Color(0xFF64748B)
                                      : Colors.grey.shade700),
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Summary Metrics Cards Grid
          GridView.count(
            crossAxisCount: metricCrossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: metricAspectRatio,
            children: [
              _buildReportMetricCard(
                'Total Revenue',
                '₱${totalRevenue.toStringAsFixed(2)}',
                Icons.payments_rounded,
                Colors.green,
                isDark,
              ),
              _buildReportMetricCard(
                'Completed Orders',
                '${reportOrders.length}',
                Icons.check_circle_rounded,
                Colors.blue,
                isDark,
              ),
              _buildReportMetricCard(
                'Average Order Value',
                '₱${averageOrderValue.toStringAsFixed(2)}',
                Icons.calculate_rounded,
                Colors.orange,
                isDark,
              ),
              _buildReportMetricCard(
                'Popular Water',
                popularType,
                Icons.local_drink_rounded,
                Colors.cyan,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Visual Chart Cards
          Card(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Income Distribution & Breakdown',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...chartData.map((data) {
                    final amount = data['amount'] as double;
                    final pct = amount / maxVal;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              data['label'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 14,
                                backgroundColor: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₱${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Transactions Breakdown List
          Card(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contributing Orders ($reportFormattedDate)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  reportOrders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No transactions recorded for this period.',
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 420,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: Builder(
                              builder: (context) {
                                final Map<String, List<OrderModel>>
                                reportDivisions = {};
                                for (var o in reportOrders) {
                                  final key = _resolveCustomerDisplayName(o);
                                  reportDivisions
                                      .putIfAbsent(key, () => [])
                                      .add(o);
                                }

                                return ListView(
                                  children: [
                                    for (var entry
                                        in reportDivisions.entries) ...[
                                      Container(
                                        margin: const EdgeInsets.only(
                                          top: 8,
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.person_pin_circle_rounded,
                                              size: 16,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Customer Division: ${entry.key}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${entry.value.length} Order${entry.value.length > 1 ? "s" : ""}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                color: AppTheme.navyColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      for (var o in entry.value) ...[
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                          leading: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppTheme
                                                .primaryColor
                                                .withValues(alpha: 0.08),
                                            child: const Icon(
                                              Icons.receipt_long_rounded,
                                              color: AppTheme.primaryColor,
                                              size: 16,
                                            ),
                                          ),
                                          title: Text(
                                            '${o.id} • ${_resolveCustomerDisplayName(o)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${o.itemsSummary} • ${o.paymentMethod}\nPlaced at: ${o.createdAt.toString().split('.')[0]}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          trailing: Text(
                                            o.formattedTotal,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        const Divider(height: 1),
                                      ],
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Export & Print Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () async {
                          if (reportOrders.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'No orders available to export.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() => _isActionLoading = true);
                          try {
                            await ReportService.exportCSV(
                              orders: reportOrders,
                              interval: _reportInterval,
                              formattedDate: reportFormattedDate,
                            );
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'CSV report export triggered successfully!',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Failed to export CSV: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isActionLoading = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.file_download_rounded, size: 16),
                  label: const Text(
                    'Export CSV',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () async {
                          if (reportOrders.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'No orders available to print.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() => _isActionLoading = true);
                          try {
                            await ReportService.printPDF(
                              orders: reportOrders,
                              interval: _reportInterval,
                              formattedDate: reportFormattedDate,
                            );
                          } catch (e) {
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Failed to print report: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isActionLoading = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text(
                    'Print Report',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () async {
                          if (reportOrders.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'No orders available to download.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() => _isActionLoading = true);
                          try {
                            await ReportService.downloadPDF(
                              orders: reportOrders,
                              interval: _reportInterval,
                              formattedDate: reportFormattedDate,
                            );
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'PDF report download triggered successfully!',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Failed to download PDF: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isActionLoading = false);
                            }
                          }
                        },
                  icon: const Icon(
                    Icons.download_for_offline_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Download PDF',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
        ],
      ),
    );
  }
}
