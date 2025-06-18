import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urwaypayment/urwaypayment.dart';
import '../../../services/apiClient.dart';
import '../promoteVideoModel/promoteVideoModel.dart';

class PromoteVideoController extends GetxController {
  var selectedDays = <String, int>{}.obs;
  var selectedCountry = "".obs;
  var selectedLocationId = 0.obs;
  var selectedCities = <String>[].obs;
  var selectedCityIds = <int>[].obs;
  var siteSettings = Rxn<SiteSettings>();
  var selectedVideoType = "Basic".obs;
  var validationErrors = <String, List<String>>{}.obs;
  var entity = 0.obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    print("LISTENING TO THIS");
    fetchSiteSettings();
    fetchEntity();
  }

  final entityDetails = Rx<Map<String, dynamic>>({});

  Future<void> fetchEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? entityDetailsJson = prefs.getString('entity_details');
    entityDetails.value =
        entityDetailsJson != null ? jsonDecode(entityDetailsJson) : {};
    print('Fetched entity_details: ${entityDetails.value}');
  }

  void selectLocation(String location, int stateId) {
    selectedCountry.value = location;
    selectedLocationId.value = stateId;
    print("Selected Location: ${selectedCountry.value} (ID: $stateId)");
  }

  void toggleCity(String city, int cityId) {
    if (selectedCities.contains(city)) {
      selectedCities.remove(city);
      selectedCityIds.remove(cityId);
    } else {
      selectedCities.add(city);
      selectedCityIds.add(cityId);
    }

    if (selectedCities.length > 0) {
      validationErrors["cities"] = [];
    } else {
      validationErrors["cities"] = ["Please select at least one city".tr];
    }
    print(
      "Selected Cities: ${selectedCities.toList()} (IDs: ${selectedCityIds.toList()})",
    );
  }

  void clearCities() {
    selectedCities.clear();
    selectedCityIds.clear();
  }

  final List<int> daysOptions = List.generate(30, (index) => index + 1);

  void setDays(String videoId, int days) {
    selectedDays[videoId] = days;
    selectedDays.refresh();
  }

  int getDays(String videoId) {
    return selectedDays[videoId] ?? 1;
  }

  void setVideoType(String type) {
    selectedVideoType.value = type;
    print("Selected Video Type: $type");
  }

  Future<void> fetchSiteSettings() async {
    try {
      final response = await ApiClient.getRequest('${EndPoints.siteSettings}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        siteSettings.value = SiteSettings.fromJson(jsonData);
        print(
          "Site Settings Fetched: ${siteSettings.value?.settings?.toJson()}",
        );
      } else {
        print("Failed to fetch site settings: ${response.statusCode}");
        Get.snackbar("Error", "Failed to fetch site settings");
      }
    } catch (e) {
      print("Error fetching site settings: $e");
      Get.snackbar("Error", "An error occurred while fetching site settings");
    }
  }

  // Calculate base price (before discount)
  // Calculate base price (before discount)
  double calculateBasePrice(String videoId) {
    if (siteSettings.value == null || siteSettings.value!.settings == null) {
      return 0.0;
    }

    final days = getDays(videoId);
    final numberOfCities =
        selectedCities.length; // Get the number of selected cities
    final settings = siteSettings.value!.settings!;
    final price =
        selectedVideoType.value == "Basic"
            ? (settings.basicSponsoredVideoPrice is num
                ? settings.basicSponsoredVideoPrice.toDouble()
                : double.tryParse(
                      settings.basicSponsoredVideoPrice?.toString() ?? "0",
                    ) ??
                    0.0)
            : (settings.premiumSponsoredVideoPrice is num
                ? settings.premiumSponsoredVideoPrice.toDouble()
                : double.tryParse(
                      settings.premiumSponsoredVideoPrice?.toString() ?? "0",
                    ) ??
                    0.0);

    // Updated formula: price * number of cities * days
    final basePrice = price * numberOfCities * days;
    print(
      "Base Price Calculation: Price (SAR $price) * Cities ($numberOfCities) * Days ($days) = SAR $basePrice",
    );
    return basePrice;
  }

  // Calculate total price (after discount)
  double calculateTotalPrice(String videoId) {
    if (siteSettings.value == null || siteSettings.value!.settings == null) {
      return 0.0;
    }

    final basePrice = calculateBasePrice(videoId);
    double totalPrice = basePrice;

    // Apply discount if subscription_required is 1
    if (entityDetails.value['subscription_required'] == 1) {
      final settings = siteSettings.value!.settings!;
      final discountPercentage =
          settings.sponsorVideoDiscount is num
              ? settings.sponsorVideoDiscount.toDouble()
              : double.tryParse(
                    settings.sponsorVideoDiscount?.toString() ?? "0",
                  ) ??
                  0.0;
      final discountAmount = basePrice * (discountPercentage / 100);
      totalPrice -= discountAmount;
    }

    // Ensure total price is not negative
    final finalPrice = totalPrice < 0 ? 0.0 : totalPrice;
    print(
      "Calculated Total Price for Video $videoId: SAR $finalPrice (Base: $basePrice, Discount: ${entityDetails.value['subscription_required'] == 1 ? (siteSettings.value!.settings!.sponsorVideoDiscount ?? 0) : 0}%)",
    );
    return finalPrice;
  }

  // Calculate discount amount for display
  double calculateDiscountAmount(String videoId) {
    print(
      "Calculated Discount Amount for Video $videoId: SAR ${entityDetails.value['subscription_required'] == 1 ? (siteSettings.value!.settings!.sponsorVideoDiscount ?? 0) : 0}%",
    );

    if (entityDetails.value['subscription_required'] != 1 ||
        siteSettings.value == null ||
        siteSettings.value!.settings == null) {
      return 0.0;
    }

    final basePrice = calculateBasePrice(videoId);
    final settings = siteSettings.value!.settings!;
    final discountPercentage =
        settings.sponsorVideoDiscount is num
            ? settings.sponsorVideoDiscount.toDouble()
            : double.tryParse(
                  settings.sponsorVideoDiscount?.toString() ?? "0",
                ) ??
                0.0;
    return basePrice * (discountPercentage / 100);
  }

  Future<bool> initiatePayment(String videoId, BuildContext context) async {
    try {
      // Set loading state to true at the start
      isLoading.value = true;

      final orderId = "PRO_${DateTime.now().millisecondsSinceEpoch}";

      String response = await Payment.makepaymentService(
        context: context,
        country: selectedCountry.value,
        action: "1",
        currency: "USD",
        amt: calculateTotalPrice(videoId).toString(),
        customerEmail: "",
        trackid: orderId,
        udf1: "",
        udf2: "",
        udf3: Directionality.of(context) == TextDirection.rtl ? "AR" : "EN",
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
          // Call promoteVideo and pass isLoading management to it
          bool success = await promoteVideo(videoId, context, paymentParams);
          // isLoading is managed in promoteVideo, so no need to set it here
          return success;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("form_unknown_error".tr)),
          );
          isLoading.value = false; // Reset loading state on failure
          return false;
        }
      } else {
        throw Exception("Invalid response format: $response");
      }
    } catch (e) {
      print("PRINTING ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("payment_cancelled".tr)),
      );
      isLoading.value = false; // Reset loading state on error
      return false;
    }
  }

  Future<bool> promoteVideo(
      String videoId,
      BuildContext context,
      Map<String, String> paymentParams,
      ) async {
    // isLoading is already true from initiatePayment, no need to set it again
    try {
      validationErrors.clear();
      final sponsorType = selectedVideoType.value == "Basic" ? 1 : 2;

      final data = {
        "video_id": videoId,
        "cities": selectedCityIds.join(","),
        "sponsor_type": sponsorType,
        "days": getDays(videoId),
        "total_price": calculateTotalPrice(videoId),
        "discount_applied":
        entityDetails.value['subscription_required'] == 1
            ? (siteSettings.value?.settings?.sponsorVideoDiscount is num
            ? siteSettings.value!.settings!.sponsorVideoDiscount.toDouble()
            : double.tryParse(
          siteSettings.value?.settings?.sponsorVideoDiscount
              ?.toString() ??
              "0",
        ) ??
            0.0)
            : 0.0,
        // Add payment parameters to the payload
        "PaymentId": paymentParams["PaymentId"],
        "TranId": paymentParams["TranId"],
        "ECI": paymentParams["ECI"],
        "TrackId": paymentParams["TrackId"],
        "RRN": paymentParams["RRN"],
        "cardBrand": paymentParams["cardBrand"],
        "amount": paymentParams["amount"],
        "maskedPAN": paymentParams["maskedPAN"],
        "PaymentType": paymentParams["PaymentType"],
      };

      print("Promoted Video Data: $data");

      final response = await ApiClient.postRequest(
        '${EndPoints.sponsorVideo}',
        data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Video promoted successfully: ${response.body}");
        resetController();
        final responseData = jsonDecode(response.body);

        final message = responseData['message'] ?? "video_promote_success".tr;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(message),
            duration: Duration(seconds: 2),
          ),
        );

        isLoading.value = false; // Reset loading state on success
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        print(responseData);

        if (responseData['status'] == false) {
          if (responseData['errors'] != null &&
              responseData['errors'].isNotEmpty) {
            validationErrors.value =
                responseData['errors'].map((key, value) {
                  return MapEntry(
                    key,
                    (value as List).map((e) => e.toString()).toList(),
                  );
                }).cast<String, List<String>>();
          } else {
            validationErrors.value = {
              'general': [responseData['message'] ?? 'An error occurred.'],
            };
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                validationErrors.value['general']?.first ??
                    'An error occurred.',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An unexpected error occurred.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        print(
          "Failed to promote video: ${response.statusCode} - ${response.body}",
        );
        isLoading.value = false; // Reset loading state on failure
        return false;
      }
    } catch (e) {
      print("Error promoting video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      isLoading.value = false; // Reset loading state on error
      return false;
    }
  }

  // Reset controller state after successful promotion
  void resetController() {
    selectedDays.clear();
    selectedCountry.value = "";
    selectedLocationId.value = 0;
    selectedCities.clear();
    selectedCityIds.clear();
    selectedVideoType.value = "Basic";
    validationErrors.clear();
    isLoading.value = false;
    print("Controller state reset: All fields cleared");
  }
}
