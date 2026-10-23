
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/main_navigation_screen.dart';
import '../../core/theme/app_colors.dart';
import '../settings/profile_storage.dart';
import 'quick_setup_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _openQuickSetup(BuildContext context) {
    // Keep onboarding underneath setup so the back arrow has a route to return to.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickSetupScreen(
          onComplete: (data) async {
            final name = data.name.trim();
            if (name.isNotEmpty) {
              await ProfileStorage.saveName(name);
            }
            
            // ignore: use_build_context_synchronously
            final currencyController = CurrencyProvider.of(context);
            await currencyController.setCurrency(data.currencyCode);


            final preferences = await SharedPreferences.getInstance();
            await preferences.setBool(
              'expense_manager_bill_reminders_enabled',
              data.billRemindersEnabled,
            );
            await preferences.setBool('expense_manager_setup_complete', true);

            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const MainNavigationScreen(),
              ),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => _openQuickSetup(context),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textSecondaryFor(context),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 85,
                  color: AppColors.primaryFor(context),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Take Control\nof Your Expenses',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Track your spending, manage budgets, '
                'and share expenses with friends — all in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'TRACK  •  SPLIT  •  SETTLE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryFor(context),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _openQuickSetup(context),
                  child: const Text('Get Started'),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Your finances, organized simply.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
