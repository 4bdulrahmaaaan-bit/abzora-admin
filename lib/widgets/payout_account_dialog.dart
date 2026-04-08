import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../theme.dart';

class PayoutAccountFormValue {
  final String methodType;
  final String accountHolderName;
  final String upiId;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankName;

  const PayoutAccountFormValue({
    required this.methodType,
    required this.accountHolderName,
    required this.upiId,
    required this.bankAccountNumber,
    required this.bankIfsc,
    required this.bankName,
  });
}

Future<PayoutAccountFormValue?> showPayoutAccountDialog({
  required BuildContext context,
  required String title,
  required PayoutProfileSummary initialValue,
}) {
  return showModalBottomSheet<PayoutAccountFormValue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PayoutAccountSheet(
      title: title,
      initialValue: initialValue,
    ),
  );
}

class PayoutAccountSummaryCard extends StatelessWidget {
  const PayoutAccountSummaryCard({
    super.key,
    required this.title,
    required this.profile,
    required this.onManage,
  });

  final String title;
  final PayoutProfileSummary profile;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final hasBank = profile.methodType == 'bank_account';
    final descriptor = !profile.isConfigured
        ? 'Add bank account or UPI details to receive automated settlements.'
        : hasBank
            ? '${profile.bankName.isEmpty ? 'Bank account' : profile.bankName} • ${_maskedAccount(profile.bankAccountNumber)}'
            : profile.upiId;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8D9AB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: Text(profile.isConfigured ? 'Edit' : 'Setup'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profile.isConfigured
                ? 'Settlements will go to ${profile.accountHolderName.isEmpty ? 'your payout account' : profile.accountHolderName}.'
                : 'RazorpayX needs a payout destination before withdrawals can be requested.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xFF5F5F5F),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AbzioTheme.grey100),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasBank ? Icons.account_balance_outlined : Icons.qr_code_2_rounded,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.isConfigured
                            ? (hasBank ? 'Bank settlement enabled' : 'UPI settlement enabled')
                            : 'Payout account not configured',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descriptor,
                        style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _maskedAccount(String value) {
  final digits = value.replaceAll(' ', '');
  if (digits.length <= 4) {
    return digits;
  }
  return '••••${digits.substring(digits.length - 4)}';
}

class _PayoutAccountSheet extends StatefulWidget {
  const _PayoutAccountSheet({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final PayoutProfileSummary initialValue;

  @override
  State<_PayoutAccountSheet> createState() => _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends State<_PayoutAccountSheet> {
  late String _methodType;
  late final TextEditingController _accountHolderController;
  late final TextEditingController _upiController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _bankNameController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _methodType = widget.initialValue.methodType.isEmpty ? 'vpa' : widget.initialValue.methodType;
    _accountHolderController = TextEditingController(text: widget.initialValue.accountHolderName);
    _upiController = TextEditingController(text: widget.initialValue.upiId);
    _bankAccountController = TextEditingController(text: widget.initialValue.bankAccountNumber);
    _ifscController = TextEditingController(text: widget.initialValue.bankIfsc);
    _bankNameController = TextEditingController(text: widget.initialValue.bankName);
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      PayoutAccountFormValue(
        methodType: _methodType,
        accountHolderName: _accountHolderController.text.trim(),
        upiId: _upiController.text.trim(),
        bankAccountNumber: _bankAccountController.text.trim(),
        bankIfsc: _ifscController.text.trim().toUpperCase(),
        bankName: _bankNameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUpi = _methodType == 'vpa';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Choose where ABZORA should send your approved withdrawals through RazorpayX.',
                    style: GoogleFonts.inter(fontSize: 13, color: AbzioTheme.grey500, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'vpa',
                        label: Text('UPI'),
                        icon: Icon(Icons.qr_code_2_rounded),
                      ),
                      ButtonSegment<String>(
                        value: 'bank_account',
                        label: Text('Bank'),
                        icon: Icon(Icons.account_balance_outlined),
                      ),
                    ],
                    selected: {_methodType},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _methodType = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountHolderController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Account holder name',
                      hintText: 'Abdul Rahman',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter account holder name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isUpi) ...[
                    TextFormField(
                      controller: _upiController,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        hintText: 'name@bank',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Enter UPI ID.';
                        }
                        if (!text.contains('@')) {
                          return 'Enter a valid UPI ID.';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _bankAccountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Bank account number',
                        hintText: '1234567890',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Enter bank account number.';
                        }
                        if (text.length < 8) {
                          return 'Bank account number looks too short.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ifscController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'IFSC code',
                        hintText: 'HDFC0001234',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Enter IFSC code.';
                        }
                        if (text.length < 8) {
                          return 'Enter a valid IFSC code.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bankNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Bank name',
                        hintText: 'HDFC Bank',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Save payout details'),
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
}
