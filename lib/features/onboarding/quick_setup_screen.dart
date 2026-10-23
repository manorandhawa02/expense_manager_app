import 'package:flutter/material.dart';

class QuickSetupData {
  final String name;
  final String currencyCode;
  final bool billRemindersEnabled;

  const QuickSetupData({
    required this.name,
    required this.currencyCode,
    required this.billRemindersEnabled,
  });
}

class QuickSetupScreen extends StatefulWidget {
  final Future<void> Function(QuickSetupData data) onComplete;
  final String initialName;
  final String initialCurrencyCode;
  final bool initialBillRemindersEnabled;

  const QuickSetupScreen({
    super.key,
    required this.onComplete,
    this.initialName = '',
    this.initialCurrencyCode = 'PKR',
    this.initialBillRemindersEnabled = true,
  });

  @override
  State<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends State<QuickSetupScreen> {
  static const _background = Color(0xFF0D1C1B);
  static const _fieldBackground = Color(0xFF142A28);
  static const _border = Color(0xFF344A47);
  static const _primaryText = Color(0xFFE8F1EF);
  static const _secondaryText = Color(0xFF9BAEAA);
  static const _mint = Color(0xFF56C6B8);

  static const Map<String, String> _currencies = {
    'PKR': 'PKR — Pakistani Rupee',
    'USD': 'USD — US Dollar',
    'EUR': 'EUR — Euro',
    'GBP': 'GBP — British Pound',
    'INR': 'INR — Indian Rupee',
  };

  late final TextEditingController _nameController;
  late String _currencyCode;
  late bool _billRemindersEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _currencyCode = _currencies.containsKey(widget.initialCurrencyCode)
        ? widget.initialCurrencyCode
        : 'PKR';
    _billRemindersEnabled = widget.initialBillRemindersEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await widget.onComplete(
        QuickSetupData(
          name: _nameController.text.trim(),
          currencyCode: _currencyCode,
          billRemindersEnabled: _billRemindersEnabled,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Quick setup save error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your setup. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: _primaryText, size: 28),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Quick setup',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Everything here is optional and can be changed later in Settings.',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 17,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 34),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: _primaryText, fontSize: 17),
                    decoration: _inputDecoration(hintText: 'Your name (optional)'),
                  ),
                  const SizedBox(height: 22),
                  DropdownButtonFormField<String>(
                    initialValue: _currencyCode,
                    dropdownColor: _fieldBackground,
                    icon: const Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 27),
                    style: const TextStyle(
                      color: _primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(labelText: 'Currency'),
                    items: _currencies.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _currencyCode = value);
                          },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill reminders',
                              style: TextStyle(
                                color: _primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Local notifications only. No data leaves your device.',
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Switch(
                        value: _billRemindersEnabled,
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(() => _billRemindersEnabled = value),
                        activeThumbColor: const Color(0xFF062D29),
                        activeTrackColor: _mint,
                        inactiveThumbColor: _secondaryText,
                        inactiveTrackColor: _border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _startTracking,
                      style: FilledButton.styleFrom(
                        backgroundColor: _mint,
                        foregroundColor: const Color(0xFF062D29),
                        disabledBackgroundColor: _mint.withValues(alpha: 0.55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF062D29),
                              ),
                            )
                          : const Text('Start tracking'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, String? labelText}) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      labelStyle: const TextStyle(color: _secondaryText),
      floatingLabelStyle: const TextStyle(color: _secondaryText),
      hintStyle: const TextStyle(color: _secondaryText, fontSize: 17),
      filled: true,
      fillColor: _fieldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _mint, width: 1.5),
      ),
    );
  }
}
