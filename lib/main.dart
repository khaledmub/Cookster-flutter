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
import 'modules/singleVideoVisit/singleVideoVisit.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }
}

Future<void> requestLocationPermission() async {
  final status = await Permission.location.status;

  if (!status.isGranted) {
    final result = await Permission.location.request();

    if (result.isPermanentlyDenied) {
      print(
        "Location permission permanently denied. Please enable it in settings.",
      );
    } else if (result.isDenied) {
      print("Location permission denied.");
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

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedLang = prefs.getString('selectedLanguage');

  Locale initialLocale =
      savedLang == "Arabic"
          ? LocalizationService.arabic
          : LocalizationService.english;

  List<ConnectivityResult> connectivityResult =
      await Connectivity().checkConnectivity();
  bool hasInternet = connectivityResult != ConnectivityResult.none;

  runApp(MyApp(initialLocale: initialLocale, hasInternet: hasInternet));
}

Future<void> setupFirebaseMessaging() async {
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
  // Remove the navigator key completely - GetX handles navigation
  late final AppLinks _appLinks;
  bool _handlingDeepLink = false;
  bool _wasOnNoInternetScreen = false;
  String? _lastRouteBeforeNoInternet;
  String? _pendingDeepLinkRoute;
  bool _initialRouteSet = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();

    _listenForConnectivity();
    _initializeDeepLinking();

    _wasOnNoInternetScreen = !widget.hasInternet;
    _initialRouteSet = true;
  }

  /// Initialize deep linking
  void _initializeDeepLinking() {
    // Handle initial deep link (when app is launched from terminated state)
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) {
            print('🔗 Initial deep link: $uri');
            _handleDeepLink(uri);
          }
        })
        .catchError((err) {
          print('❌ Initial deep link error: $err');
        });

    // Handle deep links when app is already running
    _appLinks.uriLinkStream.listen(
      (uri) {
        print('🔗 Stream deep link: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('❌ Deep link stream error: $err');
      },
    );
  }

  /// Handle deep link navigation
  Future<void> _handleDeepLink(Uri uri) async {
    try {
      _handlingDeepLink = true;

      final videoId = uri.queryParameters['id'];
      if (videoId != null && videoId.isNotEmpty) {
        print('🎥 Processing video ID: $videoId');

        bool isAuthenticated = await _isUserAuthenticated();

        // Wait for GetX to be initialized
        await _waitForGetXInitialization();

        // Check if already on the target route to avoid duplicate navigation
        if (Get.currentRoute == AppRoutes.landing ||
            Get.currentRoute == AppRoutes.signIn) {
          print('Already on ${Get.currentRoute}, skipping navigation');
          return;
        }

        if (isAuthenticated) {
          // Navigate to landing only if not already there
          if (Get.currentRoute != AppRoutes.landing) {
            Get.offAllNamed(AppRoutes.landing);
          }

          // Small delay to ensure landing screen is loaded
          await Future.delayed(const Duration(milliseconds: 300));

          // Navigate to video only if not already there
          if (Get.currentRoute != '/SingleVisitVideo') {
            Get.to(
              () => SingleVisitVideo(videoId: videoId),
              arguments: videoId,
              preventDuplicates: true,
            );
          }
        } else {
          // Navigate to sign-in only if not already there
          if (Get.currentRoute != AppRoutes.signIn) {
            Get.offAllNamed(
              AppRoutes.signIn,
              arguments: {'deepLinkVideoId': videoId},
            );
          }
        }
      } else {
        print('❌ Invalid or missing video ID in deep link');
        await _waitForGetXInitialization();
        _showErrorSnackbar('Invalid video ID in deep link');
      }
    } catch (e) {
      print('❌ Deep link handling error: $e');
      await _waitForGetXInitialization();
      _showErrorSnackbar('Error processing deep link');
    } finally {
      _handlingDeepLink = false;
    }
  }

  /// Wait for GetX to be properly initialized
  Future<void> _waitForGetXInitialization() async {
    int attempts = 0;
    while (Get.context == null && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (Get.context == null) {
      print('⚠️ GetX context still null after waiting');
    }
  }

  /// Check if user is authenticated
  Future<bool> _isUserAuthenticated() async {
    try {
      // Add your authentication check logic here
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Authentication check error: $e');
      return false;
    }
  }

  /// Show error snackbar
  void _showErrorSnackbar(String message) {
    if (Get.context != null) {
      Get.snackbar(
        'Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
    } else {
      print('⚠️ Cannot show snackbar - GetX context is null');
    }
  }

  /// Listen for Internet Connectivity Changes
  void _listenForConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      bool hasInternet = results.any(
        (result) => result != ConnectivityResult.none,
      );

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

  /// Handle Internet Connection Restored
  void _handleInternetRestored() {
    if (_wasOnNoInternetScreen) {
      if (_lastRouteBeforeNoInternet != null &&
          _lastRouteBeforeNoInternet != AppRoutes.splash &&
          _lastRouteBeforeNoInternet != AppRoutes.noInternet &&
          Get.currentRoute != _lastRouteBeforeNoInternet) {
        print("Resuming to: $_lastRouteBeforeNoInternet");
        Get.offAllNamed(_lastRouteBeforeNoInternet!);
      } else if (Get.currentRoute != AppRoutes.splash) {
        Get.offAllNamed(AppRoutes.splash);
      }
      _wasOnNoInternetScreen = false;

      // Handle pending deep link if exists
      if (_pendingDeepLinkRoute != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (Get.currentRoute != '/SingleVisitVideo') {
            Get.to(
              () => SingleVisitVideo(videoId: _pendingDeepLinkRoute!),
              arguments: _pendingDeepLinkRoute,
              preventDuplicates: true,
            );
          }
          _pendingDeepLinkRoute = null;
        });
      }
    }
  }

  /// Handle Internet Connection Lost
  void _handleInternetLost() {
    String? currentRoute = Get.currentRoute;
    if (currentRoute != AppRoutes.noInternet &&
        currentRoute != AppRoutes.splash) {
      _lastRouteBeforeNoInternet = currentRoute;
    }

    _wasOnNoInternetScreen = true;

    Get.offAllNamed(
      AppRoutes.noInternet,
      arguments: {'savedRoute': _lastRouteBeforeNoInternet},
    );
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String deviceLanguage = Platform.localeName;
    print("PRINTING THE DEVICE LANGUAGE: $deviceLanguage");

    // Initialize controllers only once
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
          // Remove navigatorKey - GetX manages its own navigation
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
          // navigatorObservers: [
          //   GetObserver((routing) {
          //     if (routing?.current != null) {
          //       print(
          //         "Navigated to: ${routing!.current} (Previous: ${routing.previous}, Args: ${routing.args})",
          //       );
          //       if (routing.current != AppRoutes.noInternet &&
          //           routing.current != AppRoutes.splash) {
          //         _lastRouteBeforeNoInternet = routing.current;
          //       }
          //     }
          //   }),
          // ],
          initialRoute:
              widget.hasInternet ? AppRoutes.splash : AppRoutes.noInternet,
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
