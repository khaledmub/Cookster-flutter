import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/services/flutterNotificationService.dart';
import 'package:cookster/services/notificationServices.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'services/feature_flags/remote_config_service.dart';
import 'services/settings/settings_service.dart';

// Import firebase_options.dart if it exists
// import 'firebase_options.dart';

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
  await runZonedGuarded(() async {
    try {
      await Firebase.initializeApp();
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      await setupFirebaseMessaging();
      await RemoteConfigService.instance.initialize();
      await SettingsService.instance.load();
      if (!SettingsService.instance.dataSaverEnabled.value &&
          RemoteConfigService.instance.dataSaverDefault) {
        await SettingsService.instance.setDataSaver(true);
      }
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      print('Firebase initialization error: $e');
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedLang = prefs.getString('selectedLanguage');

    Locale initialLocale =
        savedLang == "Arabic"
            ? LocalizationService.arabic
            : LocalizationService.english;

    runApp(MyApp(initialLocale: initialLocale, hasInternet: true));
  }, (error, stack) async {
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> setupFirebaseMessaging() async {
  try {
    // Request permissions
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
      print('Firebase Messaging authorized');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('Firebase Messaging provisional authorization');
    } else {
      print('Firebase Messaging not authorized');
    }

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Setup notifications
    await setupNotifications();
  } catch (e) {
    print('Firebase Messaging setup error: $e');
  }
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
  late final AppLinks _appLinks;
  bool _handlingDeepLink = false;
  bool _wasOnNoInternetScreen = false;
  String? _lastRouteBeforeNoInternet;
  String? _pendingDeepLinkRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Request permissions
    requestNotificationPermission();
    requestLocationPermission();

    _wasOnNoInternetScreen = !widget.hasInternet;
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
        print('App resumed - clearing notification badge');
        clearNotificationBadge();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
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
    if (_handlingDeepLink) return;
    _handlingDeepLink = true;

    try {
      final uri = Uri.parse(link);
      final bool isCooksterDomain =
          uri.host == 'cookster.org' || uri.host == 'www.cookster.org';
      final bool isCooksterCustomScheme =
          uri.scheme == 'cookster' && uri.host == 'open.cookster.app';

      if (isCooksterDomain || isCooksterCustomScheme) {
        String? videoId = uri.queryParameters['id'];
        videoId ??= uri.queryParameters['videoId'];
        videoId ??= uri.queryParameters['video_id'];
        if ((videoId == null || videoId.isEmpty) && uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last;
          const reservedSegments = {'web', 'visitSingleVideo', 'video'};
          if (!reservedSegments.contains(lastSegment)) {
            videoId = lastSegment;
          }
        }

        if (widget.hasInternet && videoId != null && videoId.isNotEmpty) {
          final resolvedVideoId = videoId;
          if (Get.currentRoute != '/SingleVisitVideo') {
            Get.to(
              () => SingleVisitVideo(videoId: resolvedVideoId),
              arguments: resolvedVideoId,
              preventDuplicates: true,
            );
          }
        } else if (videoId != null && videoId.isNotEmpty) {
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
