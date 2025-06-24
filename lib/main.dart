import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/services/flutterNotificationService.dart';
import 'package:cookster/services/notificationServices.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'appRoutes/appRoutes.dart';
import 'locale/localizationServices.dart';
import 'modules/landing/landingController/landingController.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  // Check if the platform is Android 13+ (API 33+)
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      // Request permission if not already granted
      await Permission.notification.request();
    }
  }
}

Future<void> requestLocationPermission() async {
  // Check location permission status
  final status = await Permission.location.status;

  if (!status.isGranted) {
    // Request location permission if not granted
    final result = await Permission.location.request();

    if (result.isPermanentlyDenied) {
      // Inform user to enable permission from settings
      print(
        "Location permission permanently denied. Please enable it in settings.",
      );
      // Optionally, show a dialog or snackbar to guide the user
      // await openAppSettings(); // Uncomment to open settings
    } else if (result.isDenied) {
      print("Location permission denied.");
      // Optionally, retry or inform the user
    } else if (result.isGranted) {
      print("Location permission granted.");
    }
  } else {
    print("Location permission already granted.");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  await Firebase.initializeApp();

  await requestNotificationPermission();
  await requestLocationPermission();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission();
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
  } else {}

  await setupFirebaseMessaging();

  // Lock screen rotation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedLang = prefs.getString('selectedLanguage');

  // Set default locale based on saved preference or English
  Locale initialLocale =
      savedLang == "Arabic"
          ? LocalizationService.arabic
          : LocalizationService.english;

  // Check internet connection
  List<ConnectivityResult> connectivityResult =
      await Connectivity().checkConnectivity();
  bool hasInternet = connectivityResult != ConnectivityResult.none;

  runApp(MyApp(initialLocale: initialLocale, hasInternet: hasInternet));
}

Future<void> setupFirebaseMessaging() async {
  // FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request notification permissions
  // NotificationSettings settings = await messaging.requestPermission(
  //   alert: true,
  //   badge: true,
  //   sound: true,
  // );

  // Initialize notifications
  setupNotifications();
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  final bool hasInternet;

  const MyApp({
    super.key,
    required this.initialLocale,
    required this.hasInternet,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  bool _handlingDeepLink = false;
  bool _wasOnNoInternetScreen = false;
  String? _lastRouteBeforeNoInternet;

  @override
  void initState() {
    super.initState();
    _listenForConnectivity();

    // Track if we're starting with no internet
    _wasOnNoInternetScreen = !widget.hasInternet;
  }

  /// **🔹 Listen for Internet Connectivity Changes**
  void _listenForConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      bool hasInternet = results.any(
        (result) => result != ConnectivityResult.none,
      );

      // Only handle connectivity navigation if we're not handling a deep link
      if (!_handlingDeepLink) {
        if (hasInternet) {
          print("✅ Internet is connected");
          _handleInternetRestored();
        } else {
          print("🚫 No internet connection");
          _handleInternetLost();
        }
      }
    });
  }

  /// **🔹 Handle Internet Connection Restored**
  void _handleInternetRestored() {
    if (_wasOnNoInternetScreen) {
      // If we were on no internet screen, decide where to go
      if (_lastRouteBeforeNoInternet != null &&
          _lastRouteBeforeNoInternet != AppRoutes.splash &&
          _lastRouteBeforeNoInternet != AppRoutes.noInternet) {
        // Resume from where user was before losing internet
        print("Resuming to: $_lastRouteBeforeNoInternet");
        Get.offAllNamed(_lastRouteBeforeNoInternet!);
      } else {
        // Go to splash if no previous route or if it was splash
        Get.offAllNamed(AppRoutes.splash);
      }
      _wasOnNoInternetScreen = false;
    }
    // If we weren't on no internet screen, don't navigate automatically
    // Let the user continue where they were
  }

  /// **🔹 Handle Internet Connection Lost**
  void _handleInternetLost() {
    // Save current route before going to no internet screen
    String? currentRoute = Get.currentRoute;
    if (currentRoute != AppRoutes.noInternet &&
        currentRoute != AppRoutes.splash) {
      _lastRouteBeforeNoInternet = currentRoute;
    }

    _wasOnNoInternetScreen = true;

    // Pass the saved route to NoInternetScreen
    Get.offAllNamed(
      AppRoutes.noInternet,
      arguments: {'savedRoute': _lastRouteBeforeNoInternet},
    );
  }

  @override
  Widget build(BuildContext context) {
    String deviceLanguage = Platform.localeName;
    print("PRINTING THE DEVICE LANGUAGE: ${deviceLanguage}");

    // Initialize controllers only once
    // if (!Get.isRegistered<SignUpController>()) {
    //   Get.put(SignUpController(), permanent: true);
    // }
    if (!Get.isRegistered<NavBarController>()) {
      Get.put(NavBarController(), permanent: true);
    }

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cookster',
          translations: LocalizationService(),
          locale: widget.initialLocale,
          fallbackLocale: LocalizationService.english,
          theme: ThemeData(
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            fontFamily: "Lama",
            colorScheme: ColorScheme.fromSeed(
              seedColor: ColorUtils.primaryColor,
            ),
          ),
          // Track route changes to help with connectivity handling
          navigatorObservers: [
            GetObserver((routing) {
              if (routing?.current != null) {
                print("Navigated to: ${routing!.current}");
                // Update last route if it's not a connectivity-related route
                if (routing.current != AppRoutes.noInternet &&
                    routing.current != AppRoutes.splash) {
                  _lastRouteBeforeNoInternet = routing.current;
                }
              }
            }),
          ],
          initialRoute:
              _handlingDeepLink
                  ? null
                  : (widget.hasInternet
                      ? AppRoutes.splash
                      : AppRoutes.noInternet),
          getPages: AppRoutes.pages,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: Directionality(
                textDirection:
                    Get.locale?.languageCode == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}
