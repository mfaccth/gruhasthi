import 'package:flutter/material.dart';

import '../../data/secure_payment_repository.dart';
import 'google_pay_launcher.dart';

class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({
    super.key,
    required this.recipient,
    required this.upiId,
    required this.amount,
    required this.note,
  });

  final PaymentRecipient recipient;
  final String upiId;
  final double amount;
  final String note;

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  final _googlePay = GooglePayLauncher();
  bool _opening = false;
  String? _handoffMessage;

  Future<void> _openGooglePay() async {
    setState(() {
      _opening = true;
      _handoffMessage = null;
    });
    final opened = await _googlePay.openManually();
    if (!mounted) return;
    setState(() {
      _opening = false;
      _handoffMessage = opened
          ? 'Google Pay opened. Complete the recipient, amount, and approval there.'
          : 'Google Pay could not be opened. Install or update it, then try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '₹${widget.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'to ${widget.recipient.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(widget.upiId, style: Theme.of(context).textTheme.bodyMedium),
              if (widget.note.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Note: ${widget.note}'),
              ],
              const SizedBox(height: 32),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4C8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Gruhasthi will only open Google Pay. It does not pass this recipient or amount to Google Pay, and it cannot verify the outcome.',
                  ),
                ),
              ),
              const Spacer(),
              if (_handoffMessage != null) ...[
                Text(_handoffMessage!),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _opening ? null : _openGooglePay,
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  _opening ? 'Opening Google Pay…' : 'Open Google Pay manually',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
