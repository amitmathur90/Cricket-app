import 'package:flutter/material.dart';

/// Everything [CertificateWidget] needs to render one award as a digital
/// certificate — plain display data, not tied to [AwardResult]'s wire shape
/// so the same widget can render both a tournament-wide award and a
/// per-match Man-of-the-Match entry.
class CertificateData {
  const CertificateData({
    required this.tournamentName,
    required this.awardTitle,
    required this.playerName,
    required this.teamName,
    required this.statLine,
    required this.issuedDateLabel,
    this.organizationName,
  });

  final String tournamentName;
  final String awardTitle;
  final String playerName;
  final String teamName;
  final String statLine;

  /// Already-formatted date string (e.g. "23 Aug 2026") — formatting is the
  /// caller's job so this widget stays a pure display component.
  final String issuedDateLabel;

  final String? organizationName;
}

/// A simple, tasteful digital certificate — tournament name, award title,
/// player name, team, stat line, date, and (when known) the organizing
/// body's name. Deliberately plain (a bordered card with decorative
/// typography, a trophy glyph, no photos/graphics) per the spec: this is a
/// shareable keepsake, not a print-shop design.
///
/// Kept as its own widget (rather than inline in [CertificateScreen]) so it
/// can be wrapped in a `RepaintBoundary` and captured via
/// `RenderRepaintBoundary.toImage()` independent of the screen chrome
/// (AppBar, buttons, hint text) around it.
class CertificateWidget extends StatelessWidget {
  const CertificateWidget({super.key, required this.data});

  final CertificateData data;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB8860B);
    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          border: Border.all(color: gold, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: gold.withValues(alpha: 0.5), width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: gold, size: 36),
              const SizedBox(height: 8),
              Text(
                'CERTIFICATE OF ACHIEVEMENT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.tournamentName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This certifies that',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                data.playerName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                data.teamName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'has been awarded',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                data.awardTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (data.statLine.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  data.statLine,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.issuedDateLabel,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  if ((data.organizationName ?? '').trim().isNotEmpty) ...[
                    const Text('  ·  ', style: TextStyle(color: Colors.black38, fontSize: 11)),
                    Flexible(
                      child: Text(
                        data.organizationName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
