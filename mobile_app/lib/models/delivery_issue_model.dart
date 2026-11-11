class DeliveryIssueModel {
  final String id;
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String issueType;
  final int affectedGallonsCount;
  final String? photoUrl;
  final String? photoBase64;
  final String description;
  final String status; // 'pending', 'accepted', 'declined', 'redeemed', 'completed'
  final String? adminFeedback;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool isTransactionDone;

  DeliveryIssueModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.issueType,
    required this.affectedGallonsCount,
    this.photoUrl,
    this.photoBase64,
    required this.description,
    this.status = 'pending',
    this.adminFeedback,
    required this.createdAt,
    this.resolvedAt,
    this.isTransactionDone = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'issue_type': issueType,
        'affected_gallons_count': affectedGallonsCount,
        'photo_url': photoUrl,
        'photo_base64': photoBase64,
        'description': description,
        'status': status,
        'admin_feedback': adminFeedback,
        'created_at': createdAt.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
        'is_transaction_done': isTransactionDone,
      };

  factory DeliveryIssueModel.fromJson(Map<String, dynamic> json) =>
      DeliveryIssueModel(
        id: json['id']?.toString() ?? 'CLM-${DateTime.now().millisecondsSinceEpoch}',
        orderId: json['order_id']?.toString() ?? json['orderId']?.toString() ?? '',
        customerId: json['customer_id']?.toString() ?? json['customerId']?.toString() ?? '',
        customerName: json['customer_name']?.toString() ?? json['customerName']?.toString() ?? 'Customer',
        customerPhone: json['customer_phone']?.toString() ?? json['customerPhone']?.toString() ?? '',
        issueType: json['issue_type']?.toString() ?? json['issueType']?.toString() ?? 'Quality Issue',
        affectedGallonsCount: (json['affected_gallons_count'] ?? json['affectedGallonsCount'] as num?)?.toInt() ?? 1,
        photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString(),
        photoBase64: json['photo_base64']?.toString() ?? json['photoBase64']?.toString(),
        description: json['description']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        adminFeedback: json['admin_feedback']?.toString() ?? json['adminFeedback']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        resolvedAt: json['resolved_at'] != null
            ? DateTime.tryParse(json['resolved_at'].toString())
            : null,
        isTransactionDone: json['is_transaction_done'] == true ||
            json['isTransactionDone'] == true ||
            json['status'] == 'completed' ||
            json['status'] == 'redeemed',
      );

  DeliveryIssueModel copyWith({
    String? status,
    String? adminFeedback,
    DateTime? resolvedAt,
    bool? isTransactionDone,
  }) {
    return DeliveryIssueModel(
      id: id,
      orderId: orderId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      issueType: issueType,
      affectedGallonsCount: affectedGallonsCount,
      photoUrl: photoUrl,
      photoBase64: photoBase64,
      description: description,
      status: status ?? this.status,
      adminFeedback: adminFeedback ?? this.adminFeedback,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isTransactionDone: isTransactionDone ?? this.isTransactionDone,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'accepted';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isRedeemed => status == 'redeemed';
  bool get isCompleted => status == 'completed' || isTransactionDone;
  bool get isDone => isTransactionDone || status == 'completed' || status == 'redeemed';
  int get affectedGallons => affectedGallonsCount;
  String? get adminNotes => adminFeedback;
  String get createdAtFormatted {
    final d = createdAt;
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hour:$minute $ampm';
  }
}
