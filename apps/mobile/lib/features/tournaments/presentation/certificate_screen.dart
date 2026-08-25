import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'widgets/certificate_widget.dart';

/// Full-screen "View certificate" / "Share certificate" flow for one
/// awarded category (or per-match Man of the Match entry).
///
/// Certificate export approach (documented here per the task spec): this
/// app has no share/gallery package — grepped for `RenderRepaintBoundary`,
/// `RepaintBoundary`, `share_plus`, `Share.`, and `toImage(` across `lib/`
/// before writing this file, and none existed. None is added here either.
/// Instead:
///  1. "View certificate" (this screen, by default) renders
///     [CertificateWidget] live and full-screen inside a [RepaintBoundary]
///     — already crisp, no capture needed just to look at it.
///  2. The "Share" AppBar action captures that boundary via
///     `RenderRepaintBoundary.toImage()` / `toByteData()` — both built into
///     Flutter itself, no new dependency — into a PNG, then pushes a
///     full-screen preview of that captured image.
///
/// Flutter has no built-in "save to gallery" or native share-sheet API —
/// those require a plugin (`share_plus`, `image_gallery_saver`, `gal`,
/// etc.), none of which this app has. Rather than add one just for this
/// feature, the preview screen's hint tells the user to use their device's
/// native screenshot gesture, which every phone supports with zero app
/// code — the "simpler fallback" the task spec explicitly sanctions.
class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key, required this.data});

  final CertificateData data;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final _repaintKey = GlobalKey();
  bool _capturing = false;

  Future<void> _shareCertificate() async {
    setState(() => _capturing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final pngBytes = byteData.buffer.asUint8List();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _CertificateImagePreviewScreen(pngBytes: pngBytes),
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate'),
        actions: [
          IconButton(
            tooltip: 'Share certificate',
            icon: _capturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            onPressed: _capturing ? null : _shareCertificate,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RepaintBoundary(
            key: _repaintKey,
            child: CertificateWidget(data: widget.data),
          ),
        ),
      ),
    );
  }
}

/// Shows the captured PNG full-screen with a hint to use the device's
/// native screenshot gesture — see [CertificateScreen]'s doc comment for
/// why this, rather than an in-app save/share button, is the mechanism.
class _CertificateImagePreviewScreen extends StatelessWidget {
  const _CertificateImagePreviewScreen({required this.pngBytes});

  final Uint8List pngBytes;

  void _showHint(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Use your device's screenshot gesture to save or share this image."),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Certificate ready'),
      ),
      body: GestureDetector(
        onLongPress: () => _showHint(context),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.memory(pngBytes),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white10,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                "This app doesn't have a share integration yet — take a screenshot (or "
                'long-press this image) to save or share it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
