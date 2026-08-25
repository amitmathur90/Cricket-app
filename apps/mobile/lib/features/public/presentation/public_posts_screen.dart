import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../application/public_providers.dart';
import '../data/models/public_post.dart';

/// `GET public/organizations/:organizationId/posts` — News/Photos/Videos
/// tabs, each just a client-side `?type=` filter of the one endpoint (see
/// `PublicRepository.getPosts`). Published posts only, newest first
/// (already sorted server-side).
class PublicPostsScreen extends ConsumerStatefulWidget {
  const PublicPostsScreen({super.key, required this.organizationId, this.initialType});

  final String organizationId;

  /// Which tab opens first — set when a caller deep-links into one section
  /// (e.g. the Fan Home screen's "Explore" grid tapping straight into
  /// "Photos"). Defaults to News.
  final PublicPostType? initialType;

  @override
  ConsumerState<PublicPostsScreen> createState() => _PublicPostsScreenState();
}

class _PublicPostsScreenState extends ConsumerState<PublicPostsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _types = PublicPostType.values;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialType != null ? _types.indexOf(widget.initialType!) : 0;
    _tabController = TabController(
      length: _types.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News & Media'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final type in _types) Tab(text: type.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [for (final type in _types) _PostsTab(organizationId: widget.organizationId, type: type)],
      ),
    );
  }
}

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.organizationId, required this.type});

  final String organizationId;
  final PublicPostType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId: organizationId, type: type);
    final postsAsync = ref.watch(publicPostsProvider(scope));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(child: Text('No ${type.label.toLowerCase()} posted yet.'));
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(publicPostsProvider(scope).future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) => _PostCard(post: posts[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text(error is ApiException ? error.message : 'Failed to load posts')),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final PublicPost post;

  /// This app has no `url_launcher` dependency today, so an external video
  /// link (always YouTube/etc — this module never hosts video files, see
  /// `PublicPost.videoUrl`'s doc comment) is copied to the clipboard rather
  /// than opened directly; same "copy, don't launch" precedent as
  /// `AdminHomeScreen._copyJoinCode`.
  Future<void> _copyVideoLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: post.videoUrl!));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Video link copied — open it in your browser')));
  }

  @override
  Widget build(BuildContext context) {
    final published = post.publishedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: post.videoUrl != null ? () => _copyVideoLink(context) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  Env.mediaUrl(post.imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (post.videoUrl != null)
                        Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  if (published != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        DateFormat.yMMMd().format(published.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    post.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
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
