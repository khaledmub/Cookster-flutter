import 'dart:async';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../../../services/apiClient.dart';
import '../homeModel/videoFeedModel.dart';

class HashtagController extends GetxController {
  var videoFeed = VideoFeed().obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var error = "".obs;
  var currentPage = 1.obs;
  var currentIndex = 0.obs;

  static const int feedPageSize = 15;
  String? _activeTag;
  String? _activeCity;

  @override
  void onClose() {
    super.onClose();
  }

  Future<void> fetchVideos({String? city, required String tag}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    _activeTag = tag;

    try {
      final selectedCity = await _resolveCity(city);
      if (selectedCity == null) {
        return;
      }
      _activeCity = selectedCity;

      final response = await ApiClient.postRequest(
        EndPoints.getVideos,
        _buildFeedPayload(reset: true, city: selectedCity, tag: tag),
      );
      if (response.statusCode == 200) {
        videoFeed.value = await compute(parseVideoFeed, response.body);
        currentPage.value = videoFeed.value.meta?.page ?? 1;
        currentIndex.value = 0;
      } else {
        error.value = "Failed to load videos: ${response.statusCode}";
      }
    } catch (e) {
      error.value = "Error: $e";
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> fetchMoreVideos() async {
    if (isLoading.value ||
        isLoadingMore.value ||
        _activeTag == null ||
        _activeCity == null ||
        videoFeed.value.videos == null ||
        videoFeed.value.videos!.isEmpty) {
      return;
    }

    final meta = videoFeed.value.meta;
    if (meta != null && !meta.hasMore) {
      return;
    }

    isLoadingMore.value = true;
    try {
      final response = await ApiClient.postRequest(
        EndPoints.getVideos,
        _buildFeedPayload(
          reset: false,
          city: _activeCity!,
          tag: _activeTag!,
        ),
      );
      if (response.statusCode != 200) {
        error.value = "Failed to load more videos: ${response.statusCode}";
        return;
      }

      final parsed = await compute(parseVideoFeed, response.body);
      final incoming = parsed.videos ?? [];
      if (incoming.isEmpty) {
        videoFeed.value.meta?.hasMore = false;
        videoFeed.refresh();
        return;
      }

      final existingIds = videoFeed.value.videos!
          .map((v) => v.id)
          .whereType<String>()
          .toSet();
      final uniqueIncoming = incoming
          .where((v) => v.id != null && !existingIds.contains(v.id))
          .toList();

      videoFeed.value.videos!.addAll(uniqueIncoming);
      videoFeed.value.meta = parsed.meta ?? videoFeed.value.meta;
      if (parsed.meta?.page != null) {
        currentPage.value = parsed.meta!.page!;
      }
      videoFeed.refresh();
    } catch (e) {
      error.value = "Error loading more videos: $e";
    } finally {
      isLoadingMore.value = false;
      update();
    }
  }

  Map<String, dynamic> _buildFeedPayload({
    required bool reset,
    required String city,
    required String tag,
  }) {
    final base = <String, dynamic>{
      'city': city,
      'tags': tag,
      'paginate': 1,
      'per_page': feedPageSize,
    };

    if (reset) {
      base['page'] = 1;
      return base;
    }

    final meta = videoFeed.value.meta;
    if (meta != null) {
      base.addAll(meta.toRequestPayload());
    } else {
      base['page'] = currentPage.value + 1;
    }
    return base;
  }

  Future<String?> _resolveCity(String? city) async {
    if (city != null && city.trim().isNotEmpty) {
      return city.trim();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        error.value = "Location permission denied";
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      error.value = "Location permission permanently denied";
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    return placemarks.isNotEmpty
        ? placemarks[0].locality ?? 'Unknown'
        : 'Unknown';
  }
}
