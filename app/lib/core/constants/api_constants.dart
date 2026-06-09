class ApiConstants {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.30:8000',
  );

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Temporary user id until Supabase Auth is connected in Flutter.
  static const demoUserId = 'e49e5c2b-422a-48ed-b579-beaa735abe44';

  static bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
