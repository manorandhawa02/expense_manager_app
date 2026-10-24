import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/app_lock_service.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  String? _error;
  bool _busy = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await AppLockService.isBiometricEnabled();

    if (mounted) {
      setState(() => _biometricEnabled = enabled);
    }
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();

    if (pin.length < 4 || pin.length > 6) {
      setState(() => _error = 'Enter your 4–6 digit PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final valid = await AppLockService.verifyPin(pin);

      if (!mounted) return;

      if (valid) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Incorrect PIN. Try again.');
        _pinController.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to verify PIN. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithFingerprint() async {
    if (!_biometricEnabled || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final available = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();

      if (!available || !supported) {
        if (mounted) {
          setState(() {
            _error = 'Fingerprint authentication is not available.';
          });
        }
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock Expense Manager',
       biometricOnly: true,
      );

      if (authenticated && mounted) {
        widget.onUnlocked();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Fingerprint authentication failed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 72),
                  const SizedBox(height: 20),
                  Text(
                    'Expense Manager Locked',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text('Enter your PIN to access your finances.'),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_busy,
                    onSubmitted: (_) => _unlockWithPin(),
                    decoration: const InputDecoration(
                      labelText: '4–6 digit PIN',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.password),
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _unlockWithPin,
                      child: const Text('Unlock'),
                    ),
                  ),
                  if (_biometricEnabled) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _unlockWithFingerprint,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Unlock with fingerprint'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}