import 'dart:convert';
import 'package:intl/intl.dart'; // Added for number formatting
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/auth/signUp/signUpController/signUpController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:urwaypayment/urwaypayment.dart';
import '../../../../appUtils/colorUtils.dart';
import 'package:flutter/material.dart' as dir;

class PackagesScreen extends StatefulWidget {
  @override
  _PackagesScreenState createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final SignUpController signUpController = Get.put(SignUpController());
  final CarouselSliderController _carouselController =
  CarouselSliderController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Select the first package by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final packages = signUpController.packagesList.value.packages ?? [];
      if (packages.isNotEmpty) {
        signUpController.selectPackage(packages[0].id!);
        setState(() {
          _currentIndex = 0; // Ensure carousel starts at the first item
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: ColorUtils.primaryColor,
      ),
      body: Obx(() {
        final packages = signUpController.packagesList.value.packages ?? [];
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(gradient: ColorUtils.goldGradient),
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 80.h),
                  Text(
                    'choose_your_plan'.tr,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: ColorUtils.darkBrown,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  ShaderMask(
                    shaderCallback: (Rect rect) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.1, 0.9, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: CarouselSlider(
                      carouselController: _carouselController,
                      options: CarouselOptions(
                        height: 320.h,
                        enlargeCenterPage: true,
                        enableInfiniteScroll: false,
                        autoPlay: false,
                        viewportFraction: 0.75,
                        initialPage: _currentIndex,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _currentIndex = index;
                            // Update selected package when carousel changes
                            signUpController.selectPackage(packages[index].id!);
                          });
                        },
                      ),
                      items:
                      packages
                          .map((package) => _buildPackageCard(package))
                          .toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:
                    packages.asMap().entries.map((entry) {
                      final index = entry.key;
                      return Container(
                        width: _currentIndex == index ? 12.w : 8.w,
                        height: _currentIndex == index ? 12.w : 8.w,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                          _currentIndex == index
                              ? ColorUtils.darkBrown
                              : ColorUtils.secondaryColor,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AppButton(
                      isLoading:
                      signUpController.isLoading.value ||
                          signUpController.isProfileCreating.value ||
                          signUpController.isPaymentLoading.value, // Added payment loading state
                      text: "activate_now".tr,
                      onTap: () async {
                        if (signUpController
                            .selectedPackageId
                            .value
                            .isNotEmpty) {
                          print(
                            "Selected Package ID: ${signUpController.selectedPackageId.value}",
                          );
                          print("EXECUTING THE PAYMENT PROCESS");
                          // First initiate payment
                          Map<String, dynamic>? paymentResult =
                          await initiatePayment(context);

                          if (paymentResult != null &&
                              paymentResult['success'] == true) {
                            // If payment is successful, then submit the form with payment parameters
                            signUpController.submitForm(
                              packageId:
                              signUpController.selectedPackageId.value,
                              paymentParams: paymentResult['paymentParams'],
                            );
                          } else {
                            // Payment failed, show error message
                            Get.snackbar("error".tr, "payment_failed".tr);
                          }
                        } else {
                          Get.snackbar("error".tr, "please_select_package".tr);
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
            Positioned(
              left:
              Directionality.of(context) == dir.TextDirection.rtl
                  ? null
                  : 16,
              right:
              Directionality.of(context) == dir.TextDirection.rtl
                  ? 16
                  : null,
              top: 20.h,
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6BE00),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Directionality.of(context) == dir.TextDirection.rtl
                          ? Icons.arrow_forward
                          : Icons.arrow_back,
                      color: ColorUtils.darkBrown,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    height: 50.h,
                    width: 50.h,
                    child: Image.asset("assets/images/appIconC.png"),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Future<Map<String, dynamic>?> initiatePayment(BuildContext context) async {
    try {
      signUpController.isPaymentLoading.value = true; // Set loading state
      final orderId = "SUB_${DateTime.now().millisecondsSinceEpoch}";
      final selectedPackage = signUpController.packagesList.value.packages!
          .firstWhere(
            (package) => package.id == signUpController.selectedPackageId.value,
      );

      String response = await Payment.makepaymentService(
        context: context,
        country: "Qatar",
        action: "1",
        currency: "SAR",
        amt: selectedPackage.amount.toString(),
        customerEmail: "",
        trackid: orderId,
        udf1: "",
        udf2: "",
        udf3: Directionality.of(context) == dir.TextDirection.rtl ? "AR" : "EN",
        udf4: "",
        udf5: "",
        metadata: '{"orderId":"$orderId","source":"FlutterApp"}',
        cardToken: "",
        address: "",
        city: "",
        state: "",
        tokenizationType: "0",
        zipCode: "",
        tokenOperation: "",
      );

      print("Raw Response: $response");

      if (response.isNotEmpty && response.trim().startsWith('{')) {
        Map<String, dynamic> jsonResponse = jsonDecode(response);
        print("PRINTING PAYMENT RESPONSE");
        print(jsonResponse);

        String? result = jsonResponse["Result"]?.toString().toLowerCase();
        final paymentParams = {
          "PaymentId": jsonResponse["PaymentId"]?.toString() ?? "",
          "TranId": jsonResponse["TranId"]?.toString() ?? "",
          "ECI": jsonResponse["ECI"]?.toString() ?? "",
          "TrackId": jsonResponse["TrackId"]?.toString() ?? "",
          "RRN": jsonResponse["RRN"]?.toString() ?? "",
          "cardBrand": jsonResponse["cardBrand"]?.toString() ?? "",
          "amount": jsonResponse["amount"]?.toString() ?? "",
          "maskedPAN": jsonResponse["maskedPAN"]?.toString() ?? "",
          "PaymentType": jsonResponse["PaymentType"]?.toString() ?? "",
        };

        print("PRINTING THE RESULT: $result");

        if (result == "successful") {
          signUpController.isPaymentLoading.value = false; // Reset loading state
          return {'success': true, 'paymentParams': paymentParams};
        } else {
          signUpController.isPaymentLoading.value = false; // Reset loading state
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("form_unknown_error".tr)));
          return {'success': false};
        }
      } else {
        throw Exception("Invalid response format: $response");
      }
    } catch (e) {
      print("PRINTING ERROR: $e");
      signUpController.isPaymentLoading.value = false; // Reset loading state
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("payment_cancelled".tr)));
      return {'success': false};
    }
  }

  Widget _buildPackageCard(dynamic package) {
    final SignUpController signUpController = Get.find<SignUpController>();
    // Create a number formatter for comma-separated numbers
    final NumberFormat numberFormat = NumberFormat("#,##0", "en_US");
    return Obx(() {
      bool isSelected = signUpController.selectedPackageId.value == package.id;
      return GestureDetector(
        onTap: () {
          signUpController.selectPackage(package.id);
          setState(() {
            _currentIndex = signUpController.packagesList.value.packages!
                .indexWhere((p) => p.id == package.id);
            _carouselController.animateToPage(
              _currentIndex,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(
              color: isSelected ? ColorUtils.darkBrown : Colors.transparent,
              width: isSelected ? 2.0 : 0.0,
            ),
          ),
          color:
          package.title == 'Best Seller'
              ? Colors.orange.shade100
              : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: ColorUtils.darkBrown,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        textAlign: TextAlign.center,
                        package.title ?? 'package_title_placeholder'.tr,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${signUpController.siteSettings.value!.settings!.currencySymbol} ${numberFormat.format(package.amount)}',
                  // Formatted price
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${package.duration} ${'package_duration_suffix'.tr}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 160.h),
                  child: SingleChildScrollView(
                    child: HtmlWidget(
                      package.description ?? '',
                      textStyle: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}