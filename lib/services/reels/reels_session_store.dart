import 'package:shared_preferences/shared_preferences.dart';

class ReelsSessionStore {
  ReelsSessionStore._();

  static final ReelsSessionStore instance = ReelsSessionStore._();

  static const String _videoIdKey = 'reels_last_video_id';
  static const String _indexKey = 'reels_last_video_index';

  Future<void> savePosition({
    required String videoId,
    required int index,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_videoIdKey, videoId);
    await prefs.setInt(_indexKey, index);
  }

  Future<String?> readVideoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_videoIdKey);
  }

  Future<int?> readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_indexKey);
  }
}
