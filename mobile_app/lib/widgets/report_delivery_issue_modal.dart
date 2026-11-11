import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helpers.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/delivery_issue_service.dart';

class ReportDeliveryIssueModal extends StatefulWidget {
  final OrderModel order;
  final bool isBottomSheet;

  const ReportDeliveryIssueModal({
    super.key,
    required this.order,
    this.isBottomSheet = false,
  });

  static void show(BuildContext context, OrderModel order) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    if (isNarrow) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) =>
            ReportDeliveryIssueModal(order: order, isBottomSheet: true),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) =>
            ReportDeliveryIssueModal(order: order, isBottomSheet: false),
      );
    }
  }

  @override
  State<ReportDeliveryIssueModal> createState() =>
      _ReportDeliveryIssueModalState();
}

class _ReportDeliveryIssueModalState extends State<ReportDeliveryIssueModal> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();

  String _selectedIssueType = 'Seal Damaged';
  int _affectedCount = 1;
  String? _photoUrl;
  bool _isSubmitting = false;

  final List<String> _issueTypes = [
    'Seal Damaged',
    'Murky / Unclean Water',
    'Container Leak',
    'Broken / Missing Cap',
    'Other (Specify)',
  ];

  @override
  void initState() {
    super.initState();
    _affectedCount = 1;
  }

  @override
  void dispose() {
    _descController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    String finalType = _selectedIssueType;
    if (_selectedIssueType == 'Other (Specify)') {
      final custom = _customTypeController.text.trim();
      if (custom.isEmpty) {
        Helpers.showSnackBar(
          context,
          'Please specify the issue type in the field provided.',
          isError: true,
        );
        return;
      }
      finalType = custom;
    }

    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please provide a short description of the problem.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final customerId = user?.id ?? widget.order.customerId;
    final customerName = user?.name ?? widget.order.customerName;
    final customerPhone = auth.currentPhone.isNotEmpty
        ? auth.currentPhone
        : widget.order.customerPhone;

    await DeliveryIssueService.instance.submitIssue(
      orderId: widget.order.id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      issueType: finalType,
      affectedGallonsCount: _affectedCount,
      photoUrl: _photoUrl,
      description: desc,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    Helpers.showSnackBar(
      context,
      'Issue reported for $_affectedCount gallon(s). Station Admin will review for swap replacement.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxGallons =
        widget.order.quantity > 0 ? widget.order.quantity : 10;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final content = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Issue Type Selector
          const Text(
            'Issue Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _issueTypes.map((type) {
              final isSel = _selectedIssueType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSel,
                showCheckmark: false,
                selectedColor: const Color(0xFF0F172A),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSel
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedIssueType = type);
                },
              );
            }).toList(),
          ),

          // Custom Issue Type Input (when "Other" is selected)
          if (_selectedIssueType == 'Other (Specify)') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customTypeController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Specify issue (e.g. Broken valve, algae on handle)',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 2. Affected Quantity Stepper
          const Text(
            'Defective Gallons',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _affectedCount > 1
                      ? () => setState(() => _affectedCount--)
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '$_affectedCount',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _affectedCount < maxGallons
                      ? () => setState(() => _affectedCount++)
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                ),
                const Spacer(),
                Text(
                  'out of $maxGallons delivered',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Photo Evidence
          const Text(
            'Photo Evidence (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          if (_photoUrl != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _photoUrl!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _photoUrl = null),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () {
                setState(() {
                  _photoUrl =
                      'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '+ Attach Defect Photo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // 4. Description Field
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText:
                  'Briefly explain the condition upon delivery (e.g. broken seal, leakage, murky water)...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 20),

          // 5. Submit Button (Full Width, Zero Horizontal Overflow)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Submit Claim ($_affectedCount Gallon${_affectedCount > 1 ? "s" : ""})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    // Bottom Sheet on mobile
    if (widget.isBottomSheet) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Clean Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report a Problem',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Order ${widget.order.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Flexible(child: content),
            ],
          ),
        ),
      );
    }

    // Centered Dialog on desktop / tablet
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report a Problem',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Order ${widget.order.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Flexible(child: content),
          ],
        ),
      ),
    );
  }
}
