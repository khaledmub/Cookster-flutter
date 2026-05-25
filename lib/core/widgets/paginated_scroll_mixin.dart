import 'package:flutter/material.dart';

/// Calls [onLoadMore] when the scroll view is near the bottom.
mixin PaginatedScrollMixin<T extends StatefulWidget> on State<T> {
  static const double loadMoreThreshold = 200;

  ScrollController? paginatedScrollController;

  void initPaginatedScroll(void Function() onLoadMore) {
    paginatedScrollController = ScrollController()
      ..addListener(() {
        final controller = paginatedScrollController;
        if (controller == null || !controller.hasClients) return;
        if (controller.position.pixels >=
            controller.position.maxScrollExtent - loadMoreThreshold) {
          onLoadMore();
        }
      });
  }

  void disposePaginatedScroll() {
    paginatedScrollController?.dispose();
    paginatedScrollController = null;
  }
}
