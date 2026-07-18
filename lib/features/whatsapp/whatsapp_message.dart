import '../../domain/household_models.dart';

String groceryMessage(Store store, List<GroceryItem> items) {
  final lines = items.map((item) {
    final quantity = item.quantity.isEmpty ? '' : ' — ${item.quantity}';
    return '• ${item.name}$quantity';
  });
  return 'Hello ${store.name},\n\nPlease send:\n${lines.join('\n')}\n\nThank you.';
}

String normalizedWhatsAppNumber(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '91$digits';
  return digits;
}

bool hasUsableWhatsAppNumber(String phoneNumber) {
  final number = normalizedWhatsAppNumber(phoneNumber);
  return number.length >= 11 && number.length <= 15;
}

Uri whatsAppMessageUri(String phoneNumber, String message) {
  return Uri.https('wa.me', '/${normalizedWhatsAppNumber(phoneNumber)}', {
    'text': message,
  });
}
