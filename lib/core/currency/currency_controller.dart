
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyController extends ChangeNotifier {
  static const String _preferenceKey = 'expense_manager_currency';

  String _currencyCode = 'PKR';

  String get currencyCode => _currencyCode;

  String get currencySymbol {
    switch (_currencyCode) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      case 'PKR':
      default:
        return 'Rs.';
    }
  }

  CurrencyController() {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final preferences = await SharedPreferences.getInstance();
    _currencyCode = preferences.getString(_preferenceKey) ?? 'PKR';
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    if (!['PKR', 'USD', 'EUR', 'GBP', 'INR'].contains(code)) {
      return;
    }

    _currencyCode = code;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, code);
  }
}
