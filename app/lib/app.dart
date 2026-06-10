import 'package:flutter/material.dart';

import 'core/navigation/app_route_observer.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

class FrigoCheckApp extends StatelessWidget {
  const FrigoCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    const authService = AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FrigoCheck',
      theme: AppTheme.light(),
      navigatorObservers: [appRouteObserver],
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, _) {
          return authService.currentUser == null
              ? const OnboardingScreen()
              : const HomeScreen();
        },
      ),
    );
  }
}
