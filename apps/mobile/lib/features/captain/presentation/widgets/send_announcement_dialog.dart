import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/application/session_controller.dart';
import '../../../teams/application/teams_providers.dart';
import '../../../teams/data/models/team.dart';
import '../../application/captain_providers.dart';

/// "Captain announcements" — a text field + send button that broadcasts a
/// `type: 'announcement'` notification (via `CaptainNotificationsRepository`
/// -> `POST .../notifications`) to every squad member who has a linked
/// login account (`Player.userId != null`); players without one have
/// nothing to notify and are silently skipped, same as
/// `NotificationsService.notify`'s own "tolerant of a sparse recipient
/// list" behavior server-side.
///
/// Squad membership is resolved from [pickPrimaryTournament]'s pick among
/// the team's registered tournaments (same default the Squad tab uses),
/// since the roster itself is scoped per tournament-team, not per team.
Future<void> showSendAnnouncementDialog(
  BuildContext context,
  WidgetRef ref, {
  required Team team,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SendAnnouncementDialog(team: team),
  );
}

class _SendAnnouncementDialog extends ConsumerStatefulWidget {
  const _SendAnnouncementDialog({required this.team});

  final Team team;

  @override
  ConsumerState<_SendAnnouncementDialog> createState() => _SendAnnouncementDialogState();
}

class _SendAnnouncementDialogState extends ConsumerState<_SendAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    setState(() => _sending = true);
    try {
      final tournaments =
          await ref.read(captainTeamTournamentsProvider(widget.team.id).future);
      final primary = pickPrimaryTournament(tournaments);
      if (primary == null) {
        throw ApiException('This team isn\'t registered to a tournament yet.');
      }
      final roster = await ref
          .read(teamsRepositoryProvider)
          .getRoster(organizationId, widget.team.id, primary.id);
      final recipientUserIds = {
        for (final entry in roster)
          if (entry.player.userId != null) entry.player.userId!,
      }.toList();

      if (recipientUserIds.isEmpty) {
        throw ApiException(
          'No squad members have a linked login account to notify yet.',
        );
      }

      await ref.read(captainNotificationsRepositoryProvider).sendAnnouncement(
            organizationId,
            recipientUserIds: recipientUserIds,
            title: title,
            message: message,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Announcement sent to ${recipientUserIds.length} player(s)')),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send announcement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
