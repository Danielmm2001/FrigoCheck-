import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/api_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (ApiConstants.hasSupabaseConfig) {
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      anonKey: ApiConstants.supabaseAnonKey,
    );
  }

  runApp(const FrigoCheckApp());
}
