import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../liked_videos_model/liked_videos_model.dart';

class LikedVideosController extends GetxController {
  LikedVideosController({required this.userId});

  final String userId;

  final RxList<String> videoIds = <String>[].obs;
  final RxInt totalLikes = 0.obs;
  final RxString commaSeparatedIds = ''.obs;
  final RxList<LikedVideos> likedVideos = <LikedVideos>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final listMeta = Rxn<FeedMeta>();
  final currentPage = 1.obs;

  static const int listPageSize = 30;

  String? _previousCommaSeparatedIds;
  String? _activeVideoIds;

  @override
  void onInit() {
    super.onInit();
    bindStreams();
  }

  void bindStreams() {
    FirebaseFirestore.instance
        .collection('videos')
        .where('likes', arrayContains: userId)
        .snapshots()
        .listen(
          (querySnapshot) {
            totalLikes.value = querySnapshot.docs.length;
            videoIds.value = querySnapshot.docs.map((doc) => doc.id).toList();
            commaSeparatedIds.value = videoIds.join(',');

            if (commaSeparatedIds.value != _previousCommaSeparatedIds &&
                commaSeparatedIds.value.isNotEmpty) {
              _previousCommaSeparatedIds = commaSeparatedIds.value;
              _activeVideoIds = commaSeparatedIds.value;
              sendVideoIdsToApi(commaSeparatedIds.value, reset: true);
            } else if (commaSeparatedIds.value.isEmpty) {
              likedVideos.clear();
              listMeta.value = FeedMeta(hasMore: false);
            }
          },
          onError: (e) => _showError('Error fetching liked videos: $e'),
        );
  }

  Future<void> sendVideoIdsToApi(
    String ids, {
    bool reset = true,
  }) async {
    if (ids.isEmpty) return;

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
      final response = await ApiClient.postRequest(EndPoints.myLikedVideos, {
        'video_ids': ids,
        'paginate': 1,
        'per_page': listPageSize,
        'page': page,
      });

      if (response.statusCode != 200) {
        if (!reset) return;
        _showError('Failed to fetch liked videos: ${response.statusCode}');
        return;
      }

      final model = await compute(parseLikedVideos, response.body);
      listMeta.value = model.meta;
      final incoming = model.videos ?? [];

      if (reset) {
        if (incoming.isEmpty) {
          likedVideos.clear();
        } else {
          likedVideos.assignAll(incoming);
        }
      } else if (incoming.isNotEmpty) {
        final existingIds = likedVideos
            .map((v) => v.id?.toString())
            .whereType<String>()
            .toSet();
        likedVideos.addAll(
          incoming.where((v) {
            final id = v.id?.toString();
            return id != null && !existingIds.contains(id);
          }),
        );
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
      if (reset) {
        _showError('Error fetching liked videos: $e');
      }
    } finally {
      if (reset) {
        isLoading.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> fetchMoreLikedVideos() async {
    final ids = _activeVideoIds ?? commaSeparatedIds.value;
    if (ids.isEmpty) return;
    await sendVideoIdsToApi(ids, reset: false);
  }

  bool get hasMore => listMeta.value?.hasMore ?? false;

  void _showError(String message) {
    Get.snackbar('Error', message, duration: const Duration(seconds: 3));
  }
}
