/// Mirrors `PostType` in apps/backend/src/database/entities/post.entity.ts.
/// A `news`-typed post can still carry an `imageUrl` — `type` is a
/// primary-categorization label for client-side tab filtering, not a strict
/// exclusivity rule (see the entity's doc comment).
enum PublicPostType {
  news('news', 'News'),
  photo('photo', 'Photos'),
  video('video', 'Videos');

  const PublicPostType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PublicPostType fromApi(String value) => PublicPostType.values.firstWhere(
        (t) => t.apiValue == value,
        orElse: () => PublicPostType.news,
      );
}

/// Mirrors the explicit projection returned by
/// `GET public/organizations/:organizationId/posts`
/// (apps/backend/src/modules/public/public-posts.controller.ts) — published
/// posts only (drafts and future-scheduled posts are excluded at the query
/// level server-side, per `PostsService.findPublished`). Omits
/// `createdByUserId` (internal admin reference) and `organizationId`
/// (redundant with the URL), unlike a raw `Post` entity dump would.
class PublicPost {
  const PublicPost({
    required this.id,
    this.tournamentId,
    required this.title,
    required this.body,
    this.imageUrl,
    this.videoUrl,
    required this.type,
    this.publishedAt,
    required this.createdAt,
  });

  factory PublicPost.fromJson(Map<String, dynamic> json) => PublicPost(
        id: json['id'] as String,
        tournamentId: json['tournamentId'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        imageUrl: json['imageUrl'] as String?,
        videoUrl: json['videoUrl'] as String?,
        type: PublicPostType.fromApi(json['type'] as String? ?? 'news'),
        publishedAt:
            json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String? tournamentId;
  final String title;
  final String body;
  final String? imageUrl;

  /// Always an external link (YouTube, etc.) when present — this module
  /// never hosts video files itself.
  final String? videoUrl;
  final PublicPostType type;
  final DateTime? publishedAt;
  final DateTime createdAt;
}
