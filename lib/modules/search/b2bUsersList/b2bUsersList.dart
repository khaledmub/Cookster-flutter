import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/modules/visitProfile/visitProfileModel/visitProfileModel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../visitProfile/visitProfileView/visitProfileView.dart';
import '../searchController/searchController.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../appUtils/appCenterIcon.dart'; // For AppCenterIcon

class B2bUsersList extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const B2bUsersList({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<B2bUsersList> createState() => _B2bUsersListState();
}

class _B2bUsersListState extends State<B2bUsersList> {
  final UserSearchController userSearchController =
      Get.find<UserSearchController>();
  final TextEditingController _searchController = TextEditingController();
  String _language = 'en'; // Default to English

  @override
  void initState() {
    super.initState();
    print("Category ID: ${widget.categoryId}");
    print("Category Name: ${widget.categoryName}");
    _loadLanguage();
    // Schedule the fetch operation after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userSearchController.fetchB2BUsersList(
        categoryId: int.parse(widget.categoryId),
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
          padding: EdgeInsets.only(top: 40.h),
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
                      onTap: () {
                        try {
                          Get.back();
                        } catch (e) {
                          print("Error navigating back: $e");
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
            userSearchController.isLoading.value
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/images/notfound.png", height: 250),
                      SizedBox(height: 16),
                      Text(
                        "${"no_b2b_found".tr} ${widget.categoryName} ",
                        style: TextStyle(
                          color: ColorUtils.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
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
                              leading:
                                  user.image != null && user.image != ""
                                      ? CircleAvatar(
                                        backgroundImage: CachedNetworkImageProvider(
                                          user.image!.contains('http')
                                              ? user.image!
                                              : '${Common.profileImage}/${user.image!}',
                                        ),
                                        radius: 25,
                                        onBackgroundImageError: (
                                          exception,
                                          stackTrace,
                                        ) {
                                          print("Image load error: $exception");
                                        },
                                      )
                                      : const CircleAvatar(
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
                                        radius: 25,
                                      ),
                              title: Text(
                                user.name ?? "Unknown",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user.email != null &&
                                      user.email!.isNotEmpty)
                                    Text("${user.email}"),
                                  if (user.phone != null &&
                                      user.phone!.isNotEmpty)
                                    Text("${user.phone}"),
                                ],
                              ),
                              onTap: () {
                                Get.to(VisitProfileView(userId: user.id!));
                              },
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
