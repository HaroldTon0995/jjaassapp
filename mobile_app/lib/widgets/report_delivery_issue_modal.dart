import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helpers.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/delivery_issue_service.dart';

class ReportDeliveryIssueModal extends StatefulWidget {
  final OrderModel order;

  const ReportDeliveryIssueModal({super.key, required this.order});

  static void show(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReportDeliveryIssueModal(order: order),
    );
  }

  @override
  State<ReportDeliveryIssueModal> createState() =>
      _ReportDeliveryIssueModalState();
}

class _ReportDeliveryIssueModalState extends State<ReportDeliveryIssueModal> {
  final TextEditingController _descController = TextEditingController();
  String _selectedIssueType = 'Seal Torn / Damaged';
  int _affectedCount = 1;
  String? _photoUrl;
  bool _isSubmitting = false;

  final List<String> _issueTypes = [
    'Seal Torn / Damaged',
    'Water Quality / Not Clean',
    'Container Leaking',
    'Wrong Product / Cap Broken',
    'Other Issue',
  ];

  @override
  void initState() {
    super.initState();
    _affectedCount = widget.order.quantity > 0 ? 1 : 1;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please describe the issue with the delivered gallon(s).',
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
      issueType: _selectedIssueType,
      affectedGallonsCount: _affectedCount,
      photoUrl: _photoUrl,
      description: desc,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    Helpers.showSnackBar(
      context,
      'Issue claim for $_affectedCount gallon(s) submitted! Station Admin will review for your next swap delivery.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxGallons =
        widget.order.quantity > 0 ? widget.order.quantity : 10;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 28,
        vertical: 24,
      ),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.report_problem_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Delivery Issue & Claim Swap',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Order ${widget.order.id} • ${widget.order.itemsSummary}',
                          style: const TextStyle(
                            color: Color(0xFFFEE2E2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Issue Category
                    const Text(
                      'What is the issue with this delivery?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _issueTypes.map((type) {
                        final isSel = _selectedIssueType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSel,
                          selectedColor: const Color(0xFFDC2626),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedIssueType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 2. Affected Gallon Count Stepper
                    const Text(
                      'How many gallon(s) have this issue?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 18),
                                onPressed: _affectedCount > 1
                                    ? () => setState(() => _affectedCount--)
                                    : null,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '$_affectedCount',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navyColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                onPressed: _affectedCount < maxGallons
                                    ? () => setState(() => _affectedCount++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'out of $maxGallons gallon(s) delivered',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 3. Photo Evidence Section
                    Row(
                      children: const [
                        Icon(Icons.photo_camera_rounded,
                            size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 6),
                        Text(
                          'Photo Evidence of Defect',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Attach a clear photo of the damaged seal, cloudy water, or leaking valve to accelerate admin approval.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),

                    if (_photoUrl != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: Colors.green, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Photo Evidence Attached: $_photoUrl',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent, size: 18),
                              onPressed: () =>
                                  setState(() => _photoUrl = null),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _photoUrl =
                                    'evidence_broken_seal_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              });
                            },
                            icon: const Icon(Icons.add_a_photo_rounded,
                                size: 14),
                            label: const Text('Torn Seal Evidence Photo',
                                style: TextStyle(fontSize: 11)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _photoUrl =
                                    'evidence_water_quality_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              });
                            },
                            icon: const Icon(Icons.water_drop_rounded,
                                size: 14),
                            label: const Text('Water Quality Photo',
                                style: TextStyle(fontSize: 11)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _photoUrl =
                                    'evidence_container_leak_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              });
                            },
                            icon: const Icon(Icons.upload_file_rounded,
                                size: 14),
                            label: const Text('Container Leak Photo',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),

                    // 4. Description Note
                    const Text(
                      'Detailed Description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. 1 Slim gallon had a broken blue shrink seal upon opening; water has odd particles...',
                        hintStyle: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : 'Submit Claim for $_affectedCount Gallon${_affectedCount > 1 ? "s" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
