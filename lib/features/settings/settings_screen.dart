
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/theme/app_colors.dart';
import '../transaction/transaction_storage.dart';
import 'backup_service.dart';
import 'profile_storage.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function()? onTransactionsCleared;

  const SettingsScreen({
    super.key,
    this.onTransactionsCleared,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _profileName = 'Mano';

  bool _dailyReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool _reminderSettingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfileName();
    _loadReminderSettings();
  }

  // --------------------------------------------------
  // APP LOCK
  // --------------------------------------------------

  Future<void> _enableAppLock() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Create App Lock PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Create 4–6 digit PIN',
                ),
              ),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = pinController.text;
                final confirmation = confirmController.text;

                if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN must contain 4–6 digits.'),
                    ),
                  );
                  return;
                }

                if (pin != confirmation) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PINs do not match.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      );

      if (result != true || !mounted) return;

      await AppLockService.setPin(pinController.text);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App Lock enabled successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not enable App Lock: $error'),
        ),
      );
    } finally {
      pinController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _disableAppLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable App Lock?'),
        content: const Text(
          'Your app will no longer require a PIN or fingerprint to open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AppLockService.disable();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App Lock disabled.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not disable App Lock: $error'),
        ),
      );
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    try {
      if (enabled) {
        final auth = LocalAuthentication();
        final canCheck = await auth.canCheckBiometrics;
        final supported = await auth.isDeviceSupported();
        final biometrics =
            canCheck ? await auth.getAvailableBiometrics() : <BiometricType>[];

        if (!supported || biometrics.isEmpty) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No enrolled fingerprint or supported biometric is available.',
              ),
            ),
          );
          return;
        }

        // Verify that the enrolled biometric actually works before enabling it.
        final authenticated = await auth.authenticate(
          localizedReason: 'Verify your identity to enable fingerprint unlock',
          biometricOnly: true,
        );

        if (!authenticated) return;
      }

      await AppLockService.setBiometricEnabled(enabled);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Fingerprint unlock enabled.'
                : 'Fingerprint unlock disabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update fingerprint setting: $error'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // DAILY REMINDER
  // --------------------------------------------------

  Future<void> _loadReminderSettings() async {
    try {
      final service = NotificationService.instance;

      final enabled = await service.isDailyReminderEnabled();
      final hour = await service.getReminderHour();
      final minute = await service.getReminderMinute();

      if (!mounted) return;

      setState(() {
        _dailyReminderEnabled = enabled;
        _reminderTime = TimeOfDay(hour: hour, minute: minute);
        _reminderSettingsLoaded = true;
      });
    } catch (error) {
      debugPrint('Reminder settings loading failed: $error');

      if (!mounted) return;

      setState(() {
        _reminderSettingsLoaded = true;
      });
    }
  }

  Future<void> _toggleDailyReminder(bool enabled) async {
    try {
      if (enabled) {
        final granted =
            await NotificationService.instance.requestPermission();

        if (!mounted) return;

        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please allow notifications in your device settings.',
              ),
            ),
          );
          return;
        }

        await NotificationService.instance.scheduleDailyReminder(
          hour: _reminderTime.hour,
          minute: _reminderTime.minute,
        );
      } else {
        await NotificationService.instance.cancelDailyReminder();
      }

      if (!mounted) return;

      setState(() => _dailyReminderEnabled = enabled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Daily reminder enabled.'
                : 'Daily reminder disabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update reminder: $error'),
        ),
      );
    }
  }

  Future<void> _selectReminderTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );

    if (selectedTime == null || !mounted) return;

    try {
      if (_dailyReminderEnabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: selectedTime.hour,
          minute: selectedTime.minute,
        );
      }

      if (!mounted) return;

      setState(() => _reminderTime = selectedTime);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder time set to ${selectedTime.format(context)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update reminder time: $error'),
        ),
      );
    }
  }

  Future<void> _testNotification() async {
    try {
      final granted =
          await NotificationService.instance.requestPermission();

      if (!mounted) return;

      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission was not granted. '
              'Check your device settings.',
            ),
          ),
        );
        return;
      }

      await NotificationService.instance.showTestNotification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Notification test failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification test failed: $error'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // BACKUP AND EXPORT
  // --------------------------------------------------

  Future<void> _exportBackup() async {
    try {
      final file = await BackupService.exportBackup();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Expense Manager Backup',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Backup export failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup export failed: $error'),
        ),
      );
    }
  }

  Future<void> _exportCsv() async {
    try {
      final file = await BackupService.exportTransactionsCsv();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Expense Manager Transactions',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('CSV export failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV export failed: $error'),
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Restoring replaces the saved data covered by the backup. '
          'Export your current data first to keep a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) return;

      final selected = files.first;
      final String content;

      if (selected.path != null) {
        content = await File(selected.path!).readAsString(
          encoding: utf8,
        );
      } else {
        throw const FormatException(
          'Unable to read the selected backup file.',
        );
      }

      await BackupService.restoreBackup(content);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup restored successfully. Reopen the app '
            'if some screens do not refresh automatically.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Backup restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $error'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // PROFILE
  // --------------------------------------------------

  Future<void> _loadProfileName() async {
    try {
      final name = await ProfileStorage.getName();

      if (!mounted) return;

      setState(() {
        _profileName = name;
      });
    } catch (error) {
      debugPrint('Profile loading failed: $error');
    }
  }

  Future<void> _editProfileName() async {
    final controller = TextEditingController(text: _profileName);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty || !mounted) return;

    try {
      await ProfileStorage.saveName(name);
      final savedName = await ProfileStorage.getName();

      if (!mounted) return;

      setState(() {
        _profileName = savedName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name saved successfully.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Name save failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Name save error: $error'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // SETTINGS SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.backgroundFor(context),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // PROFILE AND DISPLAY
          _buildSectionTitle(context, 'Profile & display'),
          const SizedBox(height: 12),

          _buildSettingsCard(context, [
            _buildSettingsTile(
              context: context,
              icon: Icons.person_outline,
              title: 'Your name',
              subtitle: _profileName,
              onTap: _editProfileName,
            ),
            _buildDivider(context),
            _buildSettingsTile(
              context: context,
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Customize your app theme',
              onTap: () => _showAppearanceDialog(context),
            ),
            _buildDivider(context),
            _buildSettingsTile(
              context: context,
              icon: Icons.currency_exchange_rounded,
              title: 'Currency',
              subtitle: 'Choose your preferred currency',
              onTap: () => _showCurrencyDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // NOTIFICATIONS: TEST
          _buildSectionTitle(context, 'Notifications'),
          const SizedBox(height: 12),

          _buildSettingsCard(context, [
            _buildSettingsTile(
              context: context,
              icon: Icons.notifications_active_outlined,
              title: 'Test Notification',
              subtitle: 'Check that notifications work on this device',
              onTap: _testNotification,
            ),
          ]),

          const SizedBox(height: 24),

          // NOTIFICATIONS: DAILY REMINDER
          _buildSectionTitle(context, 'Daily reminder'),
          const SizedBox(height: 12),

          _buildSettingsCard(context, [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Daily expense reminder'),
              subtitle: Text(
                _reminderSettingsLoaded
                    ? 'Remind me daily at ${_reminderTime.format(context)}'
                    : 'Loading reminder settings...',
              ),
              value: _dailyReminderEnabled,
              onChanged: _reminderSettingsLoaded
                  ? _toggleDailyReminder
                  : null,
            ),
            _buildDivider(context),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.access_time),
              title: const Text('Reminder time'),
              subtitle: Text(_reminderTime.format(context)),
              trailing: const Icon(Icons.chevron_right),
              enabled: _reminderSettingsLoaded,
              onTap: _reminderSettingsLoaded ? _selectReminderTime : null,
            ),
          ]),

          const SizedBox(height: 24),

          // SECURITY: APP LOCK AND BIOMETRICS
          _buildSectionTitle(context, 'Security'),
          const SizedBox(height: 12),

          FutureBuilder<bool>(
            future: AppLockService.isEnabled(),
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              return _buildSettingsCard(context, [
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('App Lock'),
                  subtitle: const Text(
                    'Protect your financial information with a PIN',
                  ),
                  value: enabled,
                  onChanged: isLoading
                      ? null
                      : (value) async {
                          if (value) {
                            await _enableAppLock();
                          } else {
                            await _disableAppLock();
                          }
                        },
                ),
                if (enabled) ...[
                  _buildDivider(context),
                  FutureBuilder<bool>(
                    future: AppLockService.isBiometricEnabled(),
                    builder: (context, biometricSnapshot) {
                      final biometricEnabled =
                          biometricSnapshot.data ?? false;

                      return SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Fingerprint unlock'),
                        subtitle: const Text(
                          'Use your enrolled fingerprint',
                        ),
                        value: biometricEnabled,
                        onChanged:
                            biometricSnapshot.connectionState ==
                                    ConnectionState.waiting
                                ? null
                                : _toggleBiometric,
                      );
                    },
                  ),
                ],
              ]);
            },
          ),

          const SizedBox(height: 24),

          // DATA MANAGEMENT
          _buildSectionTitle(context, 'Data Management'),
          const SizedBox(height: 12),

          _buildSettingsCard(context, [
            _buildSettingsTile(
              context: context,
              icon: Icons.backup_outlined,
              title: 'Export Backup',
              subtitle: 'Save your app data as a JSON file',
              onTap: _exportBackup,
            ),
            _buildDivider(context),
            _buildSettingsTile(
              context: context,
              icon: Icons.restore_rounded,
              title: 'Restore Backup',
              subtitle: 'Restore data from a JSON backup',
              onTap: _restoreBackup,
            ),
            _buildDivider(context),
            _buildSettingsTile(
              context: context,
              icon: Icons.file_download_outlined,
              title: 'Export Transactions',
              subtitle: 'Export transactions to a CSV file',
              onTap: _exportCsv,
            ),
            _buildDivider(context),
            _buildSettingsTile(
              context: context,
              icon: Icons.storage_rounded,
              title: 'Local Storage',
              subtitle: 'Your data is stored on this device',
              onTap: () => _showStorageInfo(context),
            ),
            _buildDivider(context),
            _buildSettingsTile(
              context: context,
              icon: Icons.delete_outline_rounded,
              title: 'Clear Data',
              subtitle: 'Remove saved personal transactions',
              iconColor: Colors.redAccent,
              onTap: () => _confirmClearData(context),
            ),
          ]),

          const SizedBox(height: 24),

          // ABOUT
          _buildSectionTitle(context, 'About'),
          const SizedBox(height: 12),

          _buildSettingsCard(context, [
            _buildSettingsTile(
              context: context,
              icon: Icons.info_outline_rounded,
              title: 'About Expense Manager',
              subtitle: 'App information and version',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Expense Manager',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Personal expense tracking app',
              ),
            ),
          ]),

          const SizedBox(height: 28),

          Center(
            child: Text(
              'Expense Manager • Version 1.0.0',
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // REUSABLE SETTINGS WIDGETS
  // --------------------------------------------------

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderFor(context),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final effectiveIconColor =
        iconColor ?? AppColors.primaryFor(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: effectiveIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: effectiveIconColor,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.borderFor(context),
    );
  }

  // --------------------------------------------------
  // LOCAL STORAGE INFORMATION
  // --------------------------------------------------

  void _showStorageInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Local Storage'),
        content: const Text(
          'Your transactions and group data are stored locally '
          'on this device. They are not automatically synced '
          'to an online account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // CLEAR TRANSACTIONS
  // --------------------------------------------------

  Future<void> _confirmClearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear personal transactions?'),
        content: const Text(
          'This will permanently remove all personal income '
          'and expense transactions stored on this device. '
          'Group expenses and settlements will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Clear Data',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await TransactionStorage.clearTransactions();
      await widget.onTransactionsCleared?.call();

      if (!mounted) return;

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal transactions cleared successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear transactions: $error'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // APPEARANCE
  // --------------------------------------------------

  Future<void> _showAppearanceDialog(BuildContext context) async {
    final controller = ThemeProvider.of(context);

    final selectedMode = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose Appearance'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: controller.themeMode,
            onChanged: (value) {
              if (value != null) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _themeOption('System Default', ThemeMode.system),
                _themeOption('Light', ThemeMode.light),
                _themeOption('Dark', ThemeMode.dark),
              ],
            ),
          ),
        ],
      ),
    );

    if (selectedMode != null) {
      await controller.setThemeMode(selectedMode);
    }
  }

  Widget _themeOption(String title, ThemeMode mode) {
    return RadioListTile<ThemeMode>(
      title: Text(title),
      value: mode,
    );
  }

  // --------------------------------------------------
  // CURRENCY
  // --------------------------------------------------

  Future<void> _showCurrencyDialog(BuildContext context) async {
    final controller = CurrencyProvider.of(context);

    final selectedCurrency = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose Currency'),
        children: [
          RadioGroup<String>(
            groupValue: controller.currencyCode,
            onChanged: (value) {
              if (value != null) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<String>(
                  title: Text('Pakistani Rupee (PKR)'),
                  value: 'PKR',
                ),
                RadioListTile<String>(
                  title: Text('US Dollar (USD)'),
                  value: 'USD',
                ),
                RadioListTile<String>(
                  title: Text('Euro (EUR)'),
                  value: 'EUR',
                ),
                RadioListTile<String>(
                  title: Text('British Pound (GBP)'),
                  value: 'GBP',
                ),
                RadioListTile<String>(
                  title: Text('Indian Rupee (INR)'),
                  value: 'INR',
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (selectedCurrency != null) {
      await controller.setCurrency(selectedCurrency);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency set to $selectedCurrency.'),
        ),
      );
    }
  }
}
