import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../services/apiClient.dart';
import '../videoEditorModels/audioLibraryModel.dart';

class AudioSelectorController extends GetxController {
  // Reactive variables
  final RxString _selectedFileName = ''.obs;
  final RxString _selectedFilePath = ''.obs;
  final RxInt _selectedDuration = 0.obs;
  final RxInt _selectedAudioIndex = (-1).obs;
  final RxBool _isPlaying = false.obs;
  final RxInt _requiredDuration = 15.obs;
  final RxList<AudioData> _audioList = <AudioData>[].obs;
  final RxInt _currentPage = 1.obs;
  final RxInt _lastPage = 1.obs;
  final RxString _nextPageUrl = ''.obs;
  final RxBool _isLoading = false.obs;

  // Cache for downloaded audio files
  final Map<String, File> _audioFileCache = {};

  // Getters
  String get selectedFileName => _selectedFileName.value;

  String get selectedFilePath => _selectedFilePath.value;

  RxString get selectedFilePathRx =>
      _selectedFilePath; // Added getter for RxString

  int get selectedDuration => _selectedDuration.value;

  int get selectedAudioIndex => _selectedAudioIndex.value;

  bool get isPlaying => _isPlaying.value;

  int get requiredDuration => _requiredDuration.value;

  List<AudioData> get audioList => _audioList;

  bool get isLoading => _isLoading.value;

  // Audio player
  final AudioPlayer audioPlayer = AudioPlayer();

  void selectAudio(
    int index,
    String name,
    String path, {
    bool isPreview = false,
  }) {
    if (!isPreview) {
      _selectedAudioIndex.value = index;
      _selectedFileName.value = name;
      _selectedFilePath.value = path;
      final audio = _audioList[index];
      final duration = _parseDurationToSeconds(audio.duration ?? '0');
      _selectedDuration.value = duration;
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchAudioList();
    audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying.value = state == PlayerState.playing;
    });
  }

  @override
  void onClose() {
    audioPlayer.dispose();
    _clearCache();
    super.onClose();
  }

  // Clear cached files
  void _clearCache() {
    _audioFileCache.forEach((_, file) async {
      try {
        if (await file.exists()) await file.delete();
      } catch (e) {
        print('Error deleting cached file: $e');
      }
    });
  }

  void deselectAudio() {
    _selectedAudioIndex.value = -1;
    _selectedFileName.value = '';
    _selectedFilePath.value = '';
    _selectedDuration.value = 0;
    stopPreview();
  }

  // Set required duration
  void setRequiredDuration(int duration) => _requiredDuration.value = duration;

  // Fetch audio list from API
  Future<void> fetchAudioList({bool loadMore = false}) async {
    if (_isLoading.value || (loadMore && _nextPageUrl.value.isEmpty)) return;
    // _isLoading.value = true;
    try {
      String endpoint =
          loadMore && _nextPageUrl.value.isNotEmpty
              ? _nextPageUrl.value.replaceFirst(ApiClient.baseUrl, '')
              : 'audios/list?page=${_currentPage.value}';
      final response = await ApiClient.postRequest(endpoint, {});
      if (response.statusCode == 200) {
        final audioLibraryModel = AudioLibraryModel.fromJson(
          jsonDecode(response.body),
        );
        if (audioLibraryModel.status == true &&
            audioLibraryModel.audios != null) {
          if (!loadMore) _audioList.clear();
          _audioList.addAll(audioLibraryModel.audios!.data ?? []);
          _currentPage.value = audioLibraryModel.audios!.currentPage ?? 1;
          _lastPage.value = audioLibraryModel.audios!.lastPage ?? 1;
          _nextPageUrl.value = audioLibraryModel.audios!.nextPageUrl ?? '';
        }
      }
    } catch (e) {
      print('Error fetching audio list: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // Load more audios
  Future<void> loadMoreAudios() async {
    if (_currentPage.value < _lastPage.value) {
      await fetchAudioList(loadMore: true);
    }
  }

  // Post selected audio
  Future<bool> postSelectedAudio() async {
    try {
      final selectionData = getSelectionData();
      final postData = {
        'file_name': selectionData['fileName'],
        'file_path': selectionData['filePath'],
        'duration': selectionData['duration'],
      };
      final response = await ApiClient.postRequest(
        '/api/audio/select',
        postData,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error posting audio selection: $e');
      return false;
    }
  }

  // Pick local audio file
  Future<void> pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        _selectedFileName.value = result.files.single.name;
        _selectedFilePath.value = result.files.single.path ?? '';
        _selectedDuration.value = _requiredDuration.value;
        _selectedAudioIndex.value = -1; // Local file, no index
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  // Play audio
  Future<void> playAudio() async {
    try {
      if (_selectedFilePath.value.isEmpty) {
        print('No audio selected to play');
        return;
      }

      // Check if the audio is already playing
      if (_isPlaying.value) {
        await audioPlayer.resume(); // Resume if paused
      } else {
        // Check if the file is local or needs to be downloaded
        File? audioFile = await _downloadAudioFile(_selectedFilePath.value);
        if (audioFile != null && await audioFile.exists()) {
          await audioPlayer.play(DeviceFileSource(audioFile.path));
        } else {
          await audioPlayer.play(UrlSource(_selectedFilePath.value));
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  // Pause audio
  Future<void> pauseAudio() async {
    try {
      if (_isPlaying.value) {
        await audioPlayer.pause();
      }
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  // Preview audio
  Future<void> previewAudio(String url) async {
    await audioPlayer.stop();
    await audioPlayer.play(UrlSource(url));
  }

  // Stop preview
  Future<void> stopPreview() async {
    await audioPlayer.stop();
  }

  // Get selection data
  Map<String, dynamic> getSelectionData() => {
    'fileName': _selectedFileName.value,
    'filePath': _selectedFilePath.value,
    'duration': _selectedDuration.value,
  };

  // Download audio file and cache it
  Future<File?> _downloadAudioFile(String audioPath) async {
    if (_audioFileCache.containsKey(audioPath)) {
      final cachedFile = _audioFileCache[audioPath]!;
      if (await cachedFile.exists()) {
        return cachedFile;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'audio_${audioPath.hashCode}.mp3';
      final audioFile = File('${tempDir.path}/$fileName');

      if (await audioFile.exists()) {
        _audioFileCache[audioPath] = audioFile;
        return audioFile;
      }

      final response = await http.get(Uri.parse(audioPath));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download audio file: ${response.statusCode}',
        );
      }

      await audioFile.writeAsBytes(response.bodyBytes);
      _audioFileCache[audioPath] = audioFile;
      return audioFile;
    } catch (e) {
      print('Error downloading audio file: $e');
      return null;
    }
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
}
