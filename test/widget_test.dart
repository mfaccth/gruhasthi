import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gruhasthi/app.dart';
import 'package:gruhasthi/data/household_repository.dart';
import 'package:gruhasthi/data/secure_payment_repository.dart';
import 'package:gruhasthi/features/voice/voice_command_sheet.dart';
import 'package:gruhasthi/features/whatsapp/whatsapp_message.dart';
import 'package:gruhasthi/features/home/home_screen.dart';
import 'package:gruhasthi/domain/household_models.dart';

class MemoryStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

void main() {
  testWidgets('shows the Kundalahalli voice home and seeded pilot stores', (
    tester,
  ) async {
    await tester.pumpWidget(
      HouseholdApp(repository: HouseholdRepository(storage: MemoryStore())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.text('Kundalahalli, Bengaluru'), findsOneWidget);
    expect(find.textContaining('Village and Big Basket'), findsOneWidget);
    expect(find.text('Press and hold to speak'), findsOneWidget);
  });

  testWidgets('shows the voice command review sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceCommandSheet(storeNames: ['Village', 'Big Basket']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review what I heard.'), findsOneWidget);
    expect(find.text('Start listening'), findsNothing);
  });

  test('recognizes BigBasket without requiring a space or the word list', () {
    final command = VoiceCommand.fromTranscript('add milk to BigBasket', const [
      'Village',
      'Big Basket',
    ]);

    expect(command, isA<AddGroceryVoiceCommand>());
    final addCommand = command as AddGroceryVoiceCommand;
    expect(addCommand.storeName, 'Big Basket');
    expect(addCommand.item, 'milk');
  });

  test('recognizes a contact command and spoken phone digits', () {
    final command = VoiceCommand.fromTranscript(
      'add the contact Manohar number is nine eight seven six five four three two one zero',
      const ['Village', 'Big Basket'],
    );

    expect(command, isA<AddContactVoiceCommand>());
    final addCommand = command as AddContactVoiceCommand;
    expect(addCommand.name, 'Manohar');
    expect(addCommand.phoneNumber, '9876543210');
  });

  test('recognizes a contact command with a directly spoken phone number', () {
    final command = VoiceCommand.fromTranscript(
      'add contact Manohar 9845 598 745',
      const ['Village', 'Big Basket'],
    );

    expect(command, isA<AddContactVoiceCommand>());
    final addCommand = command as AddContactVoiceCommand;
    expect(addCommand.name, 'Manohar');
    expect(addCommand.phoneNumber, '9845598745');
  });

  test('excludes phone number words from a parsed contact name', () {
    final command =
        VoiceCommand.fromTranscript(
              'add contact vasu phone number 998 019 9891',
              const ['Village', 'Big Basket'],
            )
            as AddContactVoiceCommand;

    expect(command.name, 'Vasu');
    expect(command.phoneNumber, '9980199891');
  });

  test('recognizes store navigation and adding a named store', () {
    expect(
      VoiceCommand.fromTranscript('open stores', const []),
      isA<OpenStoresVoiceCommand>(),
    );
    final command =
        VoiceCommand.fromTranscript('please add store daily fresh', const [])
            as AddStoreVoiceCommand;
    expect(command.name, 'Daily Fresh');
  });

  test('extracts a WhatsApp number when adding a store by voice', () {
    final command =
        VoiceCommand.fromTranscript(
              'please add store star bazaar whatsapp number 998 019 9891',
              const [],
            )
            as AddStoreVoiceCommand;

    expect(command.name, 'Star Bazaar');
    expect(command.whatsAppNumber, '9980199891');
  });

  test('formats time-aware greetings with a user name', () {
    expect(greetingForHour(9, 'Manohar'), 'Good morning, Manohar');
    expect(greetingForHour(14, 'Manohar'), 'Good afternoon, Manohar');
    expect(greetingForHour(20, 'Manohar'), 'Good evening, Manohar');
  });

  test('formats a WhatsApp grocery message and Indian phone number', () {
    const store = Store(id: 'village', name: 'Village');
    const items = [
      GroceryItem(id: 'milk', name: 'Milk', quantity: '2 packets'),
    ];

    expect(normalizedWhatsAppNumber('98765 43210'), '919876543210');
    expect(groceryMessage(store, items), contains('• Milk — 2 packets'));
  });

  test('validates UPI IDs before a payment draft can be reviewed', () {
    expect(isValidUpiId('ramesh@okaxis'), isTrue);
    expect(isValidUpiId('not a UPI ID'), isFalse);
  });
}
