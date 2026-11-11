class ChatMessageModel {
  final String id;
  final String conversationId;
  final String? orderId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'customer', 'driver', 'admin'
  final String? receiverId;
  final String? receiverName;
  final String? receiverRole;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    this.orderId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.receiverId,
    this.receiverName,
    this.receiverRole,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'order_id': orderId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'receiver_id': receiverId,
        'receiver_name': receiverName,
        'receiver_role': receiverRole,
        'message': message,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        id: json['id']?.toString() ??
            'msg_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: json['conversation_id']?.toString() ??
            json['conversationId']?.toString() ??
            'general',
        orderId: json['order_id']?.toString() ?? json['orderId']?.toString(),
        senderId: json['sender_id']?.toString() ??
            json['senderId']?.toString() ??
            '',
        senderName: json['sender_name']?.toString() ??
            json['senderName']?.toString() ??
            'User',
        senderRole: json['sender_role']?.toString() ??
            json['senderRole']?.toString() ??
            'customer',
        receiverId:
            json['receiver_id']?.toString() ?? json['receiverId']?.toString(),
        receiverName: json['receiver_name']?.toString() ??
            json['receiverName']?.toString(),
        receiverRole: json['receiver_role']?.toString() ??
            json['receiverRole']?.toString(),
        message: json['message']?.toString() ?? '',
        isRead: json['is_read'] == true || json['isRead'] == true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString()) ??
                    DateTime.now()
                : DateTime.now()),
      );
}
