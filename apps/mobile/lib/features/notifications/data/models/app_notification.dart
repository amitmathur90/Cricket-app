/// Mirrors `NotificationType` and `Notification`
/// (apps/backend/src/database/entities/notification.entity.ts).
enum NotificationType {
  matchReminder,
  practiceReminder,
  auctionAnnouncement,
  playerApproval,
  teamSelection,
  matchResult,
  scheduleChange,
  paymentReminder,
  announcement,
}

extension NotificationTypeX on NotificationType {
  String get apiValue => switch (this) {
        NotificationType.matchReminder => 'match_reminder',
        NotificationType.practiceReminder => 'practice_reminder',
        NotificationType.auctionAnnouncement => 'auction_announcement',
        NotificationType.playerApproval => 'player_approval',
        NotificationType.teamSelection => 'team_selection',
        NotificationType.matchResult => 'match_result',
        NotificationType.scheduleChange => 'schedule_change',
        NotificationType.paymentReminder => 'payment_reminder',
        NotificationType.announcement => 'announcement',
      };

  /// Falls back to [NotificationType.announcement] for any value this
  /// client doesn't recognize yet — same defensive-default convention as
  /// e.g. `TournamentFormatX.fromApi`.
  static NotificationType fromApi(String value) => switch (value) {
        'match_reminder' => NotificationType.matchReminder,
        'practice_reminder' => NotificationType.practiceReminder,
        'auction_announcement' => NotificationType.auctionAnnouncement,
        'player_approval' => NotificationType.playerApproval,
        'team_selection' => NotificationType.teamSelection,
        'match_result' => NotificationType.matchResult,
        'schedule_change' => NotificationType.scheduleChange,
        'payment_reminder' => NotificationType.paymentReminder,
        _ => NotificationType.announcement,
      };
}

/// One in-app notification for the signed-in user, as returned by
/// `GET/PATCH .../organizations/:organizationId/notifications*`. Always
/// scoped server-side to the caller — see NotificationsService's doc
/// comment.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.relatedEntityType,
    this.relatedEntityId,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        userId: json['userId'] as String,
        type: NotificationTypeX.fromApi(json['type'] as String),
        title: json['title'] as String,
        message: json['message'] as String,
        relatedEntityType: json['relatedEntityType'] as String?,
        relatedEntityId: json['relatedEntityId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        readAt: json['readAt'] == null ? null : DateTime.tryParse(json['readAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  final String id;
  final String organizationId;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
        id: id,
        organizationId: organizationId,
        userId: userId,
        type: type,
        title: title,
        message: message,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );
}
