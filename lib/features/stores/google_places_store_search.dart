import 'dart:io';

import 'package:flutter/services.dart';

class StoreSearchResult {
  const StoreSearchResult({required this.name, required this.address});

  final String name;
  final String address;
}

abstract interface class StoreSearchProvider {
  Future<List<StoreSearchResult>> search(String query, String locality);
}

class GooglePlacesStoreSearchProvider implements StoreSearchProvider {
  static const _channel = MethodChannel('com.gruhasthi.gruhasthi/store_search');

  @override
  Future<List<StoreSearchResult>> search(String query, String locality) async {
    if (!Platform.isAndroid) {
      throw const StoreSearchException(
        'Store discovery is currently available on Android only.',
      );
    }

    try {
      final response = await _channel.invokeMethod<List<dynamic>>(
        'searchNearbyStores',
        {'query': query, 'locality': locality},
      );
      return (response ?? const [])
          .cast<Map<dynamic, dynamic>>()
          .map(
            (result) => StoreSearchResult(
              name: result['name'] as String? ?? 'Unnamed store',
              address: result['address'] as String? ?? '',
            ),
          )
          .toList(growable: false);
    } on PlatformException catch (error) {
      if (error.code == 'API_KEY_MISSING') {
        throw const StoreSearchException(
          'Google Maps has not been configured on this build yet.',
        );
      }
      throw StoreSearchException(
        error.message ?? 'Google Maps could not complete the search.',
      );
    }
  }
}

class StoreSearchException implements Exception {
  const StoreSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
