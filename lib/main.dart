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

  NotificationSettings settings = await FirebaseMessaging.instance
      .requestPermission(
        badge: true,
        alert: true,
        announcement: true,
        carPlay: true,
        criticalAlert: true,
        sound: true,
      );
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
  } else {}

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

  // List<ConnectivityResult> connectivityResult =
  //     await Connectivity().checkConnectivity();
  // bool hasInternet = connectivityResult != ConnectivityResult.none;

  runApp(MyApp(initialLocale: initialLocale, hasInternet: true));
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Remove the navigator key completely - GetX handles navigation
  late final AppLinks _appLinks;
  bool _handlingDeepLink = false;
  bool _wasOnNoInternetScreen = false;
  String? _lastRouteBeforeNoInternet;
  String? _pendingDeepLinkRoute;

  // bool _initialRouteSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupNotifications();

    _wasOnNoInternetScreen = !widget.hasInternet;
    // _initialRouteSet = true;
    _appLinks = AppLinks();
    // Handle initial deep link when the app is launched
    _handleInitialDeepLink();

    // Listen for incoming deep links when the app is running
    _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri.toString());
        }
      },
      onError: (err) {
        print('Error in uriLinkStream: $err');
      },
    );

    // _listenForConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - clear badge
        print('App resumed - clearing notification badge');
        clearNotificationBadge();
        break;
      case AppLifecycleState.inactive:
        // App is inactive
        break;
      case AppLifecycleState.paused:
        // App is paused
        break;
      case AppLifecycleState.detached:
        // App is detached
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  /// Handle initial deep link when the app is launched
  Future<void> _handleInitialDeepLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }

  /// Handle deep link navigation
  void _handleDeepLink(String link) {
    if (_handlingDeepLink)
      return; // Prevent multiple simultaneous deep link handling
    _handlingDeepLink = true;

    try {
      // Example: Parse the deep link (e.g., https://cookster.org/video/123)
      final uri = Uri.parse(link);
      if (uri.host == 'cookster.org') {
        final videoId = uri.queryParameters['id'];
        if (widget.hasInternet) {
          // Navigate immediately if internet is available
          if (Get.currentRoute != '/SingleVisitVideo') {
            // Get.to(
            //   () => SingleVisitVideo(videoId: videoId!),
            //   arguments: videoId,
            //   preventDuplicates: true,
            // );
          }
        } else {
          // Store pending deep link if no internet
          _pendingDeepLinkRoute = videoId;
          Get.offAllNamed(AppRoutes.noInternet);
        }
      }
    } catch (e) {
      print('Error handling deep link: $e');
    } finally {
      _handlingDeepLink = false;
    }
  }

  /// Listen for Internet Connectivity Changes
  // void _listenForConnectivity() {
  //   Connectivity().onConnectivityChanged.listen((
  //     List<ConnectivityResult> results,
  //   ) {
  //     bool hasInternet = results.any(
  //       (result) => result != ConnectivityResult.none,
  //     );
  //
  //     if (!_handlingDeepLink) {
  //       if (hasInternet) {
  //         print("✅ Internet is connected");
  //         _handleInternetRestored();
  //       } else {
  //         print("🚫 No internet connection");
  //         _handleInternetLost();
  //       }
  //     }
  //   });
  // }

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
  // void _handleInternetLost() {
  //   String? currentRoute = Get.currentRoute;
  //   if (currentRoute != AppRoutes.noInternet &&
  //       currentRoute != AppRoutes.splash) {
  //     _lastRouteBeforeNoInternet = currentRoute;
  //   }
  //
  //   _wasOnNoInternetScreen = true;
  //
  //   Get.offAllNamed(
  //     AppRoutes.noInternet,
  //     arguments: {'savedRoute': _lastRouteBeforeNoInternet},
  //   );
  // }

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
          navigatorObservers: [
            GetObserver((routing) {
              if (routing?.current != null) {
                print(
                  "Navigated to: ${routing!.current} (Previous: ${routing.previous}, Args: ${routing.args})",
                );
                if (routing.current != AppRoutes.noInternet &&
                    routing.current != AppRoutes.splash) {
                  _lastRouteBeforeNoInternet = routing.current;
                }
              }
            }),
          ],
          initialRoute: AppRoutes.splash,
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
