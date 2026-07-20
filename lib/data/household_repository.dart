import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/household_models.dart';

abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }
}

class HouseholdRepository {
  HouseholdRepository({KeyValueStore? storage})
    : _storage = storage ?? SharedPreferencesStore();

  static const _storageKey = 'household_data_v1';
  static const _appTourSeenKey = 'app_tour_seen_v1';
  final KeyValueStore _storage;

  Future<bool> hasSeenAppTour() async =>
      (await _storage.read(_appTourSeenKey)) == 'true';

  Future<void> markAppTourSeen() => _storage.write(_appTourSeenKey, 'true');

  Future<HouseholdData> load() async {
    final stored = await _storage.read(_storageKey);
    if (stored == null) {
      final initial = HouseholdData(
        stores: seededStores,
        itemsByStore: const {},
        contacts: const [],
      );
      await save(initial);
      return initial;
    }

    final root = jsonDecode(stored) as Map<String, dynamic>;
    final stores = (root['stores'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Store.fromJson)
        .toList(growable: false);
    final itemMap = (root['itemsByStore'] as Map<String, dynamic>).map(
      (storeId, items) => MapEntry(
        storeId,
        (items as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(GroceryItem.fromJson)
            .toList(growable: false),
      ),
    );
    final contacts = (root['contacts'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Contact.fromJson)
        .toList(growable: false);
    return HouseholdData(
      stores: stores,
      itemsByStore: itemMap,
      contacts: contacts,
      userName: root['userName'] as String? ?? '',
      locality: root['locality'] as String? ?? 'Kundalahalli, Bengaluru',
    );
  }

  Future<void> save(HouseholdData data) {
    final payload = jsonEncode({
      'stores': data.stores.map((store) => store.toJson()).toList(),
      'itemsByStore': data.itemsByStore.map(
        (storeId, items) =>
            MapEntry(storeId, items.map((item) => item.toJson()).toList()),
      ),
      'contacts': data.contacts.map((contact) => contact.toJson()).toList(),
      'userName': data.userName,
      'locality': data.locality,
    });
    return _storage.write(_storageKey, payload);
  }
}
