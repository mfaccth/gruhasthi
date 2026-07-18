import 'package:flutter/material.dart';

import '../../domain/household_models.dart';
import 'google_places_store_search.dart';
import 'stores_screen.dart';

class StoreDiscoveryScreen extends StatefulWidget {
  StoreDiscoveryScreen({
    super.key,
    required this.locality,
    StoreSearchProvider? searchProvider,
  }) : _searchProvider = searchProvider ?? GooglePlacesStoreSearchProvider();

  final String locality;
  final StoreSearchProvider _searchProvider;

  @override
  State<StoreDiscoveryScreen> createState() => _StoreDiscoveryScreenState();
}

class _StoreDiscoveryScreenState extends State<StoreDiscoveryScreen> {
  final _query = TextEditingController(text: 'grocery stores');
  List<StoreSearchResult> _results = const [];
  String? _message;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final results = await widget._searchProvider.search(
        query,
        widget.locality,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _message = results.isEmpty ? 'No matching stores found.' : null;
      });
    } on StoreSearchException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(StoreSearchResult result) async {
    final store = await showDialog<Store>(
      context: context,
      builder: (_) => StoreEditorDialog(
        initialName: result.name,
        initialAddress: result.address,
      ),
    );
    if (store != null && mounted) Navigator.pop(context, store);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find stores')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Search Google Maps around ${widget.locality}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Check delivery and WhatsApp details with the store before saving.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'What are you looking for?',
              suffixIcon: IconButton(
                tooltip: 'Search Google Maps',
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          if (_searching) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!),
              ),
            ),
          ..._results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.storefront_outlined),
                  ),
                  title: Text(result.name),
                  subtitle: Text('${result.address}\nDelivery: unverified'),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: () => _add(result),
                    child: const Text('Add'),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Powered by Google Maps',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
