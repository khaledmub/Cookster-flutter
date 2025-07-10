import 'package:get/get.dart';

class ReviewController extends GetxController {
  final toggleStates = {
    "Jean Perkins": false,
    "Frank Garrett": false,
    "Randy Palmer": false,
  }.obs;

  void toggleReview(String name) {
    toggleStates[name] = !toggleStates[name]!;
    toggleStates.refresh();
  }

  void approveReview(String name) {
    // Implement approve logic here
    print("Approved review for $name");
  }

  void rejectReview(String name) {
    // Implement reject logic here
    print("Rejected review for $name");
  }
}
