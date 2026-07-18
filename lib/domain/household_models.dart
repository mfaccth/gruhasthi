class Store {
  const Store({
    required this.id,
    required this.name,
    this.address = '',
    this.whatsAppNumber = '',
  });

  final String id;
  final String name;
  final String address;
  final String whatsAppNumber;

  Store copyWith({String? name, String? address, String? whatsAppNumber}) {
    return Store(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      whatsAppNumber: whatsAppNumber ?? this.whatsAppNumber,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'whatsAppNumber': whatsAppNumber,
  };

  factory Store.fromJson(Map<String, dynamic> json) => Store(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    whatsAppNumber: json['whatsAppNumber'] as String? ?? '',
  );
}

class GroceryItem {
  const GroceryItem({required this.id, required this.name, this.quantity = ''});

  final String id;
  final String name;
  final String quantity;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
  };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as String? ?? '',
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    this.phoneNumber = '',
    this.whatsAppNumber = '',
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String whatsAppNumber;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'whatsAppNumber': whatsAppNumber,
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    phoneNumber: json['phoneNumber'] as String? ?? '',
    whatsAppNumber: json['whatsAppNumber'] as String? ?? '',
  );
}

class HouseholdData {
  const HouseholdData({
    required this.stores,
    required this.itemsByStore,
    required this.contacts,
    this.userName = '',
    this.locality = 'Kundalahalli, Bengaluru',
  });

  final List<Store> stores;
  final Map<String, List<GroceryItem>> itemsByStore;
  final List<Contact> contacts;
  final String userName;
  final String locality;

  List<GroceryItem> itemsFor(String storeId) =>
      itemsByStore[storeId] ?? const [];

  HouseholdData copyWith({
    List<Store>? stores,
    Map<String, List<GroceryItem>>? itemsByStore,
    List<Contact>? contacts,
    String? userName,
    String? locality,
  }) {
    return HouseholdData(
      stores: stores ?? this.stores,
      itemsByStore: itemsByStore ?? this.itemsByStore,
      contacts: contacts ?? this.contacts,
      userName: userName ?? this.userName,
      locality: locality ?? this.locality,
    );
  }
}

const seededStores = <Store>[
  Store(id: 'village', name: 'Village'),
  Store(id: 'big-basket', name: 'Big Basket'),
];
