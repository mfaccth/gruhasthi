import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PlatformSecureValueStore implements SecureValueStore {
  PlatformSecureValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class SecurePaymentRepository {
  SecurePaymentRepository({SecureValueStore? storage})
    : _storage = storage ?? PlatformSecureValueStore();

  final SecureValueStore _storage;

  String _upiKey(PaymentRecipient recipient) =>
      'upi.${recipient.kind.name}.${recipient.id}';

  Future<String?> upiIdFor(PaymentRecipient recipient) =>
      _storage.read(_upiKey(recipient));

  Future<void> saveUpiId(PaymentRecipient recipient, String upiId) {
    return _storage.write(_upiKey(recipient), upiId.trim().toLowerCase());
  }
}

enum PaymentRecipientKind { contact, store }

class PaymentRecipient {
  const PaymentRecipient({
    required this.kind,
    required this.id,
    required this.name,
  });

  final PaymentRecipientKind kind;
  final String id;
  final String name;
}

bool isValidUpiId(String value) {
  return RegExp(
    r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z0-9._-]{2,64}$',
  ).hasMatch(value.trim());
}
