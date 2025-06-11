import 'dart:io';
import 'dart:math' as math;

import 'package:cookster/basicVideoEditor/videoEditorControllers/videoFilterController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../appUtils/colorUtils.dart';

class VideoFilterUI extends StatelessWidget {
  final VideoFilterController videoFilterController = Get.find<VideoFilterController>();
  final File? selectedVideo;
  final ScrollController _filterScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final List<GlobalKey> _categoryKeys = [];
  final RxInt selectedCategoryIndex = 0.obs; // Track selected category
  final RxBool _isScrolling = false.obs; // Prevent recursive scroll triggers

  VideoFilterUI({this.selectedVideo});

  @override
  Widget build(BuildContext context) {
    // Generate keys for each category
    _categoryKeys.clear();
    for (var _ in videoFilterController.filters) {
      _categoryKeys.add(GlobalKey());
    }

    // Set default category to first category when filter list becomes visible
    ever(videoFilterController.isFilterListVisible, (bool isVisible) {
      if (isVisible && _categoryKeys.isNotEmpty) {
        selectedCategoryIndex.value = 0;
        // Delay to ensure layout is complete
        Future.delayed(Duration(milliseconds: 200), () {
          _scrollToCategory(0, context);
        });
      }
    });

    // Listen to filter scroll events to update selected category
    _filterScrollController.addListener(() {
      if (_isScrolling.value || _categoryKeys.isEmpty) return;

      // Calculate which category is most visible
      final screenWidth = MediaQuery.of(context).size.width;
      final scrollPosition = _filterScrollController.offset;
      final maxScroll = _filterScrollController.position.maxScrollExtent;

      // Special case for when we're at the end of the scroll
      if (maxScroll > 0 && scrollPosition >= maxScroll - 20) {
        // We're at the end, select the last category
        if (selectedCategoryIndex.value != _categoryKeys.length - 1) {
          _isScrolling.value = true;
          selectedCategoryIndex.value = _categoryKeys.length - 1;
          _scrollCategoryIntoView(_categoryKeys.length - 1, context);
          Future.delayed(Duration(milliseconds: 100), () {
            _isScrolling.value = false;
          });
        }
        return;
      }

      // Calculate visible area
      final visibleStart = scrollPosition;
      final visibleEnd = scrollPosition + screenWidth;

      // Find which category is most visible
      double bestVisiblePortion = 0;
      int bestVisibleIndex = selectedCategoryIndex.value; // Default to current

      // Track start of each section
      List<double> sectionStarts = [];
      double currentPosition = 0;

      // First pass: collect section positions
      for (int i = 0; i < _categoryKeys.length; i++) {
        final keyContext = _categoryKeys[i].currentContext;
        if (keyContext != null) {
          final RenderBox box = keyContext.findRenderObject() as RenderBox;
          sectionStarts.add(currentPosition);
          currentPosition += box.size.width;
        } else {
          sectionStarts.add(currentPosition);
        }
      }

      // Add end position
      sectionStarts.add(currentPosition);

      // Second pass: find most visible section
      for (int i = 0; i < _categoryKeys.length; i++) {
        final sectionStart = sectionStarts[i];
        final sectionEnd = sectionStarts[i + 1];

        // Calculate how much of this section is visible
        final visibleStart_section = math.max(visibleStart, sectionStart);
        final visibleEnd_section = math.min(visibleEnd, sectionEnd);

        if (visibleStart_section < visibleEnd_section) {
          final visiblePortion = visibleEnd_section - visibleStart_section;

          // If this section is more visible than our current best, update
          if (visiblePortion > bestVisiblePortion) {
            bestVisiblePortion = visiblePortion;
            bestVisibleIndex = i;
          }
        }
      }

      // Update selected category if it changed
      if (selectedCategoryIndex.value != bestVisibleIndex) {
        _isScrolling.value = true;
        selectedCategoryIndex.value = bestVisibleIndex;

        // Scroll the category tabs to show the selected one
        _scrollCategoryIntoView(bestVisibleIndex, context);

        Future.delayed(Duration(milliseconds: 100), () {
          _isScrolling.value = false;
        });
      }
    });

    return Obx(() {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: videoFilterController.isFilterListVisible.value ? 140 : 0,
          width: double.infinity,
          child: videoFilterController.isFilterListVisible.value
              ? Container(
            color: Colors.black,
            child: Column(

              children: [
                // Category selection
                Container(
                  height: 40,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: AlwaysScrollableScrollPhysics(),
                    controller: _categoryScrollController,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Block icon to unselect all
                        _buildBlockIcon(context),
                        // Categories
                        ...videoFilterController.filters.asMap().entries.map((entry) {
                          int index = entry.key;
                          var category = entry.value['category'] as String;
                          return _buildCategoryChip(
                            context,
                            category,
                            index,
                            _categoryKeys[index],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Filter list
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: AlwaysScrollableScrollPhysics(),
                    controller: _filterScrollController,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category-wise filters
                        ...videoFilterController.filters.asMap().entries.map((entry) {
                          int categoryIndex = entry.key;
                          var category = entry.value['category'] as String;
                          var filters = entry.value['filters'] as List<Map<String, dynamic>>;
                          return _buildFilterSection(
                            context,
                            category,
                            filters,
                            _categoryKeys[categoryIndex],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
              : null,
        ),
      );
    });
  }

  // Method to scroll to a specific filter category
  void _scrollToCategory(int index, BuildContext context) {
    if (index < 0 || index >= _categoryKeys.length) return;

    _isScrolling.value = true;

    final keyContext = _categoryKeys[index].currentContext;
    if (keyContext != null) {
      // Get position information
      final RenderBox box = keyContext.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);

      // Calculate the target scroll position
      double targetScroll = 0;

      // Sum widths of all previous sections to get target scroll position
      for (int i = 0; i < index; i++) {
        final prevContext = _categoryKeys[i].currentContext;
        if (prevContext != null) {
          final prevBox = prevContext.findRenderObject() as RenderBox;
          targetScroll += prevBox.size.width;
        }
      }

      // Animate scroll to the target position
      _filterScrollController.animateTo(
        targetScroll,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Also scroll the category tabs to show the selected one
      _scrollCategoryIntoView(index, context);
    }

    Future.delayed(Duration(milliseconds: 350), () {
      _isScrolling.value = false;
    });
  }

  // Method to scroll category tabs to show the selected one
  void _scrollCategoryIntoView(int index, BuildContext context) {
    if (index < 0 || index >= _categoryKeys.length) return;

    final categoryContext = _categoryKeys[index].currentContext;
    if (categoryContext == null) return;

    final RenderBox box = categoryContext.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    // Get the position of the category tab in the category list
    final tabContext = _categoryKeys[index].currentContext;
    if (tabContext == null) return;

    // Create a RenderObject attached to the category tabs scroll view
    final RenderObject? renderObjectTab = _categoryScrollController.position.context.storageContext.findRenderObject();
    if (renderObjectTab == null) return;

    // Calculate the global position of the category tab
    final RenderBox tabRenderBox = tabContext.findRenderObject() as RenderBox;
    final tabPosition = tabRenderBox.localToGlobal(Offset.zero, ancestor: renderObjectTab);

    // Calculate target scroll position to center the tab
    double targetScroll = _categoryScrollController.offset;

    // If the tab is off-screen to the right
    if (tabPosition.dx + tabRenderBox.size.width > screenWidth) {
      targetScroll += (tabPosition.dx + tabRenderBox.size.width) - screenWidth + 16; // 16px padding
    }
    // If the tab is off-screen to the left
    else if (tabPosition.dx < 0) {
      targetScroll += tabPosition.dx - 16; // 16px padding
    }

    // Animate to the target position
    if (targetScroll != _categoryScrollController.offset) {
      _categoryScrollController.animateTo(
        targetScroll,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildBlockIcon(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          selectedCategoryIndex.value = -1; // Unselect category
          videoFilterController.selectedFilter.value = null; // Unselect filter
          videoFilterController.sliderValue.value = 0.0; // Reset slider value
        },
        child: SvgPicture.asset(
          'assets/icons/ban.svg',
          height: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      BuildContext context,
      String category,
      int index,
      GlobalKey key,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Obx(() {
        bool isSelected = selectedCategoryIndex.value == index;
        return InkWell(
          onTap: () {
            // Update selected category
            selectedCategoryIndex.value = index;

            // Scroll to corresponding filter section
            _scrollToCategory(index, context);
          },
          child: Text(
            category,
            style: TextStyle(
              color: isSelected ? ColorUtils.primaryColor : Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFilterSection(
      BuildContext context,
      String category,
      List<Map<String, dynamic>> filters,
      GlobalKey key,
      ) {
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: filters.map((filter) => _buildFilterTile(context, filter)).toList(),
      ),
    );
  }

  Widget _buildFilterTile(BuildContext context, Map<String, dynamic> filter) {
    final filterConfig = videoFilterController.getFilterConfig(
      filter: filter,
      value: filter['defaultValue'] as double,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Obx(() {
        bool isSelected = videoFilterController.selectedFilter.value?['name'] == filter['name'];

        return InkWell(
          onTap: () {
            videoFilterController.selectedFilter.value = filter;
            videoFilterController.sliderValue.value = filter['defaultValue'] as double;
          },
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isSelected ? ColorUtils.primaryColor : Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColorFiltered(
                    colorFilter: filterConfig['colorFilter'],
                    child: Image.asset(
                      "assets/images/filter.jpg",
                      fit: BoxFit.cover,
                      height: 80,
                      width: 80,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      filter['name'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}