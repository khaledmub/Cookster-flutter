import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'dart:async';

import 'package:video_thumbnail/video_thumbnail.dart';

class VideoFilterController extends GetxController {
  // Filters organized by aesthetic style categories
  final filters =
      [
        {
          'category': 'Cinematic',
          'filters': [
            {
              'name': 'Vintage',
              'commandTemplate':
                  'eq=contrast=1.2:saturation=0.8:brightness=-0.1',
              'minValue': 0.0,
              'maxValue': 1.0,
              'defaultValue': 0.5,
              'svgPath': 'assets/icons/vintage.svg',
            },
            {
              'name': 'Cinematic',
              'commandTemplate':
                  'eq=contrast=1.3:brightness=-0.05:saturation=0.9',
              'minValue': 0.0,
              'maxValue': 1.0,
              'defaultValue': 0.7,
              'svgPath': 'assets/icons/cinematic.svg',
            },
            {
              'name': 'Fade',
              'commandTemplate': 'eq=contrast=0.8:saturation={value}',
              'minValue': 0.5,
              'maxValue': 1.5,
              'defaultValue': 0.7,
              'svgPath': 'assets/icons/fade.svg',
            },
          ],
        },
        {
          'category': 'Natural Tones',
          'filters': [
            {
              'name': 'Warm',
              'commandTemplate': 'eq=brightness=0.1:saturation={value}',
              'minValue': 1.0,
              'maxValue': 2.0,
              'defaultValue': 1.2,
              'svgPath': 'assets/icons/warm.svg',
            },
            {
              'name': 'Glow',
              'commandTemplate': 'eq=brightness={value}:contrast=1.1',
              'minValue': 0.1,
              'maxValue': 0.5,
              'defaultValue': 0.3,
              'svgPath': 'assets/icons/glow.svg',
            },
            {
              'name': 'Shade',
              'commandTemplate': 'eq=brightness={value}',
              'minValue': -1.0,
              'maxValue': 0.0,
              'defaultValue': -0.3,
              'svgPath': 'assets/icons/dim.svg',
            },
          ],
        },

        {
          'category': 'High Contrast',
          'filters': [
            {
              'name': 'Monochrome',
              'commandTemplate': 'eq=saturation=0',
              'minValue': 0.0,
              'maxValue': 0.0,
              'defaultValue': 0.0,
              'svgPath': 'assets/icons/monochrome.svg',
            },
            {
              'name': 'HighContrast',
              'commandTemplate': 'eq=contrast={value}:brightness=0.1',
              'minValue': 1.5,
              'maxValue': 3.0,
              'defaultValue': 2.0,
              'svgPath': 'assets/icons/highcontrast.svg',
            },
            {
              'name': 'Focus',
              'commandTemplate': 'eq=contrast={value}',
              'minValue': 0.0,
              'maxValue': 2.0,
              'defaultValue': 1.5,
              'svgPath': 'assets/icons/focus.svg',
            },
            {
              'name': 'Smooth',
              'commandTemplate': 'eq=contrast={value}',
              'minValue': 0.0,
              'maxValue': 1.0,
              'defaultValue': 0.5,
              'svgPath': 'assets/icons/soft.svg',
            },
          ],
        },
        {
          'category': 'Vibrant',
          'filters': [
            {
              'name': 'Vibe',
              'commandTemplate': 'eq=saturation={value}',
              'minValue': 0.0,
              'maxValue': 3.0,
              'defaultValue': 1.0,
              'svgPath': 'assets/icons/vibe.svg',
            },
            {
              'name': 'Lumina',
              'commandTemplate': 'eq=brightness={value}',
              'minValue': -1.0,
              'maxValue': 1.0,
              'defaultValue': 0.3,
              'svgPath': 'assets/icons/lumina.svg',
            },
          ],
        },
      ].obs;

  var isFilterListVisible = false.obs;
  var isProcessing = false.obs;
  var selectedFilter = Rxn<Map<String, dynamic>>();
  var sliderValue = 0.0.obs;
  var filteredVideoFile = Rxn<File>();
  Timer? _debounceTimer;
  final Duration debounceDuration = Duration(milliseconds: 500);

  @override
  void onInit() {
    super.onInit();
    ever(selectedFilter, (_) {
      if (selectedFilter.value != null &&
          selectedFilter.value!['defaultValue'] != null) {
        sliderValue.value = selectedFilter.value!['defaultValue'];
        print(
          'Selected filter: ${selectedFilter.value!['name']}, '
          'Slider value: ${sliderValue.value}',
        );
      }
    });
    ever(sliderValue, (_) {
      print('Slider value updated: ${sliderValue.value}');
    });
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  void toggleFilterList() {
    isFilterListVisible.value = !isFilterListVisible.value;
  }

  void updateSliderValue(double value, File inputVideo) {
    sliderValue.value = value;
    _debounceTimer?.cancel();
    print(
      'Updating slider value to: $value for filter: '
      '${selectedFilter.value?['name'] ?? 'none'}',
    );
  }

  void clearFilter() {
    selectedFilter.value = null;
    filteredVideoFile.value = null;
    sliderValue.value = 0.0;
    _debounceTimer?.cancel();
    print('Filter cleared');
  }

  // Returns a filter configuration for rendering
  Map<String, dynamic> getFilterConfig({
    Map<String, dynamic>? filter,
    required double value,
  }) {
    final selectedFilter = filter ?? this.selectedFilter.value;
    final filterValue = value;

    if (selectedFilter == null) {
      return {
        'type': 'none',
        'colorFilter': ColorFilter.mode(Colors.transparent, BlendMode.multiply),
        'imageFilter': null,
      };
    }

    switch (selectedFilter['name']) {
      case 'Lumina':
        double brightness = filterValue.clamp(-1.0, 1.0);
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            1,
            0,
            0,
            0,
            brightness * 255,
            0,
            1,
            0,
            0,
            brightness * 255,
            0,
            0,
            1,
            0,
            brightness * 255,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Focus':
        double contrast = filterValue.clamp(0.0, 2.0);
        double offset = (1.0 - contrast) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            contrast,
            0,
            0,
            0,
            offset,
            0,
            contrast,
            0,
            0,
            offset,
            0,
            0,
            contrast,
            0,
            offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Vibe':
        double saturation = filterValue.clamp(0.0, 3.0);
        double rw = 0.3086;
        double gw = 0.6094;
        double bw = 0.0820;
        double s = saturation;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            (1 - s) * rw + s,
            (1 - s) * gw,
            (1 - s) * bw,
            0,
            0,
            (1 - s) * rw,
            (1 - s) * gw + s,
            (1 - s) * bw,
            0,
            0,
            (1 - s) * rw,
            (1 - s) * gw,
            (1 - s) * bw + s,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Classic':
        double grayscale = filterValue.clamp(0.0, 1.0);
        double rw = 0.299;
        double gw = 0.587;
        double bw = 0.114;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            rw + (1 - grayscale) * (1 - rw),
            gw - grayscale * gw,
            bw - grayscale * bw,
            0,
            0,
            rw - grayscale * rw,
            gw + (1 - grayscale) * (1 - gw),
            bw - grayscale * bw,
            0,
            0,
            rw - grayscale * rw,
            gw - grayscale * gw,
            bw + (1 - grayscale) * (1 - bw),
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Shade':
        double dim = filterValue.clamp(-1.0, 0.0);
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            1,
            0,
            0,
            0,
            dim * 255,
            0,
            1,
            0,
            0,
            dim * 255,
            0,
            0,
            1,
            0,
            dim * 255,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Smooth':
        double soften = filterValue.clamp(0.0, 1.0);
        double offset = (1.0 - soften) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            soften,
            0,
            0,
            0,
            offset,
            0,
            soften,
            0,
            0,
            offset,
            0,
            0,
            soften,
            0,
            offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Vintage':
        double intensity = filterValue.clamp(0.0, 1.0);
        double contrast = 1.2 * intensity;
        double saturation = 0.8 * intensity;
        double brightness = -0.1 * intensity;
        double offset = (1.0 - contrast) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            contrast * (0.3086 * (1 - saturation) + saturation),
            contrast * (0.6094 * (1 - saturation)),
            contrast * (0.0820 * (1 - saturation)),
            0,
            brightness * 255 + offset,
            contrast * (0.3086 * (1 - saturation)),
            contrast * (0.6094 * (1 - saturation) + saturation),
            contrast * (0.0820 * (1 - saturation)),
            0,
            brightness * 255 + offset,
            contrast * (0.3086 * (1 - saturation)),
            contrast * (0.6094 * (1 - saturation)),
            contrast * (0.0820 * (1 - saturation) + saturation),
            0,
            brightness * 255 + offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Warm':
        double saturation = filterValue.clamp(1.0, 2.0);
        double brightness = 0.1;
        double rw = 0.3086;
        double gw = 0.6094;
        double bw = 0.0820;
        double s = saturation;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            (1 - s) * rw + s,
            (1 - s) * gw,
            (1 - s) * bw,
            0,
            brightness * 255,
            (1 - s) * rw,
            (1 - s) * gw + s,
            (1 - s) * bw,
            0,
            brightness * 255,
            (1 - s) * rw,
            (1 - s) * gw,
            (1 - s) * bw + s,
            0,
            brightness * 255,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Cinematic':
        double intensity = filterValue.clamp(0.0, 1.0);
        double contrast = 1.3 * intensity;
        double brightness = -0.05 * intensity;
        double saturation = 0.9 * intensity;
        double offset = (1.0 - contrast) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            contrast * (0.3086 * (1 - saturation) + saturation),
            contrast * (0.6094 * (1 - saturation)),
            contrast * (0.0820 * (1 - saturation)),
            0,
            brightness * 255 + offset,
            contrast * (0.3086 * (1 - saturation)),
            contrast * (0.6094 * (1 - saturation) + saturation),
            contrast * (0.0820 * (1 - saturation)),
            0,
            brightness * 255 + offset,
            contrast * (0.3086 * (1 - saturation)),
            contrast * (0.6094 * (1 - saturation)),
            contrast * (0.0820 * (1 - saturation) + saturation),
            0,
            brightness * 255 + offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Monochrome':
        double grayscale = 1.0;
        double rw = 0.299;
        double gw = 0.587;
        double bw = 0.114;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            rw,
            gw,
            bw,
            0,
            0,
            rw,
            gw,
            bw,
            0,
            0,
            rw,
            gw,
            bw,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'HighContrast':
        double contrast = filterValue.clamp(1.5, 3.0);
        double brightness = 0.1;
        double offset = (1.0 - contrast) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            contrast,
            0,
            0,
            0,
            brightness * 255 + offset,
            0,
            contrast,
            0,
            0,
            brightness * 255 + offset,
            0,
            0,
            contrast,
            0,
            brightness * 255 + offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Glow':
        double brightness = filterValue.clamp(0.1, 0.5);
        double contrast = 1.1;
        double offset = (1.0 - contrast) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            contrast,
            0,
            0,
            0,
            brightness * 255 + offset,
            0,
            contrast,
            0,
            0,
            brightness * 255 + offset,
            0,
            0,
            contrast,
            0,
            brightness * 255 + offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      case 'Fade':
        double saturation = filterValue.clamp(0.5, 1.5);
        double contrast = 0.8;
        double rw = 0.3086;
        double gw = 0.6094;
        double bw = 0.0820;
        double s = saturation;
        double offset = (1.0 - contrast) / 2.0 * 255;
        return {
          'type': 'color',
          'colorFilter': ColorFilter.matrix([
            contrast * ((1 - s) * rw + s),
            contrast * ((1 - s) * gw),
            contrast * ((1 - s) * bw),
            0,
            offset,
            contrast * ((1 - s) * rw),
            contrast * ((1 - s) * gw + s),
            contrast * ((1 - s) * bw),
            0,
            offset,
            contrast * ((1 - s) * rw),
            contrast * ((1 - s) * gw),
            contrast * ((1 - s) * bw + s),
            0,
            offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          'imageFilter': null,
        };
      default:
        return {
          'type': 'none',
          'colorFilter': ColorFilter.mode(
            Colors.transparent,
            BlendMode.multiply,
          ),
          'imageFilter': null,
        };
    }
  }

  Future<File?> generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.PNG,
        maxHeight: 100,
        quality: 75,
      );
      return thumbnailPath != null ? File(thumbnailPath) : null;
    } catch (e) {
      print("Error generating thumbnail: $e");
      return null;
    }
  }
}
