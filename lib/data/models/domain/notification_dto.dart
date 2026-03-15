import 'notification_type.dart';

/// Notification data transfer object from the backend
class NotificationDto {
  final String id;
  final String recipientId;
  final String? actorId;
  final NotificationType type;
  final String? referenceId;
  final String message;
  final bool read;
  final DateTime createdAt;

  NotificationDto({
    required this.id,
    required this.recipientId,
    this.actorId,
    required this.type,
    this.referenceId,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      actorId: json['actorId'] as String?,
      type: NotificationType.fromJson(json['type'] as String? ?? ''),
      referenceId: json['referenceId'] as String?,
      message: json['message'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientId': recipientId,
        if (actorId != null) 'actorId': actorId,
        'type': type.toJson(),
        if (referenceId != null) 'referenceId': referenceId,
        'message': message,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
      };
}
