import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String keyEmail = 'saved_email';
  static const String keyUsername = 'saved_username';
  static const String keyPassword = 'saved_password';

  /// Salva email, username e password
  static Future<void> saveCredentials({
    required String email,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyEmail, email);
    await prefs.setString(keyUsername, username);
    await prefs.setString(keyPassword, password);
  }

  /// Recupera i dati salvati
  static Future<Map<String, String?>> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(keyEmail),
      'username': prefs.getString(keyUsername),
      'password': prefs.getString(keyPassword),
    };
  }

  /// Elimina i dati salvati (logout)
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyEmail);
    await prefs.remove(keyUsername);
    await prefs.remove(keyPassword);
  }
}
