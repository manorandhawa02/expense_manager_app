
import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/app_lock/app_lock_screen.dart';
import 'app_lock_service.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({
    super.key,
    required this.child,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  static const Duration _lockDelay = Duration(seconds: 20);

  bool _enabled = false;
  bool _locked = false;
  bool _ready = false;
  bool _checkingStorage = false;

  DateTime? _backgroundedAt;
  Timer? _backgroundTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    if (_checkingStorage) return;
    _checkingStorage = true;

    try {
      final enabled = await AppLockService.isEnabled();
      final hasPin = await AppLockService.hasPin();

      if (!mounted) return;

      final shouldEnable = enabled && hasPin;

      setState(() {
        _enabled = shouldEnable;
        _locked = shouldEnable;
        _ready = true;
      });
    } catch (error) {
      debugPrint('App lock state error: $error');

      if (mounted) {
        setState(() {
          _enabled = false;
          _locked = false;
          _ready = true;
        });
      }
    } finally {
      _checkingStorage = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();

      _backgroundTimer ??= Timer(_lockDelay, () {
        if (mounted && _enabled) {
          setState(() => _locked = true);
        }
      });
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
      _backgroundTimer = null;

      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;

      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >= _lockDelay) {
        if (_enabled && mounted) {
          setState(() => _locked = true);
        }
      }

      // Refresh in case App Lock was changed in Settings.
      _refreshLockSettings();
    }
  }

  Future<void> _refreshLockSettings() async {
    try {
      final enabled = await AppLockService.isEnabled();
      final hasPin = await AppLockService.hasPin();

      if (!mounted) return;

      final shouldEnable = enabled && hasPin;

      setState(() {
        _enabled = shouldEnable;
        if (!shouldEnable) {
          _locked = false;
        }
      });
    } catch (error) {
      debugPrint('App lock refresh error: $error');
    }
  }

  void _unlock() {
    if (!mounted) return;
    setState(() => _locked = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Material(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_enabled && _locked)
          Positioned.fill(
            child: AppLockScreen(onUnlocked: _unlock),
          ),
      ],
    );
  }
}
