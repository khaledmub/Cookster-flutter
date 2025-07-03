import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/modules/search/searchController/searchController.dart';
import 'package:cookster/modules/singleVideoView/singleVideoView.dart';
import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appRoutes/appRoutes.dart';
import '../../../appUtils/appUtils.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../loaders/pulseLoader.dart';
import '../../auth/signUp/signUpController/cityController.dart';
import '../../landing/landingController/landingController.dart';
import '../../landing/landingTabs/add/videoAddController/videoAddController.dart';
import '../../landing/landingTabs/home/homeController/homeController.dart';
import '../searchModel/b2bList.dart';
import '../searchModel/searchModel.dart';

class SearchView extends StatefulWidget {
  final String? tag; // Optional tag parameter
  int? isGeneral;
  int? isFollowing;

  SearchView({super.key, this.tag, this.isGeneral, this.isFollowing});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TextEditingController _searchController = TextEditingController();
  final UserSearchController searchController = Get.find();

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  // Debounce timer for search
  Timer? _debounce;

  String _language = 'en'; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _tabController = TabController(length: 4, vsync: this);
    _clearSearchData();

    // If tag is provided, set it in the text field and trigger search
    if (widget.tag != null && widget.tag!.isNotEmpty) {
      _searchController.text = widget.tag!;
      if (_searchController.text.length >= 3) {
        searchController.fetchSearchResults(
          isFollowing: widget.isFollowing,
          isGeneral: widget.isGeneral,
          _searchController.text,
        );
      }
    }
  }

  void _clearSearchData() {
    searchController.searchResult.value = SearchResult();
    searchController.b2bList.value = B2BList();
    searchController.filteredB2bList.value = B2BList();
    searchController.hasSearched.value = false;
    searchController.isLoading.value = false;
    // Optional: Clear search controller text if you want to start fresh
    // _searchController.clear();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel(); // Cancel debounce timer
    super.dispose();
  }

  // Debounced search function
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 3) {
        searchController.fetchSearchResults(
          isGeneral: widget.isGeneral,
          isFollowing: widget.isFollowing,

          query,
        );
      } else if (query.isEmpty) {
        // Clear results when search is empty
        searchController.clearSearchResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(183.h),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: 40.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                ),
                gradient: LinearGradient(
                  colors: [Color(0XFFFFD700), Color(0XFFFFFADC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      // Back Button on the Left
                      Positioned(
                        left: isRtl ? null : 16,
                        right: isRtl ? 16 : null,
                        top: 10.h,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            try {
                              print("Tapped");
                              Get.back();
                            } catch (e) {
                              print(e);
                            }
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6BE00),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                isRtl ? Icons.arrow_back : Icons.arrow_back,
                                color: ColorUtils.darkBrown,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: isRtl ? null : 16,
                        left: isRtl ? 16 : null,
                        top: 10.h,
                        child: InkWell(
                          onTap: () {
                            _showBottomSheet(context);
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFFE6BE00),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.tune,
                                color: ColorUtils.darkBrown,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AppCenterIcon(),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TabBar(
                      onTap: (index) {
                        if (index == 0) {
                          searchController.type.value = 1; // General Search
                        } else if (index == 1) {
                          searchController.type.value = 2; // Business Accounts
                        } else if (index == 2) {
                          searchController.type.value = 4; // Top Rated
                        } else if (index == 3) {
                          searchController.type.value = 5;
                          searchController.fetchB2BList();
                        } else if (_searchController.text.length >= 3) {
                          searchController.fetchSearchResults(
                            _searchController.text,
                            isGeneral: widget.isGeneral,
                            isFollowing: widget.isFollowing,
                          );
                        }
                      },
                      controller: _tabController,
                      indicatorColor: ColorUtils.darkBrown,
                      labelColor: ColorUtils.darkBrown,
                      unselectedLabelColor: ColorUtils.darkBrown,
                      labelStyle: TextStyle(
                        color: ColorUtils.darkBrown,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: ColorUtils.darkBrown,
                      enableFeedback: true,
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(text: "General Search".tr),
                        Tab(text: "business".tr),
                        Tab(text: "Top Rated".tr),
                        Tab(text: "B2B".tr),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      onTapOutside: (event) {
                        FocusScope.of(context).unfocus();
                      },
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) {
                        if (value.isNotEmpty &&
                            searchController.type.value != 5) {
                          searchController.fetchSearchResults(
                            isGeneral: widget.isGeneral,
                            isFollowing: widget.isFollowing,
                            value,
                          );
                        } else if (value.isNotEmpty &&
                            searchController.type.value == 5) {
                          searchController.searchB2BAccounts(value);
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        hintText: "Search".tr,
                        suffixIcon: InkWell(
                          onTap: () {
                            if (_searchController.text.isNotEmpty) {
                              if (searchController.type.value == 5) {
                                searchController.searchB2BAccounts(
                                  _searchController.text,
                                );
                              } else {
                                searchController.fetchSearchResults(
                                  isGeneral: widget.isGeneral,
                                  isFollowing: widget.isFollowing,
                                  _searchController.text,
                                );
                              }
                            }
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            padding: EdgeInsets.all(10),
                            margin: EdgeInsets.only(left: 4, right: 4),
                            decoration: BoxDecoration(
                              color: ColorUtils.darkBrown,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 24.sp,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(
                            color: ColorUtils.darkBrown,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(
                            color: ColorUtils.darkBrown,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        var videosList = searchController.searchResult.value.videos;
        var chefsList = searchController.searchResult.value.chefAccounts;
        var businessList = searchController.searchResult.value.businessAccounts;

        bool hasNoResults =
            searchController.hasSearched.value &&
            (videosList == null || videosList.isEmpty) &&
            (chefsList == null || chefsList.isEmpty) &&
            (businessList == null || businessList.isEmpty);

        bool hasNotSearchedYet = !searchController.hasSearched.value;

        if (searchController.type.value == 5) {
          return Obx(() {
            var businessTypes =
                searchController
                    .filteredB2bList
                    .value
                    .b2bAccountsList
                    ?.businessTypes;

            if (searchController.isLoading.value) {
              return Center(
                child: PulseLogoLoader(
                  logoPath: "assets/images/appIcon.png",
                  size: 80,
                ),
              );
            } else if (businessTypes == null ||
                businessTypes.isEmpty &&
                    (searchController.b2bList.value.b2bAccountsList == null ||
                        searchController
                            .b2bList
                            .value
                            .b2bAccountsList!
                            .businessTypes
                            .isEmpty)) {
              return _buildNoResultsFound();
            } else if (businessTypes.isEmpty &&
                _searchController.text.isNotEmpty) {
              return _buildNoResultsFound();
            } else {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      businessTypes.entries.map((entry) {
                        String businessType = entry.key;
                        List<BusinessAccount> businesses = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Business Type Header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                businessType,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),

                            // Business Accounts List
                            ...businesses.map((business) {
                              return InkWell(
                                onTap: () async {
                                  bool isAuthenticated =
                                      await _isUserAuthenticated();
                                  if (isAuthenticated) {
                                    Get.to(
                                      VisitProfileView(userId: business.id!),
                                    );
                                  } else {
                                    Get.toNamed(AppRoutes.signIn);
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Profile Picture
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              business.image != null &&
                                                      business.image!.isNotEmpty
                                                  ? '${Common.profileImage}/${business.image!}'
                                                  : "",
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (
                                                context,
                                                url,
                                                error,
                                              ) => Container(
                                                width: 60,
                                                height: 60,
                                                color: ColorUtils.primaryColor,
                                                child: Image.asset(
                                                  'assets/images/appIcon.png',
                                                  width: 30,
                                                  height: 30,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                          placeholder:
                                              (context, url) => Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.grey[300],
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.grey[700],
                                                      ),
                                                ),
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 12),

                                      // Business Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Business Name
                                            Text(
                                              business.name ??
                                                  "Unknown Business",
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4),

                                            // Business Email
                                            Text(
                                              business.email ??
                                                  "No email available",
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Optional: Add arrow icon
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),

                            SizedBox(height: 16.h),
                          ],
                        );
                      }).toList(),
                ),
              );
            }
          });
        } else if (searchController.isLoading.value) {
          return Center(
            child: PulseLogoLoader(
              logoPath: "assets/images/appIcon.png",
              size: 80,
            ),
          );
        } else if (hasNotSearchedYet && widget.tag == null) {
          return _buildInitialState();
        } else if (hasNoResults) {
          return _buildNoResultsFound();
        } else {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () =>
                      searchController.recentSearches.isNotEmpty
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      "recent_searches".tr,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(left: 16, right: 16),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.start,
                                  spacing: 8.0,
                                  children:
                                      searchController.recentSearches.map((
                                        search,
                                      ) {
                                        return InkWell(
                                          onTap: () {
                                            _searchController.text = search;
                                            searchController.fetchSearchResults(
                                              isGeneral: widget.isGeneral,
                                              search,
                                            );
                                          },
                                          child: Chip(
                                            label: Text(search),
                                            onDeleted: () {
                                              searchController
                                                  .removeSearchQuery(search);
                                            },
                                            backgroundColor: Colors.grey[200],
                                            labelStyle: TextStyle(
                                              color: Colors.black,
                                            ),
                                            deleteIcon: Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          )
                          : SizedBox(),
                ),
                if (videosList != null && videosList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16),
                        Text(
                          "Discover".tr,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1 / 1.2,
                              ),
                          itemCount: videosList.length,
                          itemBuilder: (context, index) {
                            var video = videosList[index];
                            return InkWell(
                              onTap: () async {
                                bool isAuthenticated =
                                    await _isUserAuthenticated();
                                if (isAuthenticated) {
                                  Get.to(
                                    SingleVideoScreen(
                                      followers:
                                          video.followersCount.toString(),
                                      frondUserId: video.frontUserId,
                                      userImage: video.userImage,
                                      videoId: video.id,
                                      videoUrl: video.video,
                                      title: video.title,
                                      image: video.image,
                                      allowComments: video.allowComments,
                                      description: video.description,
                                      tags: video.tags,
                                      userName: video.userName,
                                      createdAt: video.createdAt,
                                      contactEmail: video.contactEmail,
                                      contactPhone: video.contactPhone,
                                      latitude: video.latitude,
                                      longitude: video.longitude,
                                      takeOrder: video.takeOrder.toString(),
                                      website: video.website,
                                      isImage: video.isImage.toString(),
                                    ),
                                  );
                                } else {
                                  // Navigate to sign in page
                                  Get.toNamed(
                                    AppRoutes.signIn,
                                  ); // Make sure you have this route defined
                                }
                              },

                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl:
                                            video.image != null
                                                ? '${Common.videoUrl}/${video.image!}'
                                                : '',
                                        // Empty string if image is null
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        placeholder:
                                            (context, url) => const Center(
                                              child: Icon(
                                                Icons.image,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.heart_fill,
                                            color: Colors.white,
                                            size: 14.sp,
                                          ),
                                          SizedBox(width: 4),
                                          StreamBuilder<DocumentSnapshot>(
                                            stream:
                                                FirebaseFirestore.instance
                                                    .collection('videos')
                                                    .doc(video.id)
                                                    .snapshots(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData ||
                                                  !snapshot.data!.exists) {
                                                return Text(
                                                  "0",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                );
                                              }
                                              final data =
                                                  snapshot.data!.data()
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >? ??
                                                  {};
                                              List<dynamic> likes =
                                                  data['likes'] ?? [];
                                              int likeCount = likes.length;
                                              String formattedLikeCount =
                                                  likeCount > 1000
                                                      ? '${(likeCount / 1000).toStringAsFixed(1)}K'
                                                      : likeCount.toString();
                                              return Text(
                                                formattedLikeCount,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.sp,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (chefsList != null && chefsList.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Top Rated".tr,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        height: Get.height * 0.17,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: chefsList.length,
                          itemBuilder: (context, index) {
                            var chef = chefsList[index];
                            return InkWell(
                              onTap: () async {
                                bool isAuthenticated =
                                    await _isUserAuthenticated();
                                if (isAuthenticated) {
                                  Get.to(VisitProfileView(userId: chef.id!));
                                } else {
                                  // Navigate to sign in page
                                  Get.toNamed(
                                    AppRoutes.signIn,
                                  ); // Make sure you have this route defined
                                }
                              },
                              child: Container(
                                margin: EdgeInsets.only(left: 16),
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl:
                                            chef.image != null &&
                                                    chef.image!.isNotEmpty
                                                ? '${Common.profileImage}/${chef.image!}'
                                                : "",
                                        width: Get.height * 0.17,
                                        height: Get.height * 0.4,
                                        fit: BoxFit.cover,
                                        errorWidget:
                                            (context, url, error) => Container(
                                              color: ColorUtils.primaryColor,
                                              child: Image.asset(
                                                'assets/images/appIcon.png',
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        placeholder:
                                            (context, url) => Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[300],
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.grey[700],
                                                    ),
                                              ),
                                            ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(10),
                                            bottomRight: Radius.circular(10),
                                          ),
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                        child: Text(
                                          chef.name ?? "Unknown Chef",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                if (businessList != null && businessList.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Business Accounts".tr,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        height: Get.height * 0.17,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: businessList.length,
                          itemBuilder: (context, index) {
                            var business = businessList[index];
                            return InkWell(
                              onTap: () async {
                                bool isAuthenticated =
                                    await _isUserAuthenticated();
                                if (isAuthenticated) {
                                  Get.to(
                                    VisitProfileView(userId: business.id!),
                                  );
                                } else {
                                  // Navigate to sign in page
                                  Get.toNamed(
                                    AppRoutes.signIn,
                                  ); // Make sure you have this route defined
                                }
                              },
                              child: Container(
                                margin: EdgeInsets.only(left: 16),
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl:
                                            business.image != null &&
                                                    business.image!.isNotEmpty
                                                ? '${Common.profileImage}/${business.image!}'
                                                : "",
                                        width: Get.height * 0.17,
                                        height: Get.height * 0.4,
                                        fit: BoxFit.cover,
                                        errorWidget:
                                            (context, url, error) => Container(
                                              color: ColorUtils.primaryColor,
                                              child: Image.asset(
                                                'assets/images/appIcon.png',
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        placeholder:
                                            (context, url) => Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[300],
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.grey[700],
                                                    ),
                                              ),
                                            ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(10),
                                            bottomRight: Radius.circular(10),
                                          ),
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                        child: Text(
                                          business.name ?? "Unknown Business",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
              ],
            ),
          );
        }
      }),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/search_icon.png', height: 120, width: 120),
          SizedBox(height: 24),
          Text(
            textAlign: TextAlign.center,
            "search_video".tr,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: ColorUtils.darkBrown,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "type_at_least_search".tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/notfound.png', height: 200, width: 200),
          SizedBox(height: 16),
          Text(
            "no_results_found".tr,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: ColorUtils.darkBrown,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "search_not_found_result".tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    final CityController cityController = Get.find();
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                color: Colors.white,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter'.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    InkWell(
                      onTap: () {
                        showLocationDialog(context);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined),
                          SizedBox(width: 10),
                          Obx(
                            () => Text(
                              searchController.currentCountry.value == ""
                                  ? 'select_country_label'.tr
                                  : searchController.currentCountry.value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    SizedBox(height: 15),
                    InkWell(
                      onTap: () {
                        // Get the current city's ID from cityMap in cityController
                        int? initialCityId;
                        if (searchController.currentCity.value.isNotEmpty) {
                          Map<String, int> cityMap = {};
                          cityController.cityList.forEach((city) {
                            cityMap[city.name!] = city.id!;
                          });
                          initialCityId =
                              cityMap[searchController.currentCity.value];
                        }
                        showCityDialog(context, initialCity: initialCityId);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined),
                          SizedBox(width: 10),
                          Obx(
                            () => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              // Set your desired maximum width
                              child: Text(
                                searchController.currentCity.value == ""
                                    ? 'select_city_dialog_label'.tr
                                    : searchController.currentCity.value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow:
                                    TextOverflow
                                        .ellipsis, // Show ellipsis if text exceeds maxWidth
                              ),
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    AppButton(
                      text: "Submit",
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void showLocationDialog(BuildContext context, {int? initialCountryId}) {
    final NavBarController profileController = Get.find();

    final HomeController homeController = Get.find();
    final VideoAddController controller = Get.find();

    final CityController cityController = Get.find<CityController>();
    final UserSearchController searchControllerNew = Get.find();

    print("Initial Country ID: $initialCountryId");

    Map<String, int> countryMap = {};
    List<String> countryName =
        profileController.videoUploadSettings.value!.countries!.map((country) {
          countryMap[country.name!] = country.id!;
          return country.name!;
        }).toList();

    // Controller for search field
    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCountryName = countryName.obs;
    RxString selectedCountryName =
        (controller.selectedCountry.value.isNotEmpty
                ? controller.selectedCountry.value
                : '')
            .obs;
    // Set the initial selected country if provided
    if (initialCountryId != null) {
      String? countryNameForId =
          countryMap.entries
              .firstWhere(
                (entry) => entry.value == initialCountryId,
                orElse: () => MapEntry('', 0),
              )
              .key;
      if (countryNameForId.isNotEmpty) {
        selectedCountryName.value = countryNameForId;
      }
    }

    // Filter countries based on search input
    void filterCountries(String query) {
      if (query.isEmpty) {
        filteredCountryName.value = countryName;
      } else {
        filteredCountryName.value =
            countryName
                .where(
                  (country) =>
                      country.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          width: 350.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// **Header (Title + Close Button)**
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.black),
                      SizedBox(width: 8.w),
                      Text(
                        "select_country_label".tr,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    child: Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              /// **Search Field**
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'search_country_placeholder'.tr,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: ColorUtils.primaryColor),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10.h,
                    horizontal: 12.w,
                  ),
                ),
                onChanged: (value) => filterCountries(value),
              ),
              SizedBox(height: 16.h),

              /// **Scrollable Location List**
              Container(
                height: 230.h,
                child: SingleChildScrollView(
                  child: Obx(
                    () => Column(
                      children: List.generate(filteredCountryName.length, (
                        index,
                      ) {
                        String country = filteredCountryName[index];
                        bool isSelected = selectedCountryName.value == country;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                selectedCountryName.value = country;
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: 200.w,
                                      ),
                                      child: Text(
                                        country,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 20.w,
                                      height: 20.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: ColorUtils.primaryColor,
                                          width: 2,
                                        ),
                                        color:
                                            isSelected
                                                ? ColorUtils.primaryColor
                                                : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (index < filteredCountryName.length - 1)
                              Divider(
                                height: 1.h,
                                thickness: 1.r,
                                color: Colors.grey.shade300,
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              /// **Submit Button**
              Obx(
                () => ElevatedButton(
                  onPressed:
                      selectedCountryName.value.isNotEmpty
                          ? () async {
                            int? selectedId =
                                countryMap[selectedCountryName.value];
                            if (selectedId != null) {
                              searchControllerNew.currentCountry.value =
                                  selectedCountryName.value;
                              controller.selectLocation(
                                selectedCountryName.value,
                                selectedId,
                              );
                              homeController.currentCountry.value =
                                  selectedCountryName.value;
                              await cityController.fetchCities(selectedId);
                              Get.back(); // Close the country dialog
                              showCityDialog(context);
                            }
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    minimumSize: Size(double.infinity, 44.h),
                  ),
                  child: Text(
                    "Submit".tr,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showCityDialog(BuildContext context, {int? initialCity}) {
    final VideoAddController controller = Get.find();
    final CityController cityController = Get.find<CityController>();
    final UserSearchController homeController = Get.find();
    final HomeController homeUpdateController = Get.find();

    Map<String, int> cityMap = {};
    List<String> cityName =
        cityController.cityList.map((city) {
          cityMap[city.name!] = city.id!;
          return city.name!;
        }).toList();

    // Controller for search field
    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCityName = cityName.obs;
    RxString selectedCityName =
        (controller.selectedCity.value.isNotEmpty
                ? controller.selectedCity.value
                : '')
            .obs;

    // Pre-select city if initialCity is provided
    if (initialCity != null) {
      String? initialCityName =
          cityMap.entries
              .firstWhere(
                (entry) => entry.value == initialCity,
                orElse: () => MapEntry('', -1),
              )
              .key;
      if (initialCityName.isNotEmpty) {
        selectedCityName.value = initialCityName;
      }
    }

    // Filter cities based on search input
    void filterCities(String query) {
      if (query.isEmpty) {
        filteredCityName.value = cityName;
      } else {
        filteredCityName.value =
            cityName
                .where(
                  (city) => city.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Obx(
          () => Container(
            width: 350.w,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child:
                cityController.isLoading.value
                    ? Center(child: CircularProgressIndicator())
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// **Header (Title + Close Button)**
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.black),
                                SizedBox(width: 8.w),
                                Text(
                                  "Select City".tr,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => Get.back(),
                              child: Icon(Icons.close, color: Colors.grey),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),

                        /// **Search Field**
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'search_city_placeholder'.tr,
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide(
                                color: ColorUtils.primaryColor,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h,
                              horizontal: 12.w,
                            ),
                          ),
                          onChanged: (value) => filterCities(value),
                        ),
                        SizedBox(height: 16.h),

                        /// **Scrollable Location List**
                        Container(
                          height: 230.h,
                          child: SingleChildScrollView(
                            child: Obx(
                              () => Column(
                                children: List.generate(
                                  filteredCityName.length,
                                  (index) {
                                    String city = filteredCityName[index];
                                    bool isSelected =
                                        selectedCityName.value == city;

                                    return Column(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            selectedCityName.value = city;
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12.h,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxWidth: 200.w,
                                                  ),
                                                  child: Text(
                                                    city,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  width: 20.w,
                                                  height: 20.w,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          ColorUtils
                                                              .primaryColor,
                                                      width: 2,
                                                    ),
                                                    color:
                                                        isSelected
                                                            ? ColorUtils
                                                                .primaryColor
                                                            : Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        if (index < filteredCityName.length - 1)
                                          Divider(
                                            height: 1.h,
                                            thickness: 1.r,
                                            color: Colors.grey.shade300,
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),

                        /// **Submit Button**
                        Obx(
                          () => ElevatedButton(
                            onPressed:
                                selectedCityName.value.isNotEmpty
                                    ? () {
                                      try {
                                        int? selectedId =
                                            cityMap[selectedCityName.value];
                                        if (selectedId != null) {
                                          print(
                                            "Selected City: ${selectedCityName.value} (ID: $selectedId)",
                                          );
                                          homeController.currentCity.value =
                                              selectedCityName.value;
                                          homeUpdateController
                                              .currentCity
                                              .value = selectedCityName.value;
                                          controller.selectedCity.value =
                                              selectedCityName.value;
                                          homeController.currentCity.value =
                                              selectedCityName.value;
                                          homeUpdateController
                                              .currentCity
                                              .value = selectedCityName.value;

                                          Get.back(); // Close the city dialog
                                        }
                                      } catch (e) {
                                        print('Error selecting city: $e');
                                        Get.snackbar(
                                          'Error',
                                          'Failed to select city',
                                        );
                                      }
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              minimumSize: Size(double.infinity, 44.h),
                            ),
                            child: Text(
                              "Submit".tr,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
