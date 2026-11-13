part of 'admin_dashboard.dart';

extension _AdminPayments on _AdminDashboardState {
  // TAB 5: PAYMENTS TRANSACTIONS (Realtime live transaction monitor)
  Widget _buildPaymentsTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    // Financial Metrics
    double totalPaidRevenue = 0.0;
    double totalGcashRevenue = 0.0;
    int gcashPaidCount = 0;
    double totalCodRevenue = 0.0;
    int codPaidCount = 0;
    int pendingCount = 0;

    for (var o in allOrders) {
      if (o.paymentStatus == 'Paid') {
        totalPaidRevenue += o.totalAmount;
        if (o.paymentMethod.toLowerCase().contains('gcash')) {
          totalGcashRevenue += o.totalAmount;
          gcashPaidCount++;
        } else {
          totalCodRevenue += o.totalAmount;
          codPaidCount++;
        }
      } else {
        pendingCount++;
      }
    }

    // Filter & Search logic
    final query = _paymentsSearchController.text.trim().toLowerCase();
    final filtered = allOrders.where((o) {
      final matchesQuery =
          query.isEmpty ||
          o.id.toLowerCase().contains(query) ||
          o.txnId.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query) ||
          o.customerPhone.toLowerCase().contains(query);

      bool matchesFilter = true;
      if (_paymentsFilter == 'GCash') {
        matchesFilter = o.paymentMethod.toLowerCase().contains('gcash');
      } else if (_paymentsFilter == 'Cash on Delivery') {
        matchesFilter = !o.paymentMethod.toLowerCase().contains('gcash');
      } else if (_paymentsFilter == 'Paid') {
        matchesFilter = o.paymentStatus == 'Paid';
      } else if (_paymentsFilter == 'Pending') {
        matchesFilter = o.paymentStatus != 'Paid';
      }

      return matchesQuery && matchesFilter;
    }).toList();

    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Live Indicator & Sync Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Real-Time Payment Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Live Stream Active',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instant synchronization for GCash and Cash transactions across customer & rider apps.',
                    style: TextStyle(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await orderProvider.fetchSupabaseOrders(silent: false);
                  if (!mounted) return;
                  Helpers.showSnackBar(
                    context,
                    'Transactions synced with database.',
                  );
                },
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Refresh Feed'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Stats Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Revenue (Paid)',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${totalPaidRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF007DFE),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GCash Collected',
                            style: TextStyle(fontSize: 11, color: subtextColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${totalGcashRevenue.toStringAsFixed(2)} ($gcashPaidCount)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007DFE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COD Collected',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${totalCodRevenue.toStringAsFixed(2)} ($codPaidCount)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Settlement',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pendingCount orders',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _paymentsSearchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 12, color: titleColor),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search by Txn Ref, Order #, or Customer...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          'All',
                          'GCash',
                          'Cash on Delivery',
                          'Paid',
                          'Pending',
                        ].map((filter) {
                          final isSel = _paymentsFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSel,
                              selectedColor: AppTheme.primaryColor,
                              labelStyle: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (val) {
                                setState(() {
                                  _paymentsFilter = filter;
                                });
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transactions List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No payment transactions match this filter.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (itemCtx, index) {
                      final pay = filtered[index];
                      final isSuccess = pay.paymentStatus == 'Paid';
                      final isGcash = pay.paymentMethod.toLowerCase().contains(
                        'gcash',
                      );
                      final statusColor = isSuccess
                          ? Colors.green
                          : Colors.amber.shade700;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isGcash && isSuccess
                                ? const Color(0xFF007DFE).withValues(alpha: 0.3)
                                : borderColor,
                            width: isGcash && isSuccess ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Method Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isGcash
                                    ? const Color(
                                        0xFF007DFE,
                                      ).withValues(alpha: 0.12)
                                    : Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  isGcash
                                      ? Icons.account_balance_wallet_rounded
                                      : Icons.payments_rounded,
                                  color: isGcash
                                      ? const Color(0xFF007DFE)
                                      : Colors.green,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        pay.txnId,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isGcash
                                              ? const Color(
                                                  0xFF007DFE,
                                                ).withValues(alpha: 0.12)
                                              : Colors.grey.withValues(
                                                  alpha: 0.12,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          pay.paymentMethod,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isGcash
                                                ? const Color(0xFF007DFE)
                                                : subtextColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• Order ${pay.id}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subtextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${pay.customerName} (${pay.customerPhone}) • ${pay.itemsSummary}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: titleColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Placed: ${pay.createdAt.toString().split('.')[0]}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Trailing Amount & Status
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  pay.formattedTotal,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: isGcash
                                        ? const Color(0xFF007DFE)
                                        : titleColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSuccess
                                                ? Icons.check_circle_rounded
                                                : Icons.hourglass_top_rounded,
                                            size: 10,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pay.paymentStatus,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isSuccess) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () async {
                                          await orderProvider.markOrderAsPaid(
                                            pay.id,
                                          );
                                          if (!mounted) return;
                                          Helpers.showSnackBar(
                                            context,
                                            'Order ${pay.id} confirmed as Paid in database.',
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Mark Paid',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
}
