import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/sendEmail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

void showContactNowDialog(
  BuildContext context, {
  String? phoneNumber,
  String? latitude,
  String? longitude,
  String? email,
  String? website, // Already included in the function signature
  required String videoId,
}) {
  final theme = Theme.of(context);
  final primaryColor = theme.primaryColor;

  // Get screen width for responsive sizing
  final screenWidth = MediaQuery.of(context).size.width;
  final dialogWidth = screenWidth < 400 ? screenWidth * 0.85 : 350.0;

  AwesomeDialog(
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.scale,
    dismissOnTouchOutside: true,
    dialogBackgroundColor: Colors.white,
    borderSide: BorderSide(color: primaryColor, width: 2),
    width: dialogWidth,
    body: SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(screenWidth < 350 ? 16.0 : 24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              spacing: 8,
              children: [
                Icon(
                  Icons.contact_phone_rounded,
                  color: primaryColor,
                  size: 28,
                ),
                Text(
                  'connect_with_us'.tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Contact options - Wrap for smaller screens
            _buildContactOptionsLayout(
              context: context,
              phoneNumber: phoneNumber,
              latitude: latitude,
              longitude: longitude,
              email: email,
              website: website,
              // Pass website to the layout
              smallScreen: screenWidth < 350,
              videoId: videoId,
            ),

            SizedBox(height: 20),

            // Divider
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            SizedBox(height: 16),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.grey.shade700,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  'close'.tr,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ).show();
}

Widget _buildContactOptionsLayout({
  required BuildContext context,
  required String? phoneNumber,
  required String? latitude,
  required String? longitude,
  required String? email,
  required String? website, // Add website parameter
  required bool smallScreen,
  required String videoId,
}) {
  // Count available options
  int optionCount = 0;
  if (phoneNumber != null && phoneNumber.isNotEmpty) optionCount++;
  if (latitude != null &&
      longitude != null &&
      latitude.isNotEmpty &&
      longitude.isNotEmpty)
    optionCount++;
  if (email != null && email.isNotEmpty) optionCount++;
  if (website != null && website.isNotEmpty)
    optionCount++; // Include website in count

  // For small screens or many options, use Wrap instead of Row
  if (smallScreen || optionCount > 2) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          _buildContactOption(
            context: context,
            icon: 'assets/images/whatsapp.png',
            label: 'whatsapp'.tr,
            onTap: () {
              Get.back();
              _launchWhatsApp(context, phoneNumber);
            },
            color: Color(0xFF25D366),
            smallScreen: smallScreen,
          ),
        if (latitude != null &&
            longitude != null &&
            latitude.isNotEmpty &&
            longitude.isNotEmpty)
          _buildContactOption(
            context: context,
            icon: 'assets/images/map.png',
            label: 'location'.tr,
            onTap: () {
              Get.back();
              _launchMaps(context, latitude, longitude);
            },
            color: Color(0xFF4285F4),
            smallScreen: smallScreen,
          ),
        if (email != null && email.isNotEmpty)
          _buildContactOption(
            context: context,
            icon: 'assets/images/email.png',
            label: 'email'.tr,
            onTap: () {
              Navigator.pop(context);
              Get.to(SendEmailContact(videoId: videoId));
            },
            color: Color(0xFFEA4335),
            smallScreen: smallScreen,
          ),
        if (website != null && website.isNotEmpty) // Add website option
          _buildContactOption(
            context: context,
            icon: 'assets/images/website.png',
            // Ensure you have a website icon
            label: 'website'.tr,
            onTap: () {
              Get.back();
              _launchWebsite(context, website); // Launch website
            },
            color: Color(0xFF4CAF50),
            // Choose a color for the website option
            smallScreen: smallScreen,
          ),
      ],
    );
  } else {
    // For larger screens with few options, use Row
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          _buildContactOption(
            context: context,
            icon: 'assets/images/whatsapp.png',
            label: 'whatsapp'.tr,
            onTap: () => _launchWhatsApp(context, phoneNumber),
            color: Color(0xFF25D366),
            smallScreen: smallScreen,
          ),
        if (latitude != null &&
            longitude != null &&
            latitude.isNotEmpty &&
            longitude.isNotEmpty)
          _buildContactOption(
            context: context,
            icon: 'assets/images/map.png',
            label: 'location'.tr,
            onTap: () => _launchMaps(context, latitude, longitude),
            color: Color(0xFF4285F4),
            smallScreen: smallScreen,
          ),
        if (email != null && email.isNotEmpty)
          _buildContactOption(
            context: context,
            icon: 'assets/images/email.png',
            label: 'email'.tr,
            onTap: () {
              Get.to(() => SendEmailContact(videoId: videoId));
            },
            color: Color(0xFFEA4335),
            smallScreen: smallScreen,
          ),
        if (website != null && website.isNotEmpty) // Add website option
          _buildContactOption(
            context: context,
            icon: 'assets/images/website.png',
            // Ensure you have a website icon
            label: 'website'.tr,
            onTap: () => _launchWebsite(context, website),
            // Launch website
            color: Color(0xFF4CAF50),
            // Choose a color for the website option
            smallScreen: smallScreen,
          ),
      ],
    );
  }
}

Widget _buildContactOption({
  required BuildContext context,
  required String icon,
  required String label,
  required Function() onTap,
  required Color color,
  required bool smallScreen,
}) {
  final double size = smallScreen ? 60.0 : 70.0;
  final double iconSize = smallScreen ? 30.0 : 36.0;
  final double fontSize = smallScreen ? 10.0 : 12.0;
  final double containerHeight = smallScreen ? 68.0 : 78.0;

  return SizedBox(
    width: size,
    height: containerHeight,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(smallScreen ? 6 : 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, width: iconSize, height: iconSize),
            SizedBox(height: smallScreen ? 4 : 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper methods for launching URLs
Future<void> _launchWhatsApp(BuildContext context, String phoneNumber) async {
  final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  final url = Uri.parse('https://wa.me/$cleanPhoneNumber');
  _launchUrl(context, url, 'WhatsApp');
}

Future<void> _launchMaps(
  BuildContext context,
  String latitude,
  String longitude,
) async {
  final url = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  _launchUrl(context, url, 'Google Maps');
}

Future<void> _launchWebsite(BuildContext context, String website) async {
  // Ensure the website URL has a scheme (http or https)
  String urlString = website;
  if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
    urlString = 'https://$urlString';
  }
  final url = Uri.parse(urlString);
  _launchUrl(context, url, 'Browser');
}

Future<void> _launchUrl(BuildContext context, Uri url, String appName) async {
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar(
        context,
        '$appName not installed or URL scheme unsupported',
      );
    }
  } catch (e) {
    _showErrorSnackBar(context, 'Error launching $appName: $e');
  }
}

void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red.shade700,
    ),
  );
}
