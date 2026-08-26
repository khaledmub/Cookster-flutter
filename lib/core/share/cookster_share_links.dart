/// Canonical Cookster web + in-app link builders.
///
/// Share messages must use [webOrigin] HTTPS URLs only. Custom-scheme links
/// that embed `open.cookster.app` get linkified by WhatsApp as broken
/// `https://cookster.app/...` (404 on GCS).
class CooksterShareLinks {
  CooksterShareLinks._();

  static const webOrigin = 'https://cookster.org';

  static String videoWebUrl(String videoId) =>
      '$webOrigin/web/visitSingleVideo?id=${videoId.trim()}';

  static String profileWebUrl({String? userId, String? email}) {
    final trimmedId = userId?.trim() ?? '';
    if (trimmedId.isNotEmpty) {
      return '$webOrigin/web/visitProfile?id=$trimmedId';
    }
    final trimmedEmail = email?.trim() ?? '';
    if (trimmedEmail.isNotEmpty) {
      return '$webOrigin/profile?email=${Uri.encodeComponent(trimmedEmail)}';
    }
    return webOrigin;
  }

  /// In-app deep link (landing pages, notifications) — not for WhatsApp text.
  static String videoAppUrl(String videoId) =>
      'cookster://open.cookster.app/web/visitSingleVideo?id=${videoId.trim()}';

  static String profileAppUrl(String userId) =>
      'cookster://open.cookster.app/web/visitProfile?id=${userId.trim()}';

  static String videoShareMessage(String videoId) =>
      'Check out this amazing video on Cookster!\n${videoWebUrl(videoId)}';

  static String profileShareMessage({
    String? userId,
    String? email,
    String? displayName,
  }) {
    final url = profileWebUrl(userId: userId, email: email);
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'Check out $name on Cookster!\n$url';
    }
    return 'Check out this profile on Cookster!\n$url';
  }
}
