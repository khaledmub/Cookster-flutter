import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../../loaders/pulseLoader.dart';
import '../followersFollowingController/followersFollowingController.dart';
import '../followersListModel/followersListModel.dart';

enum SocialTab { followers, following }

class SocialListsScreen extends StatefulWidget {
  final String userName;
  final String userId;
  final SocialTab initialTab;

  const SocialListsScreen({
    Key? key,
    required this.userName,
    required this.userId,
    this.initialTab = SocialTab.followers,
  }) : super(key: key);

  @override
  _SocialListsScreenState createState() => _SocialListsScreenState();
}

class _SocialListsScreenState extends State<SocialListsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late final SocialListsController _controller;

  // Use RxList for reactive filtered lists
  final RxList<FFUser> _filteredFollowers = <FFUser>[].obs;
  final RxList<FFUser> _filteredFollowing = <FFUser>[].obs;
  final RxBool _isSearching = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == SocialTab.followers ? 0 : 1,
    );

    // Initialize controller with a unique tag based on userId
    _controller = Get.put(SocialListsController(), tag: widget.userId);

    // Clear existing data in the controller
    // _controller.followers.clear();
    // _controller.following.clear();
    // _filteredFollowers.clear();
    // _filteredFollowing.clear();

    // Fetch data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.fetchSocialData(widget.userId);
    });

    // Listen to search changes
    _searchController.addListener(_onSearchChanged);

    // Listen to controller updates reactively
    ever(_controller.followers, (List<FFUser> followers) {
      _filteredFollowers.assignAll(followers);
      if (_isSearching.value) _onSearchChanged();
    });
    ever(_controller.following, (List<FFUser> following) {
      _filteredFollowing.assignAll(following);
      if (_isSearching.value) _onSearchChanged();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    _isSearching.value = query.isNotEmpty;

    if (query.isEmpty) {
      _filteredFollowers.assignAll(_controller.followers);
      _filteredFollowing.assignAll(_controller.following);
    } else {
      _filteredFollowers.assignAll(
        _controller.followers.where((follower) {
          final name = (follower.name ?? '').toLowerCase();
          final email = (follower.email ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList(),
      );
      _filteredFollowing.assignAll(
        _controller.following.where((follow) {
          final name = (follow.name ?? '').toLowerCase();
          final email = (follow.email ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList(),
      );
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _isSearching.value = false;
    _filteredFollowers.assignAll(_controller.followers);
    _filteredFollowing.assignAll(_controller.following);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    Get.delete<SocialListsController>(tag: widget.userId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.userName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Obx(
            () => _controller.isLoading.value
            ? Center(
          child: PulseLogoLoader(
            logoPath: "assets/images/appIconC.png",
          ),
        )
            : _controller.errorMessage.isNotEmpty
            ? Center(child: Text(_controller.errorMessage.value))
            : Column(
          children: [
            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'search_followers_following'.tr,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[600],
                  ),
                  suffixIcon: _isSearching.value
                      ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: Color(0xFFFFD700),
                    ),
                    onPressed: _clearSearch,
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(25),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[700],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    child: Obx(
                          () => Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${_filteredFollowers.length} ${"Followers".tr}',
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    child: Obx(
                          () => Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${_filteredFollowing.length} ${"Following".tr}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab dachContent
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Obx(
                        () => _buildUserList(
                      _filteredFollowers,
                      isFollowers: true,
                    ),
                  ),
                  Obx(
                        () => _buildUserList(
                      _filteredFollowing,
                      isFollowers: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(List<FFUser> users, {required bool isFollowers}) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isSearching.value
                  ? 'no_results_found'.tr
                  : isFollowers
                  ? 'no_followers'.tr
                  : 'no_following'.tr,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_isSearching.value) ...[
              const SizedBox(height: 8),
              Text(
                'try_different'.tr,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance()
          .then((prefs) => prefs.getString('user_id')),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUserId = snapshot.data;
        final showActionButton = currentUserId == widget.userId;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];

            return InkWell(
              onTap: () {
                Get.to(() => VisitProfileView(userId: user.id));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: user.image != null
                            ? Image.network(
                          '${Common.profileImage}/${user.image!}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                            );
                          },
                        )
                            : Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.person,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (user.email.isNotEmpty)
                            Container(
                              width: Get.width * 0.5,
                              child: Text(
                                user.email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Action Button (conditionally shown)
                    if (showActionButton) _buildActionButton(user, isFollowers),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(FFUser user, bool isFollowers) {
    return GestureDetector(
      onTap: () async {
        // Call toggleFollowStatus and wait for completion
        isFollowers
            ? await _controller.removeFollower(user.id)
            : await _controller.toggleFollowStatus(user.id);

        // Update the local lists to remove the user
        if (isFollowers) {
          _filteredFollowers.removeWhere((follower) => follower.id == user.id);
          _controller.followers
              .removeWhere((follower) => follower.id == user.id);
        } else {
          _filteredFollowing.removeWhere((follow) => follow.id == user.id);
          _controller.following.removeWhere((follow) => follow.id == user.id);
        }

        // Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFollowers
                  ? '${"removed".tr} ${user.name}'
                  : '${"unfollowed".tr} ${user.name}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFFD700),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isFollowers ? Colors.white : const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        ),
        child: Center(
          child: Text(
            isFollowers ? 'remove'.tr : 'Following'.tr,
            style: TextStyle(
              color: isFollowers ? const Color(0xFFFFD700) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}