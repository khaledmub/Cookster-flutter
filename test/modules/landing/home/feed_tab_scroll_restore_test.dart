import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController tab scroll restore', () {
    late HomeController controller;

    setUp(() {
      Get.testMode = true;
      controller = HomeController();
    });

    tearDown(() {
      Get.reset();
    });

    WallVideos video(String id) => WallVideos(id: id, title: id);

    test('resolveScrollIndexForTab prefers saved video id', () {
      final videos = [video('a'), video('b'), video('c')];
      controller.saveTabScrollIndex('Near Me', 0);
      controller.saveTabVideoId('Near Me', 'c');

      expect(
        controller.resolveScrollIndexForTab('Near Me', videos),
        2,
      );
    });

    test('resolveScrollIndexForTab falls back to saved index', () {
      final videos = [video('a'), video('b'), video('c')];
      controller.saveTabScrollIndex('General', 1);

      expect(
        controller.resolveScrollIndexForTab('General', videos),
        1,
      );
    });

    test('resolveScrollIndexForTab falls back to 0 when saved id is stale', () {
      final videos = [video('a'), video('b'), video('c')];
      controller.saveTabScrollIndex('Near Me', 2);
      controller.saveTabVideoId('Near Me', 'missing');

      expect(
        controller.resolveScrollIndexForTab('Near Me', videos),
        0,
      );
    });

    test('resolveScrollIndexForTab falls back to 0 when saved index out of bounds',
        () {
      final videos = [video('a'), video('b')];
      controller.saveTabScrollIndex('Following', 9);

      expect(
        controller.resolveScrollIndexForTab('Following', videos),
        0,
      );
    });

    test('resetTabScrollRestore clears saved id and index', () {
      final videos = [video('a'), video('b'), video('c')];
      controller.saveTabScrollIndex('Near Me', 2);
      controller.saveTabVideoId('Near Me', 'c');

      controller.resetTabScrollRestore('Near Me');

      expect(controller.resolveScrollIndexForTab('Near Me', videos), 0);
    });
  });
}
