part of 'admin_dashboard.dart';

extension _AdminClaims on _AdminDashboardState {
  // Defect Claims & Swap Authorizations Tab
  Widget _buildDeliveryIssueClaimsTab(bool isDark) {
    return ListenableBuilder(
      listenable: DeliveryIssueService.instance,
      builder: (context, _) {
        final allIssues = DeliveryIssueService.instance.issues;
        final pendingCount = DeliveryIssueService.instance.pendingCount;

        // Auto-complete claims whose order transaction is finished
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        for (var i in allIssues) {
          if (!i.isDone && (i.isApproved || i.isDeclined)) {
            final o = orderProvider.orders.cast<OrderModel?>().firstWhere(
              (ord) =>
                  ord?.id == i.orderId ||
                  '#${ord?.id}' == i.orderId ||
                  ord?.id == i.orderId.replaceAll('#', ''),
              orElse: () => null,
            );
            if (o != null &&
                (o.orderStatus == OrderStatus.completed ||
                    o.orderStatus == OrderStatus.cancelled)) {
              DeliveryIssueService.instance.completeTransaction(i.id);
            }
          }
        }

        // Filter by category chip
        final filteredByStatus =
            (_claimFilter == 'All' || _claimFilter == 'Active')
            ? allIssues.where((i) => !i.isDone).toList()
            : allIssues.where((i) {
                if (_claimFilter == 'Pending') {
                  return i.isPending && !i.isDone;
                }
                if (_claimFilter == 'Approved') {
                  return i.isApproved && !i.isDone;
                }
                if (_claimFilter == 'Declined') {
                  return i.isDeclined;
                }
                if (_claimFilter == 'Done & History') {
                  return i.isDone || i.isDeclined;
                }
                return !i.isDone;
              }).toList();

        // Filter by search query
        final query = _claimSearchController.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? filteredByStatus
            : filteredByStatus.where((i) {
                return i.id.toLowerCase().contains(query) ||
                    i.orderId.toLowerCase().contains(query) ||
                    i.customerName.toLowerCase().contains(query) ||
                    i.customerPhone.toLowerCase().contains(query) ||
                    i.issueType.toLowerCase().contains(query);
              }).toList();

        final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Title and Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Defect & Replacement Claims',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review customer complaints, verify photo evidence, and authorize free replacement swaps on next delivery.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Quick Summary Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: pendingCount > 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF6EE7B7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pendingCount > 0
                            ? Icons.warning_amber_rounded
                            : Icons.verified_rounded,
                        size: 16,
                        color: pendingCount > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pendingCount > 0
                            ? '$pendingCount Claims Awaiting Decision'
                            : 'All Claims Resolved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: pendingCount > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Chips
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _claimSearchController,
                      onChanged: (_) => setState(() {}),
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText:
                            'Search by Claim ID, Order ID, Customer name or issue...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        suffixIcon: _claimSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _claimSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter Chips: Active (Default), Pending, Approved, Done & History
                ...['Active', 'Pending', 'Approved', 'Done & History'].map((
                  filter,
                ) {
                  final isSelected =
                      (_claimFilter == filter) ||
                      (_claimFilter == 'All' && filter == 'Active');
                  int count = 0;
                  if (filter == 'Active') {
                    count = allIssues.where((i) => !i.isDone).length;
                  }
                  if (filter == 'Pending') {
                    count = allIssues
                        .where((i) => i.isPending && !i.isDone)
                        .length;
                  }
                  if (filter == 'Approved') {
                    count = allIssues
                        .where((i) => i.isApproved && !i.isDone)
                        .length;
                  }
                  if (filter == 'Done & History') {
                    count = allIssues
                        .where((i) => i.isDone || i.isDeclined)
                        .length;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text('$filter ($count)'),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? Colors.grey.shade300
                                  : const Color(0xFF334155)),
                      ),
                      backgroundColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      selectedColor: filter == 'Pending'
                          ? const Color(0xFFF59E0B)
                          : (filter == 'Approved'
                                ? const Color(0xFF10B981)
                                : (filter == 'Done & History'
                                      ? const Color(0xFF64748B)
                                      : AppTheme.primaryColor)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : borderColor,
                        ),
                      ),
                      onSelected: (_) => setState(() => _claimFilter = filter),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Claims Content List
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 52,
                      color: Colors.green.shade500,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _claimFilter == 'Done & History'
                          ? 'No Completed Claims in History'
                          : 'All Defect Claims & Swap Transactions Resolved',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _claimFilter == 'Done & History'
                          ? 'Past resolved customer claims will appear here for audit history.'
                          : 'There are no active claims awaiting action. When claims are accepted or rejected and the transaction is done, they are cleared from the active queue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, idx) {
                  final claim = filtered[idx];
                  return _buildDeliveryIssueClaimCard(
                    context,
                    claim,
                    isDark,
                    cardBgColor,
                    borderColor,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryIssueClaimCard(
    BuildContext context,
    DeliveryIssueModel claim,
    bool isDark,
    Color cardBgColor,
    Color borderColor,
  ) {
    final isDone = claim.isDone;
    final isApproved = claim.isApproved && !isDone;
    final isDeclined = claim.isDeclined;
    final isPending = claim.isPending && !isDone;

    final Color statusColor = isDone
        ? const Color(0xFF64748B)
        : (isApproved
              ? const Color(0xFF059669)
              : (isDeclined
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD97706)));
    final Color statusBg = isDone
        ? const Color(0xFFF1F5F9)
        : (isApproved
              ? const Color(0xFFECFDF5)
              : (isDeclined
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFFEF3C7)));

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final relatedOrder = orderProvider.orders.cast<OrderModel?>().firstWhere(
      (o) =>
          o?.id == claim.orderId ||
          '#${o?.id}' == claim.orderId ||
          '##${o?.id}' == claim.orderId ||
          o?.id == claim.orderId.replaceAll('#', ''),
      orElse: () => null,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? const Color(0xFFFCD34D) : borderColor,
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header (Claim ID, Order ID, Status, Timestamp)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Claim #${claim.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Order #${claim.orderId}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_outline_rounded
                          : (isApproved
                                ? Icons.check_circle_rounded
                                : (isDeclined
                                      ? Icons.cancel_rounded
                                      : Icons.hourglass_top_rounded)),
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDone
                          ? (isDeclined
                                ? 'Declined & Closed'
                                : 'Transaction Completed (Done)')
                          : (isApproved
                                ? 'Swap Approved (${claim.affectedGallons} Gallons)'
                                : (isDeclined
                                      ? 'Claim Declined'
                                      : 'Pending Review')),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                claim.createdAtFormatted,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Customer & Issue Info + Photo Evidence Thumbnail
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Customer details & Issue Breakdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE0E7FF),
                          child: Text(
                            claim.customerName.isNotEmpty
                                ? claim.customerName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3730A3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          claim.customerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        if (claim.customerPhone.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${claim.customerPhone}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (relatedOrder?.deliveryAddress != null &&
                        relatedOrder!.deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              relatedOrder.deliveryAddress,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Issue Category and Gallon Quantity Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 13,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                claim.issueType,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                size: 13,
                                color: Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${claim.affectedGallons} Gallon(s) Affected',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (claim.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '"${claim.description}"',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? Colors.grey.shade300
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],

                    if (claim.adminNotes != null &&
                        claim.adminNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isApproved
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isApproved
                                  ? Icons.verified_user_rounded
                                  : Icons.info_outline_rounded,
                              size: 14,
                              color: isApproved
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Resolution Note: ${claim.adminNotes}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isApproved
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right Column: Photo Evidence Thumbnail (Click to zoom/inspect)
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Photo Evidence',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildEvidenceThumbnail(
                      claim.photoUrl ?? claim.photoBase64,
                      context,
                      claim,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 3: Action Buttons (Accept Swap vs Decline, or Complete Transaction)
          if (isPending) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDeclineClaimDialog(context, claim),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Decline Claim',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF87171)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    await DeliveryIssueService.instance.acceptIssue(claim.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✓ Claim #${claim.id} Approved! Customer ${claim.customerName} will receive ${claim.affectedGallons} replacement gallon(s).',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Accept & Issue Swap (${claim.affectedGallons} Gallons)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (claim.isApproved && !claim.isDone) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await DeliveryIssueService.instance.completeTransaction(
                      claim.id,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✓ Transaction for Claim #${claim.id} completed. Removed from active queue.',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Complete Transaction & Dismiss',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (claim.isDone) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: isDark
                        ? Colors.grey.shade400
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Transaction Completed & Closed',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceThumbnail(
    String? photoUrl,
    BuildContext context,
    DeliveryIssueModel issue,
  ) {
    final effectivePhoto = (photoUrl != null && photoUrl.trim().isNotEmpty)
        ? photoUrl
        : issue.photoBase64;
    final hasPhoto = effectivePhoto != null && effectivePhoto.trim().isNotEmpty;

    return InkWell(
      onTap: () => _showInspectEvidenceDialog(context, issue),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasPhoto)
              _renderPhotoWidget(effectivePhoto)
            else
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 28,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No Photo',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            // Zoom Overlay Icon
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderPhotoWidget(String photoUrl) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        final base64Str = commaIdx != -1
            ? photoUrl.substring(commaIdx + 1)
            : photoUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image_rounded, color: Colors.grey),
        );
      } catch (_) {
        return const Icon(Icons.broken_image_rounded, color: Colors.grey);
      }
    } else if (photoUrl.startsWith('http://') ||
        photoUrl.startsWith('https://')) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_rounded, color: Colors.grey),
      );
    } else {
      // Mock / fallback preview
      return Container(
        color: const Color(0xFFE0F2FE),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_rounded, size: 28, color: Color(0xFF0284C7)),
            SizedBox(height: 2),
            Text(
              'Evidence Attached',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0369A1),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showInspectEvidenceDialog(
    BuildContext context,
    DeliveryIssueModel issue,
  ) {
    final photo = issue.photoUrl ?? issue.photoBase64;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          children: [
            const Icon(
              Icons.photo_library_rounded,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Defect Evidence - Claim #${issue.id}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Frame
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: photo != null && photo.isNotEmpty
                    ? _renderPhotoWidget(photo)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_rounded,
                            size: 48,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No photo was uploaded with this claim.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),

              // Claim Meta Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order ID: #${issue.orderId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⚠️ ${issue.affectedGallons} Gallon(s) Affected',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Customer: ${issue.customerName} (${issue.customerPhone})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Issue Type: ${issue.issueType}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (issue.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Customer Note: "${issue.description}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (issue.isPending) ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showDeclineClaimDialog(context, issue);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
              ),
              child: const Text(
                'Decline Claim',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await DeliveryIssueService.instance.acceptIssue(issue.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✓ Swap claim approved for ${issue.customerName} (${issue.affectedGallons} Gallons)!',
                      ),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
              child: Text(
                'Accept Swap (${issue.affectedGallons} Gallons)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (issue.isApproved && !issue.isDone) ...[
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await DeliveryIssueService.instance.completeTransaction(
                  issue.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✓ Transaction for Claim #${issue.id} completed. Removed from active queue.',
                      ),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
              child: const Text(
                'Complete Transaction',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeclineClaimDialog(BuildContext context, DeliveryIssueModel issue) {
    final reasonController = TextEditingController();
    final quickReasons = [
      'Defect not visible in photo evidence',
      'Normal container wear (seal unbroken)',
      'Reported after delivery acceptance window',
      'No leak detected on inspection',
      'Wrong order reference',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Text('Decline Claim #${issue.id}'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select or type the reason why this claim is declined. The customer will see this message.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickReasons.map((r) {
                      final isSelected = reasonController.text == r;
                      return ChoiceChip(
                        label: Text(
                          r,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFDC2626),
                        onSelected: (_) {
                          setModalState(() {
                            reasonController.text = r;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter reason for customer...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final reason = reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : 'Claim could not be verified.';
                  Navigator.pop(ctx);
                  await DeliveryIssueService.instance.declineIssue(
                    issue.id,
                    reason,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Claim declined. Customer notified.'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                child: const Text(
                  'Confirm Decline',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
