import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import '../../../../../services/apiClient.dart';
import '../homeModel/userSaveUnsave.dart';
import '../homeModel/videoFeedModel.dart';

class SaveController extends GetxController {
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var savedVideos = <SavedVideos>[].obs;
  /// Bumped when [savedVideos] membership changes — cheap Obx for reel save icons.
  final savedIdRevision = 0.obs;
  final Set<String> _savedVideoIds = {};
  var listMeta = Rxn<FeedMeta>();
  var currentPage = 1.obs;

  static const int listPageSize = 30;

  @override
  void onClose() {
    savedVideos.clear();
    _savedVideoIds.clear();
    listMeta.value = null;
    super.onClose();
  }

  bool isVideoSaved(String videoId) => _savedVideoIds.contains(videoId);

  void setVideoSavedLocally(String videoId, {required bool saved}) {
    if (saved) {
      _savedVideoIds.add(videoId);
    } else {
      _savedVideoIds.remove(videoId);
    }
    savedIdRevision.value++;
  }

  void _syncSavedIdSet() {
    _savedVideoIds
      ..clear()
      ..addAll(
        savedVideos
            .map((v) => v.id?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
    savedIdRevision.value++;
  }

  Future<bool> saveVideo(String videoId) async {
    try {
      isLoading(true);
      final response = await ApiClient.postRequest(EndPoints.save, {
        'video_id': videoId,
      });
      return response.statusCode == 201;
    } catch (e) {
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<void> getSavedVideos({bool reset = true}) async {
    if (reset) {
      if (isLoading.value) return;
      isLoading.value = true;
      currentPage.value = 1;
    } else {
      if (isLoading.value || isLoadingMore.value) return;
      if (listMeta.value != null && !listMeta.value!.hasMore) return;
      isLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : currentPage.value + 1;
      final response = await ApiClient.postRequest(
        EndPoints.getSavedVideos,
        {'paginate': 1, 'per_page': listPageSize, 'page': page},
      );

      if (response.statusCode != 200) {
        return;
      }

      final model = await compute(parseSavedVideos, response.body);
      listMeta.value = model.meta;
      final incoming = model.videos ?? [];

      if (reset) {
        savedVideos.assignAll(incoming);
        _syncSavedIdSet();
      } else if (incoming.isNotEmpty) {
        final existingIds = savedVideos
            .map((v) => v.id?.toString())
            .whereType<String>()
            .toSet();
        savedVideos.addAll(
          incoming.where((v) {
            final id = v.id?.toString();
            return id != null && !existingIds.contains(id);
          }),
        );
        _syncSavedIdSet();
      }

      if (model.meta?.page != null) {
        currentPage.value = model.meta!.page!;
      } else {
        currentPage.value = page;
      }
      if (incoming.isEmpty && !reset) {
        listMeta.value = FeedMeta(
          page: currentPage.value,
          perPage: listPageSize,
          hasMore: false,
        );
      }
    } catch (e) {
      // ignore
    } finally {
      if (reset) {
        isLoading.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> fetchMoreSavedVideos() => getSavedVideos(reset: false);

  bool get hasMore => listMeta.value?.hasMore ?? false;
}
