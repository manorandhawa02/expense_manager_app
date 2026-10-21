import 'package:flutter/material.dart';
import 'core/currency/currency_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/splash/splash_screen.dart';

class ThemeProvider extends InheritedNotifier<ThemeController> {
  const ThemeProvider({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ThemeProvider>();

    assert(provider != null, 'ThemeProvider not found in widget tree.');
    return provider!.notifier!;
  }
}


class CurrencyProvider extends InheritedNotifier<CurrencyController> {
  const CurrencyProvider({
    super.key,
    required CurrencyController controller,
    required super.child,
  }) : super(notifier: controller);

  static CurrencyController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<CurrencyProvider>();

    assert(provider != null, 'CurrencyProvider not found in widget tree.');
    return provider!.notifier!;
  }
}


class ExpenseManagerApp extends StatefulWidget {
  const ExpenseManagerApp({super.key});

  @override
  State<ExpenseManagerApp> createState() => _ExpenseManagerAppState();
}

class _ExpenseManagerAppState extends State<ExpenseManagerApp> {
  late final ThemeController _themeController;
  late final CurrencyController _currencyController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController();
      _currencyController = CurrencyController();
  }

  @override
void dispose() {
  _themeController.dispose();
  _currencyController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, child) {
        return ThemeProvider(
  controller: _themeController,
  child: CurrencyProvider(
    controller: _currencyController,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeController.themeMode,
      home: const SplashScreen(),
    ),
  ),
);
      },
    );
  }
}