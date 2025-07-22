import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../blockedUsersController/blockedUsersController.dart';
import '../blockedUsersModel/blockedUsersModel.dart';

class BlockedUsersScreen extends StatefulWidget {
  final String userName;

  const BlockedUsersScreen({Key? key, required this.userName})
      : super(key: key);

  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BlockedUsersController _controller = Get.put(BlockedUsersController());
  bool _isSearching = false;
  String? userId;

  @override
  void initState() {
    super.initState();
    // Fetch blocked users data
    _controller.fetchBlockUsersList();
    fetchUserId();

    // Listen to search changes
    _searchController.addListener(_onSearchChanged);
  }

  fetchUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
      _controller.searchBlockedUsers(
        query,
      ); // Call controller's search function
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _controller.searchBlockedUsers(''); // Reset search
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            () =>
        _controller.isLoading.value
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
                  hintText: 'search_blocked_users'.tr,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[600],
                  ),
                  suffixIcon:
                  _isSearching
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
            const SizedBox(height: 16),
            // Blocked Users List
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return Obx(() {
      final users = _controller.filteredBlockedUsersList;
      if (users.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isSearching ? 'no_results_found'.tr : 'no_blocked_users'.tr,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isSearching) ...[
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

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];

          return InkWell(
            onTap: () {
              // Get.to(VisitProfileView(userId: user.id ?? ''));
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
                      child: Image.network(
                        '${Common.profileImage}/${user.image}',
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
                          user.name ?? '',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if ((user.email ?? '').isNotEmpty)
                          Container(
                            width: Get.width * 0.5,
                            child: Text(
                              user.email ?? '',
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
                  // Action Button
                  _buildActionButton(user),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildActionButton(BlockedUsers user) {
    return GestureDetector(
      onTap: () async {
        // Call unblock user method
        await _controller.unblockUser(userId!, user.id!);

        // Show snackbar

      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        ),
        child: Center(
          child: Text(
            'unblock'.tr,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
