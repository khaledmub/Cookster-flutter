import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/basicVideoEditor/videoEditorControllers/audioSelectorController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cookster/appUtils/colorUtils.dart'; // Assuming ColorUtils is defined here

class AudioSelector extends StatelessWidget {
  final AudioSelectorController controller = Get.find();
  final String? audioUrl;
  final List<Map<String, dynamic>>? availableAudios;
  final int? initialDuration;
  final Function(Map<String, dynamic>)? onAudioSelected;

  AudioSelector({
    super.key,
    this.audioUrl,
    this.availableAudios,
    this.initialDuration = 15,
    this.onAudioSelected,
  }) {
    if (initialDuration != null) {
      controller.setRequiredDuration(initialDuration!);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  int _parseDurationToSeconds(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return minutes * 60 + seconds;
      }
      return int.parse(duration);
    } catch (e) {
      print('Error parsing duration: $e');
      return 0;
    }
  }

  List<Map<String, dynamic>> _getAudioList() {
    if (controller.audioList.isNotEmpty) {
      return controller.audioList
          .asMap()
          .entries
          .map(
            (entry) => {
              'name': entry.value.title ?? 'Audio ${entry.key + 1}',
              'url': '${Common.audioUrl}/${entry.value.file}',
              'image': '${Common.audioUrl}/${entry.value.image}',
              'duration': entry.value.duration ?? '0',
              'artist': entry.value.artist ?? 'Unknown',
            },
          )
          .toList();
    }
    if (availableAudios != null && availableAudios!.isNotEmpty) {
      return availableAudios!;
    }
    return List.generate(2, (index) {
      return {
        'name': 'Audio Track ${index + 1}',
        'url': '${Common.audioUrl}/${audioUrl}',
      };
    });
  }

  void _showAudioBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Obx(() {
          final selectedIndex = controller.selectedAudioIndex;
          final audioList = _getAudioList();
          final isLoading = controller.isLoading;

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                          'select_music'.tr,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (audioList.isEmpty && !isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No audios available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ListTile(
                          leading: const Icon(
                            Icons.cancel,
                            color: Colors.white,
                          ),
                          title: Text(
                            'no_music'.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            controller.deselectAudio();
                            if (onAudioSelected != null) {
                              onAudioSelected!({});
                            }
                            Navigator.pop(context);
                          },
                        ),
                        ...List.generate(audioList.length, (index) {
                          final audio = audioList[index];
                          final isSelected = selectedIndex == index;
                          return ListTile(
                            trailing: IconButton(
                              icon: Obx(() {
                                return Icon(
                                  controller.isPlaying && isSelected
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                );
                              }),
                              onPressed: () {
                                if (isSelected && controller.isPlaying) {
                                  controller.stopPreview();
                                } else {
                                  controller.selectAudio(
                                    index,
                                    audio['name'],
                                    audio['url'],
                                    isPreview: true,
                                  );
                                  controller.previewAudio(audio['url']);
                                  if (onAudioSelected != null) {
                                    onAudioSelected!(audio);
                                  }
                                }
                              },
                            ),
                            leading: SizedBox(
                              height: 30,
                              width: 30,
                              child: CachedNetworkImage(
                                imageUrl: audio['image'] ?? '',
                                placeholder:
                                    (context, url) =>
                                        const CircularProgressIndicator(),
                                errorWidget:
                                    (context, url, error) =>
                                        const Icon(Icons.error),
                              ),
                            ),
                            title: Text(
                              audio['name'],
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? ColorUtils.primaryColor
                                        : Colors.white,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${audio['artist'] ?? 'Unknown'} - ${_formatDuration(_parseDurationToSeconds(audio['duration'] ?? '0'))}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            onTap: () {
                              controller.selectAudio(
                                index,
                                audio['name'],
                                audio['url'],
                                isPreview: false,
                              );
                              controller.previewAudio(audio['url']);
                              if (onAudioSelected != null) {
                                onAudioSelected!(audio);
                              }
                              // Navigator.pop(context);
                            },
                            tileColor: isSelected ? Colors.grey[900] : null,
                          );
                        }),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showAudioBottomSheet(context),
            child: Align(
              alignment: Alignment.topCenter,
              child: IntrinsicWidth(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 150),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note_rounded, color: Colors.black),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.selectedFileName.isEmpty
                              ? "Add Music".tr
                              : controller.selectedFileName,
                          style: const TextStyle(color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Obx(() {
                        return InkWell(
                          onTap: () {
                            if (controller.isPlaying) {
                              controller.pauseAudio();
                            } else {
                              controller.playAudio();
                            }
                          },
                          child:
                              controller.isPlaying
                                  ? const Icon(Icons.pause)
                                  : const Icon(Icons.play_arrow),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
