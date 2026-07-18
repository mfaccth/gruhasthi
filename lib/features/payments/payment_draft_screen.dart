import 'package:flutter/material.dart';

import '../../data/secure_payment_repository.dart';
import 'payment_review_screen.dart';

class PaymentDraftScreen extends StatefulWidget {
  const PaymentDraftScreen({
    super.key,
    required this.recipient,
    required this.paymentRepository,
  });

  final PaymentRecipient recipient;
  final SecurePaymentRepository paymentRepository;

  @override
  State<PaymentDraftScreen> createState() => _PaymentDraftScreenState();
}

class _PaymentDraftScreenState extends State<PaymentDraftScreen> {
  final _upi = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _loading = true;
  String? _upiError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _loadSavedUpiId();
  }

  Future<void> _loadSavedUpiId() async {
    final saved = await widget.paymentRepository.upiIdFor(widget.recipient);
    if (!mounted) return;
    setState(() {
      _upi.text = saved ?? '';
      _loading = false;
    });
  }

  Future<void> _review() async {
    final amount = double.tryParse(_amount.text.trim());
    final upiId = _upi.text.trim();
    setState(() {
      _upiError = isValidUpiId(upiId)
          ? null
          : 'Enter a valid UPI ID, for example name@bank.';
      _amountError = amount != null && amount > 0
          ? null
          : 'Enter an amount greater than ₹0.';
    });
    if (_upiError != null || _amountError != null) return;
    await widget.paymentRepository.saveUpiId(widget.recipient, upiId);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentReviewScreen(
          recipient: widget.recipient,
          upiId: upiId,
          amount: amount!,
          note: _note.text.trim(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _upi.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create payment draft')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Paying', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    widget.recipient.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _upi,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'UPI ID',
                      hintText: 'name@bank',
                      errorText: _upiError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      errorText: _amountError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _note,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('The UPI ID is saved in device-secured storage.'),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _review,
                    child: const Text('Review payment'),
                  ),
                ],
              ),
            ),
    );
  }
}
