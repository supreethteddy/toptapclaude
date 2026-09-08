import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shortzz/common/controller/theme_controller.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/call_notification_manager.dart';
import 'package:shortzz/common/manager/internet_connection_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/video_memory_manager.dart';
import 'package:shortzz/common/manager/reactive_save_manager.dart';
import 'package:shortzz/common/manager/local_content_manager.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/common/service/settings_service.dart';
import 'package:shortzz/common/service/content_filter_service.dart';
import 'package:shortzz/common/widget/restart_widget.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/screen/splash_screen/splash_screen.dart';
import 'package:shortzz/utilities/theme_res.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] == 'call' && Platform.isAndroid) {
    await showBackgroundIncomingCallNotification(message);
  } else if (Platform.isIOS && message.data['type'] != 'call') {
    FirebaseNotificationManager.instance.showNotification(message);
  }
  Loggers.success("Handling background message: ${message.data}");
  print("✅ Background Message: ${message.data}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ FlutterError: ${details.exception}');
    Loggers.error('FlutterError: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    print('❌ Platform Error: $error');
    Loggers.error('Platform error: $error\n$stack');
    return true;
  };

  // --- MODIFIED TO FIX ZONE MISMATCH ---
  // The runZonedGuarded block was causing the Zone mismatch error.
  // We will perform the initializations directly and then call runApp.
  print('🔄 Initializing Firebase...');
  await Firebase.initializeApp();
  print('✅ Firebase initialized');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  print('🔄 Initializing GetStorage...');
  await GetStorage.init('shortzz');
  print('✅ GetStorage initialized');
  Get.put(ThemeController(), permanent: true);

  try {
    print('🔄 Initializing SubscriptionManager...');
    await SubscriptionManager.shared.initPlatformState();
    print('✅ SubscriptionManager initialized');
  } catch (e, st) {
    print('❌ SubscriptionManager init error: $e');
    Loggers.error('SubscriptionManager init error: $e\n$st');
  }


  try {
    print('🔄 Initializing Branch SDK...');
    await FlutterBranchSdk.init();
    print('✅ Branch SDK initialized');
  } catch (e, st) {
    print('❌ Branch SDK init error: $e');
    Loggers.error('Branch SDK init error: $e\n$st');
  }

  print('🔄 Registering Translations...');
  Get.put(DynamicTranslations());
  print('✅ Translations Registered');

  // Initialize Video Memory Manager
  print('🔄 Initializing Video Memory Manager...');
  Get.put(VideoMemoryManager(), permanent: true);
  print('✅ Video Memory Manager initialized');

  // Initialize Reactive Save Manager
  print('🔄 Initializing Reactive Save Manager...');
  Get.put(ReactiveSaveManager(), permanent: true);
  print('✅ Reactive Save Manager initialized');

  // Initialize Local Content Manager for missing APIs
  print('🔄 Initializing Local Content Manager...');
  Get.put(LocalContentManager(), permanent: true);
  print('✅ Local Content Manager initialized');

  // Initialize Settings Service with all settings controllers
  print('🔄 Initializing Settings Service...');
  Get.put(SettingsService(), permanent: true);
  print('✅ Settings Service initialized');

  // Initialize Content Filter Service
  print('🔄 Initializing Content Filter Service...');
  Get.put(ContentFilterService(), permanent: true);
  print('✅ Content Filter Service initialized');

  // Initialize Call Notification Manager for incoming call notifications
  print('🔄 Initializing Call Notification Manager...');
  try {
    await CallNotificationManager.instance.initialize();
    print('✅ Call Notification Manager initialized');
  } catch (e, st) {
    print('❌ Call Notification Manager init error: $e');
    Loggers.error('Call Notification Manager init error: $e\n$st');
  }

  print('🚀 Launching App...');
  runApp(const RestartWidget(child: MyApp()));
  // --- END OF MODIFICATION ---

  /*
  // --- ORIGINAL CODE ---
  runZonedGuarded(() async {
    print('🔄 Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    print('🔄 Initializing GetStorage...');
    await GetStorage.init('shortzz');
    print('✅ GetStorage initialized');
    Get.put(ThemeController(), permanent: true);

    try {
      print('🔄 Initializing SubscriptionManager...');
      await SubscriptionManager.shared.initPlatformState();
      print('✅ SubscriptionManager initialized');
    } catch (e, st) {
      print('❌ SubscriptionManager init error: $e');
      Loggers.error(
          'SubscriptionManager init error: $e\n$st');
    }


    try {
      print('🔄 Initializing Branch SDK...');
      await FlutterBranchSdk.init();
      print('✅ Branch SDK initialized');
    } catch (e, st) {
      print('❌ Branch SDK init error: $e');
      Loggers.error('Branch SDK init error: $e\n$st');
    }

    print('🔄 Registering Translations...');
    Get.put(DynamicTranslations());
    print('✅ Translations Registered');

    // Initialize Video Memory Manager
    print('🔄 Initializing Video Memory Manager...');
    Get.put(VideoMemoryManager(), permanent: true);
    print('✅ Video Memory Manager initialized');

    // Initialize Reactive Save Manager
    print('🔄 Initializing Reactive Save Manager...');
    Get.put(ReactiveSaveManager(), permanent: true);
    print('✅ Reactive Save Manager initialized');

    print('🚀 Launching App...');
    runApp(const RestartWidget(child: MyApp()));
  }, (error, stack) {
    print('❌ Uncaught Zone error: $error');
    Loggers.error('Uncaught Zone error: $error\n$stack');
  });
  // --- END OF ORIGINAL CODE ---
  */
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🔧 MyApp build triggered');

    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(() {
      print(
        '🔁 Rebuilding due to theme change: ${themeController.themeMode.value}',
      );

      return GetMaterialApp(
        builder: (context, child) =>
            ScrollConfiguration(behavior: MyBehavior(), child: child!),
        onReady: () {
          print('🌐 Listening for Internet Connection...');
          InternetConnectionManager.instance.listenNoInternetConnection();
        },
        translations: Get.find<DynamicTranslations>(),
        locale: Locale(SessionManager.instance.getLang()),
        fallbackLocale: Locale(SessionManager.instance.getFallbackLang()),
        themeMode: themeController.themeMode.value,
        darkTheme: ThemeRes.darkTheme(context),
        theme: ThemeRes.lightTheme(context),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      );
    });
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/**
 * The issue was in the complex BoxFit.cover coordinate conversion logic in the ffmpeg_video_service.dart file. The system was using overly complex calculations with offset adjustments that were incorrectly mapping UI coordinates to video coordinates.
 */

// Below is working code
// import 'dart:async';
// import 'dart:io';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// // import 'package:shortzz/common/controller/theme_controller.dart';
// import 'package:shortzz/common/manager/firebase_notification_manager.dart';
// import 'package:shortzz/common/manager/internet_connection_manager.dart';
// import 'package:shortzz/common/manager/logger.dart';
// import 'package:shortzz/common/manager/session_manager.dart';
// import 'package:shortzz/common/service/subscription/subscription_manager.dart';
// import 'package:shortzz/common/widget/restart_widget.dart';
// import 'package:shortzz/languages/dynamic_translations.dart';
// import 'package:shortzz/screen/splash_screen/splash_screen.dart';
// import 'package:shortzz/utilities/theme_res.dart';

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(
//     RemoteMessage message) async {
//   Loggers.success(
//       "Handling a background message: ${message.data}");
//   await Firebase.initializeApp();
//   if (Platform.isIOS) {
//     FirebaseNotificationManager.instance
//         .showNotification(message);
//   }
// }

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     await Firebase.initializeApp();

//     // Register background handler
//     FirebaseMessaging.onBackgroundMessage(
//         _firebaseMessagingBackgroundHandler);

//     await GetStorage.init('shortzz');

//     // Init RevenueCat (handle errors gracefully)
//     try {
//       await SubscriptionManager.shared.initPlatformState();
//     } catch (e, st) {
//       Loggers.error(
//           'SubscriptionManager init error: $e\n$st');
//     }

//     // Init Ads (ignore async wait if needed)
//     MobileAds.instance.initialize();

//     // Init Branch SDK
//     try {
//       await FlutterBranchSdk.init();
//     } catch (e, st) {
//       Loggers.error('Branch SDK init error: $e\n$st');
//     }

//     // Load Translations
//     Get.put(DynamicTranslations());

//     // Run app
//     runApp(const RestartWidget(child: MyApp()));
//   } catch (e, st) {
//     Loggers.error('Fatal crash during app startup $st');
//   }
// }

// // this is new main

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final ThemeController themeController =
//         Get.put(ThemeController());

//     return Obx(() => GetMaterialApp(
//           builder: (context, child) => ScrollConfiguration(
//               behavior: MyBehavior(), child: child!),
//           onReady: () {
//             InternetConnectionManager.instance
//                 .listenNoInternetConnection();
//           },
//           translations: Get.find<DynamicTranslations>(),
//           locale: Locale(SessionManager.instance.getLang()),
//           fallbackLocale: Locale(
//               SessionManager.instance.getFallbackLang()),
//           themeMode: themeController.themeMode.value,
//           darkTheme: ThemeRes.darkTheme(context),
//           theme: ThemeRes.lightTheme(context),
//           debugShowCheckedModeBanner: false,
//           home: const SplashScreen(),
//         ));
//   }
// }

// class MyBehavior extends ScrollBehavior {
//   @override
//   Widget buildOverscrollIndicator(BuildContext context,
//       Widget child, ScrollableDetails details) {
//     return child;
//   }
// }

// Below is the old main

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       builder: (context, child) => ScrollConfiguration(
//           behavior: MyBehavior(), child: child!),
//       onReady: () {
//         InternetConnectionManager.instance
//             .listenNoInternetConnection();
//       },
//       translations: Get.find<DynamicTranslations>(),
//       locale: Locale(SessionManager.instance.getLang()),
//       fallbackLocale:
//           Locale(SessionManager.instance.getFallbackLang()),
//       themeMode: ThemeMode.light,
//       darkTheme: ThemeRes.darkTheme(context),
//       theme: ThemeRes.lightTheme(context),
//       debugShowCheckedModeBanner: false,
//       home: const SplashScreen(),
//     );
//   }
// }
