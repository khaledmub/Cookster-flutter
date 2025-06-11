import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

import '../../../appUtils/colorUtils.dart';
import '../../../loaders/pulseLoader.dart';
import '../../../services/apiClient.dart';

class PolicyScreen extends StatefulWidget {
  final int pageType; // 1 for Terms & Conditions, 2 for Privacy Policy

  const PolicyScreen({super.key, required this.pageType});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  late Future<Map<String, dynamic>> _policyDataFuture;

  @override
  void initState() {
    super.initState();
    _policyDataFuture = fetchPolicyData();
  }

  Future<Map<String, dynamic>> fetchPolicyData() async {
    String endpoint = "page?type=${widget.pageType}";
    final response = await ApiClient.getRequest(endpoint);

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['page'];
    } else {
      throw Exception("Failed to load policy data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _policyDataFuture,
      builder: (context, snapshot) {
        // Default title to show when waiting for data
        String title = '...';

        // Update title if data is available
        if (snapshot.hasData) {
          title = snapshot.data!['title'] ?? title;
        }

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(80),
            child: Container(
              padding: EdgeInsets.only(top: 20.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
                gradient: LinearGradient(
                  colors: [Color(0XFFFFD700), Color(0XFFFFFADC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Positioned(
                    left: Directionality.of(context) == TextDirection.rtl ? null : 16,
                    right: Directionality.of(context) == TextDirection.rtl ? 16 : null,
                    top: 25,
                    child: InkWell(
                      onTap: () {
                        Get.back();
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
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_back

                                : Icons.arrow_back
,
                            color: ColorUtils.darkBrown,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(
            child: PulseLogoLoader(
              logoPath: "assets/images/appIcon.png",
              size: 80,
            ),
          )
              : snapshot.hasError
              ? Center(child: Text("Error: ${snapshot.error}"))
              : !snapshot.hasData
              ? const Center(child: Text("No Data Available"))
              : _buildPolicyContent(snapshot.data!),
        );
      },
    );
  }

  Widget _buildPolicyContent(Map<String, dynamic> data) {
    String? subTitle = data['sub_title'];
    String description = data['description'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subTitle != null && subTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  subTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            HtmlWidget(description),
          ],
        ),
      ),
    );
  }
}