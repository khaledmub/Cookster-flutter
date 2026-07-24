import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../visitProfile/visitProfileView/visitProfileView.dart';
import '../searchController/searchController.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../appUtils/appCenterIcon.dart'; // For AppCenterIcon
import 'package:cookster/core/media/media_url_resolver.dart';
import '../searchModel/b2bUsersListModel.dart';

class B2bUsersList extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String country;
  final String city;

  const B2bUsersList({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.country,
    required this.city,
  });

  @override
  State<B2bUsersList> createState() => _B2bUsersListState();
}

class _B2bUsersListState extends State<B2bUsersList> {
  final UserSearchController userSearchController =
      Get.find<UserSearchController>();
  final TextEditingController _searchController = TextEditingController();
  String _language = 'en'; // Default to English
  Worker? _locationFilterWorker;
  Timer? _fetchDebounce;

  String? _avatarUrl(B2bAccountsList user) {
    final resolved = MediaUrlResolver.firstAbsolute([
      user.imageUrl,
      user.image?.toString(),
    ]);
    if (resolved != null) {
      return resolved;
    }
    return MediaUrlResolver.profileImageUrl(user.image?.toString());
  }

  @override
  void initState() {
    super.initState();
    print("Category ID: ${widget.categoryId}");
    print("Category Name: ${widget.categoryName}");
    _loadLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCategoryUsers();
    });
    _locationFilterWorker = ever(
      userSearchController.locationFilterRevision,
      (_) => _fetchCategoryUsers(),
    );
  }

  void _fetchCategoryUsers() {
    _fetchDebounce?.cancel();
    _fetchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      final country = userSearchController.locationFilterEnabled.value
          ? userSearchController.currentCountryId.value
          : widget.country;
      final city = userSearchController.locationFilterEnabled.value
          ? userSearchController.currentCityId.value
          : widget.city;
      userSearchController.fetchB2BUsersList(
        categoryId: int.parse(widget.categoryId),
        country: country,
        city: city,
      );
    });
  }

  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  void dispose() {
    _fetchDebounce?.cancel();
    _locationFilterWorker?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(155.h), // Adjusted height to fit content
        child: Container(
          padding: EdgeInsets.only(top: 30),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(30),
              bottomLeft: Radius.circular(30),
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFFADC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  // Back Button
                  Positioned(
                    left: isRtl ? null : 16,
                    right: isRtl ? 16 : null,
                    top: 10.h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => navigateBackFromContext(context),
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
                  // Center App Icon
                  AppCenterIcon(),
                ],
              ),
              // Search Field
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onTapOutside: (event) {
                    FocusScope.of(context).unfocus();
                  },
                  onChanged: (value) {
                    userSearchController.searchB2BUsers(value);
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    hintText: "Search".tr,
                    suffixIcon: InkWell(
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          userSearchController.searchB2BUsers(
                            _searchController.text,
                          );
                        }
                      },
                      child: Container(
                        height: 50,
                        width: 50,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(left: 4, right: 4),
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
      ),
      body: Obx(
        () =>
            userSearchController.isB2bUsersLoading.value
                ? const Center(child: CircularProgressIndicator())
                : userSearchController
                            .filteredB2bUsersList
                            .value
                            .b2bAccountsList ==
                        null ||
                    userSearchController
                        .filteredB2bUsersList
                        .value
                        .b2bAccountsList!
                        .isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/notfound.png", height: 250),
                        SizedBox(height: 16),
                        Text(
                          "${"no_b2b_found".tr} ${widget.categoryName} ",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ColorUtils.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (userSearchController.locationFilterEnabled.value &&
                            (userSearchController.currentCity.value.isNotEmpty ||
                                userSearchController
                                    .currentCountry
                                    .value
                                    .isNotEmpty)) ...[
                          SizedBox(height: 8.h),
                          Text(
                            [
                              userSearchController.currentCity.value,
                              userSearchController.currentCountry.value,
                            ].where((part) => part.isNotEmpty).join(', '),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ColorUtils.darkBrown.withValues(alpha: 0.6),
                              fontSize: 13.sp,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          if (userSearchController.currentCityId.value.isNotEmpty &&
                              userSearchController
                                  .currentCountry
                                  .value
                                  .isNotEmpty)
                            TextButton(
                              onPressed: () {
                                userSearchController.clearCityKeepCountry();
                                _fetchCategoryUsers();
                              },
                              child: Text(
                                '${userSearchController.currentCountry.value} — all cities',
                              ),
                            ),
                          TextButton(
                            onPressed: () {
                              userSearchController.clearLocationFilter();
                              _fetchCategoryUsers();
                            },
                            child: Text('clear_location_filter'.tr),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    // Business Type Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        widget.categoryName,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.darkBrown,
                        ),
                      ),
                    ),
                    // List of Users
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount:
                            userSearchController
                                .filteredB2bUsersList
                                .value
                                .b2bAccountsList!
                                .length,
                        itemBuilder: (context, index) {
                          final user =
                              userSearchController
                                  .filteredB2bUsersList
                                  .value
                                  .b2bAccountsList![index];
                          final avatarUrl = _avatarUrl(user);
                          return Material(
                            color: Colors.white,
                            elevation: 0,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.grey.shade300,
                                child: ClipOval(
                                  child: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                              title: Text(
                                user.name ?? "Unknown",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: PublicUserIdentity.subtitleHandle(
                                        user.userName,
                                      ) != null
                                  ? Text(
                                      PublicUserIdentity.formatAtHandle(
                                        user.userName,
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13.sp,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                Get.to(VisitProfileView(userId: user.id!));
                              },
                            ),
                          ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
