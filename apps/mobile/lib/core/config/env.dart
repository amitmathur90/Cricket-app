/// Build-time configuration.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
///
/// Defaults to the special Android-emulator alias for the host machine's
/// `localhost` (10.0.2.2), since that's the primary target for this app
/// during development (no iOS/desktop toolchain available on this machine).
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Resolves a server-relative media path (e.g. `/uploads/{orgId}/x.jpg`,
  /// as returned by `POST .../uploads`) into an absolute URL for display.
  static String mediaUrl(String relativeOrAbsolutePath) {
    if (relativeOrAbsolutePath.startsWith('http://') ||
        relativeOrAbsolutePath.startsWith('https://')) {
      return relativeOrAbsolutePath;
    }
    return '$apiBaseUrl$relativeOrAbsolutePath';
  }
}
