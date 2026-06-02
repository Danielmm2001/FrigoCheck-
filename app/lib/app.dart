import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';

class FrigoCheckApp extends StatelessWidget {
  const FrigoCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FrigoCheck',
      theme: AppTheme.light(),
      home: const OnboardingScreen(),
    );
  }
}
