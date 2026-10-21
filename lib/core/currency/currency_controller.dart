
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyController extends ChangeNotifier {
  static const String _preferenceKey = 'expense_manager_currency';
  static const String _ratesKey = 'expense_manager_exchange_rates';
  static const String _ratesDateKey = 'expense_manager_exchange_rates_date';

  static const List<String> supportedCurrencies = [
    'PKR',
    'USD',
    'EUR',
    'GBP',
    'INR',
  ];

  String _currencyCode = 'PKR';
  Map<String, double> _rates = {'PKR': 1.0};
  DateTime? _lastUpdated;
  bool _isLoadingRates = false;
  String? _errorMessage;

  String get currencyCode => _currencyCode;
  bool get isLoadingRates => _isLoadingRates;
  DateTime? get lastUpdated => _lastUpdated;
  String? get errorMessage => _errorMessage;

  bool get hasSelectedCurrencyRate =>
      _currencyCode == 'PKR' || _rates.containsKey(_currencyCode);

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
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _loadCurrency();
    await _loadCachedRates();
    await refreshRates();
  }

  Future<void> _loadCurrency() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _currencyCode =
          preferences.getString(_preferenceKey) ?? 'PKR';

      if (!supportedCurrencies.contains(_currencyCode)) {
        _currencyCode = 'PKR';
      }

      if (!isDisposed) notifyListeners();
    } catch (_) {
      // Keep PKR as the default if preferences cannot be read.
    }
  }

  Future<void> _loadCachedRates() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedRates = preferences.getString(_ratesKey);
      final savedDate = preferences.getString(_ratesDateKey);

      if (savedRates != null) {
        final decoded = jsonDecode(savedRates) as Map<String, dynamic>;

        final cachedRates = <String, double>{'PKR': 1.0};

        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is num && value > 0) {
            cachedRates[entry.key] = value.toDouble();
          }
        }

        _rates = cachedRates;

        if (savedDate != null) {
          _lastUpdated = DateTime.tryParse(savedDate);
        }
      }

      if (!isDisposed) notifyListeners();
    } catch (_) {
      // If the cache is invalid, PKR conversion remains available.
    }
  }

  Future<void> refreshRates() async {
    if (_isLoadingRates) return;

    _isLoadingRates = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse(
        'https://open.er-api.com/v6/latest/PKR',
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Exchange-rate service is unavailable.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['result'] != 'success') {
        throw Exception('Unable to retrieve exchange rates.');
      }

      final rawRates = data['rates'] as Map<String, dynamic>;
      final updatedRates = <String, double>{'PKR': 1.0};

      for (final code in supportedCurrencies) {
        if (code == 'PKR') continue;

        final value = rawRates[code];

        if (value is num && value > 0) {
          updatedRates[code] = value.toDouble();
        }
      }

      if (!updatedRates.keys.toSet().containsAll(supportedCurrencies)) {
        throw Exception('Some currency rates are missing.');
      }

      _rates = updatedRates;
      _lastUpdated = DateTime.now();

      final preferences = await SharedPreferences.getInstance();

      await preferences.setString(
        _ratesKey,
        jsonEncode(_rates),
      );

      await preferences.setString(
        _ratesDateKey,
        _lastUpdated!.toIso8601String(),
      );
    } catch (_) {
      _errorMessage =
          'Could not refresh exchange rates. Using saved rates if available.';
    } finally {
      _isLoadingRates = false;
      notifyListeners();
    }
  }

 Future<void> setCurrency(String code) async {
  if (!supportedCurrencies.contains(code)) return;

  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_preferenceKey, code);

  _currencyCode = code;

  if (!isDisposed) notifyListeners();

  if (!hasSelectedCurrencyRate) {
    await refreshRates();
  }
}

/// Converts an amount in the selected currency back to PKR
/// for consistent local transaction storage.
double? convertToPKR(num selectedCurrencyAmount) {
  if (_currencyCode == 'PKR') {
    return selectedCurrencyAmount.toDouble();
  }

  final rate = _rates[_currencyCode];

  if (rate == null || rate <= 0) {
    return null;
  }

  return selectedCurrencyAmount / rate;
}

  /// Converts a stored PKR amount to the selected currency.
  ///
  /// Returns null if the required exchange rate is unavailable.
  double? convertFromPKR(num amount) {
    if (_currencyCode == 'PKR') {
      return amount.toDouble();
    }

    final rate = _rates[_currencyCode];

    if (rate == null) return null;

    return amount * rate;
  }

  /// Formats a converted amount with its selected currency symbol.
  String formatAmount(num pkrAmount, {int decimalPlaces = 2}) {
    final converted = convertFromPKR(pkrAmount);

    if (converted == null) {
      return 'Rate unavailable';
    }

    final formatted = converted.toStringAsFixed(decimalPlaces);

    final parts = formatted.split('.');
    final wholeNumber = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    final result = decimalPlaces > 0
        ? '$wholeNumber.${parts.last}'
        : wholeNumber;

    return '$currencySymbol $result';
  }

  bool get isDisposed => _disposed;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
