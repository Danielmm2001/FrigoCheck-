import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

class FrigoCheckApp extends StatelessWidget {
  const FrigoCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = const AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FrigoCheck',
      theme: AppTheme.light(),
      home: authService.currentUser == null ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
