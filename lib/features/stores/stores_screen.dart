import 'package:flutter/material.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import 'store_discovery_screen.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({
    super.key,
    required this.repository,
    this.initialName,
    this.initialWhatsApp = '',
  });

  final HouseholdRepository repository;
  final String? initialName;
  final String initialWhatsApp;

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  late Future<HouseholdData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.load();
    if (widget.initialName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _edit(
            null,
            initialName: widget.initialName!,
            initialWhatsApp: widget.initialWhatsApp,
          );
        }
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _data = widget.repository.load());
  }

  Future<void> _edit(
    Store? store, {
    String initialName = '',
    String initialWhatsApp = '',
  }) async {
    final result = await showDialog<Store>(
      context: context,
      builder: (_) => StoreEditorDialog(
        store: store,
        initialName: initialName,
        initialWhatsApp: initialWhatsApp,
      ),
    );
    if (result == null) return;
    final data = await widget.repository.load();
    final updatedStores = store == null
        ? [...data.stores, result]
        : data.stores
              .map((entry) => entry.id == result.id ? result : entry)
              .toList();
    await widget.repository.save(data.copyWith(stores: updatedStores));
    await _refresh();
  }

  Future<void> _discover() async {
    final initialData = await widget.repository.load();
    if (!mounted) return;
    final result = await Navigator.of(context).push<Store>(
      MaterialPageRoute(
        builder: (_) => StoreDiscoveryScreen(locality: initialData.locality),
      ),
    );
    if (result == null) return;
    final data = await widget.repository.load();
    await widget.repository.save(
      data.copyWith(stores: [...data.stores, result]),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add store',
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Add store'),
      ),
      body: FutureBuilder<HouseholdData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              OutlinedButton.icon(
                onPressed: _discover,
                icon: const Icon(Icons.travel_explore_outlined),
                label: const Text('Find a store on Google Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF43383B),
                  backgroundColor: const Color(0xFFFFF4C8),
                  side: const BorderSide(color: Color(0xFF43383B)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              ...snapshot.data!.stores.map(
                (store) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.storefront_outlined),
                      ),
                      title: Text(store.name),
                      subtitle: Text(
                        store.whatsAppNumber.isEmpty
                            ? 'Add a WhatsApp number before sending lists'
                            : store.whatsAppNumber,
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(store),
                    ),
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

class StoreEditorDialog extends StatefulWidget {
  const StoreEditorDialog({
    super.key,
    this.store,
    this.initialName = '',
    this.initialAddress = '',
    this.initialWhatsApp = '',
  });

  final Store? store;
  final String initialName;
  final String initialAddress;
  final String initialWhatsApp;

  @override
  State<StoreEditorDialog> createState() => _StoreEditorDialogState();
}

class _StoreEditorDialogState extends State<StoreEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _whatsApp;
  bool _nameFocused = false;
  bool _addressFocused = false;
  bool _whatsAppFocused = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.store?.name ?? widget.initialName,
    );
    _address = TextEditingController(
      text: widget.store?.address ?? widget.initialAddress,
    );
    _whatsApp = TextEditingController(
      text: widget.store?.whatsAppNumber ?? widget.initialWhatsApp,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _whatsApp.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, bool focused) {
    return InputDecoration(
      labelText: label,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      labelStyle: focused ? const TextStyle(color: Color(0xFFF2B8C5)) : null,
      floatingLabelStyle: focused
          ? const TextStyle(color: Color(0xFFF2B8C5))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.store == null ? 'Add store' : 'Edit store'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              onFocusChange: (focused) {
                setState(() => _nameFocused = focused);
              },
              child: TextField(
                controller: _name,
                autofocus: true,
                cursorColor: const Color(0xFFE2A900),
                decoration: _fieldDecoration('Store name', _nameFocused),
              ),
            ),
            Focus(
              onFocusChange: (focused) {
                setState(() => _addressFocused = focused);
              },
              child: TextField(
                controller: _address,
                cursorColor: const Color(0xFFE2A900),
                decoration: _fieldDecoration(
                  'Address or area',
                  _addressFocused,
                ),
              ),
            ),
            Focus(
              onFocusChange: (focused) {
                setState(() => _whatsAppFocused = focused);
              },
              child: TextField(
                controller: _whatsApp,
                keyboardType: TextInputType.phone,
                cursorColor: const Color(0xFFE2A900),
                decoration: _fieldDecoration(
                  'WhatsApp number',
                  _whatsAppFocused,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF43383B),
            side: const BorderSide(color: Color(0xFF43383B)),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              Store(
                id:
                    widget.store?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
                address: _address.text.trim(),
                whatsAppNumber: _whatsApp.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF2B8C5),
            foregroundColor: const Color(0xFF43383B),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
