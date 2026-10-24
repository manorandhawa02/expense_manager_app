import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockService {
  AppLockService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _pinKey = 'expense_manager_app_lock_pin';
  static const String _enabledKey = 'expense_manager_app_lock_enabled';
  static const String _biometricKey = 'expense_manager_biometric_enabled';

  static Future<bool> isEnabled() async {
    return await _storage.read(key: _enabledKey) == 'true';
  }

  static Future<bool> hasPin() async {
    return await _storage.read(key: _pinKey) != null;
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  static Future<bool> verifyPin(String pin) async {
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin != null && savedPin == pin;
  }

  static Future<void> disable() async {
    await _storage.delete(key: _pinKey);
    await _storage.write(key: _enabledKey, value: 'false');
    await _storage.write(key: _biometricKey, value: 'false');
  }

  static Future<bool> isBiometricEnabled() async {
    return await _storage.read(key: _biometricKey) == 'true';
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricKey,
      value: enabled.toString(),
    );
  }
}