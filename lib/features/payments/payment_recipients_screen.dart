import 'package:flutter/material.dart';

import '../../data/household_repository.dart';
import '../../data/secure_payment_repository.dart';
import '../../domain/household_models.dart';
import 'payment_draft_screen.dart';

class PaymentRecipientsScreen extends StatefulWidget {
  const PaymentRecipientsScreen({
    super.key,
    required this.householdRepository,
    required this.paymentRepository,
  });

  final HouseholdRepository householdRepository;
  final SecurePaymentRepository paymentRepository;

  @override
  State<PaymentRecipientsScreen> createState() =>
      _PaymentRecipientsScreenState();
}

class _PaymentRecipientsScreenState extends State<PaymentRecipientsScreen> {
  late Future<HouseholdData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.householdRepository.load();
  }

  void _openDraft(PaymentRecipient recipient) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDraftScreen(
          recipient: recipient,
          paymentRepository: widget.paymentRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose payment recipient')),
      body: FutureBuilder<HouseholdData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Contacts', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.contacts.isEmpty)
                const ListTile(
                  leading: Icon(Icons.person_add_alt_1_outlined),
                  title: Text('Add a contact before creating a payment draft'),
                )
              else
                for (final contact in data.contacts)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(contact.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(contact.name),
                    subtitle: const Text('Payment draft'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDraft(
                      PaymentRecipient(
                        kind: PaymentRecipientKind.contact,
                        id: contact.id,
                        name: contact.name,
                      ),
                    ),
                  ),
              const Divider(height: 36),
              Text('Stores', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final store in data.stores)
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.storefront_outlined),
                  ),
                  title: Text(store.name),
                  subtitle: const Text('Payment draft'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDraft(
                    PaymentRecipient(
                      kind: PaymentRecipientKind.store,
                      id: store.id,
                      name: store.name,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
