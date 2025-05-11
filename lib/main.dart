import 'package:chatzilla/config/theme/app_theme.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/firebase_options.dart';
import 'package:chatzilla/presentation/screens/auth/login_screen.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  await setupServiceLocator();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white, // or transparent if you prefer
      statusBarBrightness: Brightness.light, // for iOS
      statusBarIconBrightness: Brightness.dark, // for Android
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatZilla',
      navigatorKey: getIt<AppRouter>().navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: LoginScreen(),
    );
  }
}
