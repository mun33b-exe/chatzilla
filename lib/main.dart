import 'package:chatzilla/SplashScreen.dart';
import 'package:chatzilla/config/theme/app_theme.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/firebase_options.dart';
import 'package:chatzilla/logic/observer/app_life_cycle_observer.dart';
import 'package:chatzilla/presentation/screens/auth/login_screen.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  await setupServiceLocator();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppLifeCycleObserver? _appLifeCycleObserver;

  @override
  void initState() {
    super.initState();
    _initializeAppLifeCycleObserver();
  }

  void _initializeAppLifeCycleObserver() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        if (_appLifeCycleObserver != null) {
          WidgetsBinding.instance.removeObserver(_appLifeCycleObserver!);
        }

        _appLifeCycleObserver = AppLifeCycleObserver(
          userId: user.uid,
          chatRepository: getIt<ChatRepository>(),
        );
        WidgetsBinding.instance.addObserver(_appLifeCycleObserver!);
      } else {
        if (_appLifeCycleObserver != null) {
          WidgetsBinding.instance.removeObserver(_appLifeCycleObserver!);
        }
        _appLifeCycleObserver = null;
      }
    });
  }

  @override
  void dispose() {
    if (_appLifeCycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_appLifeCycleObserver!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatZilla',
      navigatorKey: getIt<AppRouter>().navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(),
    );
  }
}
