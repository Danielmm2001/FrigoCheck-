class ApiConstants {
  // Android emulator uses 10.0.2.2 to reach the host machine.
  // Real Android device on same WiFi should use your laptop LAN IP, for example:
  static const baseUrl = 'http://192.168.1.30:8000';
  // static const baseUrl = 'http://10.0.2.2:8000';

  // Temporary user id until Supabase Auth is connected in Flutter.
  static const demoUserId = 'e49e5c2b-422a-48ed-b579-beaa735abe44';
}
