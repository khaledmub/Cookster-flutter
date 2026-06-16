/// Helpers for hashtag labels from API/upload text (with or without leading `#`).
class HashtagText {
  HashtagText._();

  static List<String> splitTags(String? tags) {
    if (tags == null || tags.trim().isEmpty) {
      return const [];
    }
    return tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Display label — preserves a single `#` prefix.
  static String displayLabel(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return '';
    }
    return t.startsWith('#') ? t : '#$t';
  }

  /// Search/navigation key — strips `#` for hashtag feed API.
  static String searchKey(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return '';
    }
    return t.startsWith('#') ? t.substring(1) : t;
  }
}
