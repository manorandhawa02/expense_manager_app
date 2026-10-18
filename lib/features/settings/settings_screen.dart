import 'package:flutter/material.dart';
import '../transaction/transaction_storage.dart';
import '../../core/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  final Future<void> Function()? onTransactionsCleared;

  const SettingsScreen({
    super.key,
    this.onTransactionsCleared,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('Preferences'),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Customize your app theme',
              onTap: () => _showComingSoon(context),
            ),
            _buildDivider(),
            _buildSettingsTile(
  icon: Icons.delete_outline_rounded,
  title: 'Clear Data',
  subtitle: 'Remove saved personal transactions',
  iconColor: Colors.redAccent,
  onTap: () => _confirmClearData(context),
),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('Data Management'),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.storage_rounded,
              title: 'Local Storage',
              subtitle: 'Your data is stored on this device',
              onTap: () => _showStorageInfo(context),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.delete_outline_rounded,
              title: 'Clear Data',
              subtitle: 'Remove saved transaction data',
              iconColor: Colors.redAccent,
              onTap: () => _showComingSoon(context),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('About'),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
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
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.primary,
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This setting will be available in a future step.'),
      ),
    );
  }

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
  Future<void> _confirmClearData(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear personal transactions?'),
      content: const Text(
        'This will permanently remove all personal income and '
        'expense transactions stored on this device. Group '
        'expenses and settlements will not be deleted.',
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

  if (confirmed != true) return;

  await TransactionStorage.clearTransactions();
  await onTransactionsCleared?.call();

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Personal transactions cleared successfully.'),
    ),
  );
}
}
