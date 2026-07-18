import 'package:flutter/material.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import '../whatsapp/whatsapp_message.dart';
import '../whatsapp/whatsapp_preview_screen.dart';
import '../voice/voice_command_sheet.dart';

class GroceryListsScreen extends StatefulWidget {
  const GroceryListsScreen({super.key, required this.repository});

  final HouseholdRepository repository;

  @override
  State<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends State<GroceryListsScreen> {
  late Future<HouseholdData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _data = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grocery lists')),
      body: FutureBuilder<HouseholdData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: data.stores.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final store = data.stores[index];
              final itemCount = data.itemsFor(store.id).length;
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.storefront_outlined),
                  ),
                  title: Text(store.name),
                  subtitle: Text(
                    itemCount == 0 ? 'No items yet' : '$itemCount items',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroceryListEditor(
                          repository: widget.repository,
                          store: store,
                        ),
                      ),
                    );
                    await _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GroceryListEditor extends StatefulWidget {
  const GroceryListEditor({
    super.key,
    required this.repository,
    required this.store,
    this.initialItem = '',
    this.initialQuantity = '',
    this.initialUnit = GroceryQuantityUnit.count,
  });

  final HouseholdRepository repository;
  final Store store;
  final String initialItem;
  final String initialQuantity;
  final GroceryQuantityUnit initialUnit;

  @override
  State<GroceryListEditor> createState() => _GroceryListEditorState();
}

class _GroceryListEditorState extends State<GroceryListEditor> {
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  late GroceryQuantityUnit _unit;
  List<GroceryItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _itemController.text = widget.initialItem;
    _quantityController.text = widget.initialQuantity;
    _unit = widget.initialUnit;
    _load();
  }

  Future<void> _load() async {
    final data = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _items = data.itemsFor(widget.store.id);
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    final name = _itemController.text.trim();
    if (name.isEmpty) return;
    final item = GroceryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      quantity: groceryQuantityLabel(_quantityController.text.trim(), _unit),
    );
    final data = await widget.repository.load();
    final updated = [...data.itemsFor(widget.store.id), item];
    await widget.repository.save(
      data.copyWith(
        itemsByStore: {...data.itemsByStore, widget.store.id: updated},
      ),
    );
    _itemController.clear();
    _quantityController.clear();
    if (mounted) setState(() => _items = updated);
  }

  Future<void> _removeItem(GroceryItem item) async {
    final data = await widget.repository.load();
    final updated = data
        .itemsFor(widget.store.id)
        .where((entry) => entry.id != item.id)
        .toList();
    await widget.repository.save(
      data.copyWith(
        itemsByStore: {...data.itemsByStore, widget.store.id: updated},
      ),
    );
    if (mounted) setState(() => _items = updated);
  }

  void _openWhatsAppPreview() {
    if (!hasUsableWhatsAppNumber(widget.store.whatsAppNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a valid WhatsApp number in Stores first.'),
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one grocery item first.')),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WhatsAppPreviewScreen(store: widget.store, items: _items),
      ),
    );
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _openWhatsAppPreview,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _itemController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Grocery item',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onSubmitted: (_) => _addItem(),
                              decoration: const InputDecoration(
                                labelText: 'Quantity (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 112,
                            child: DropdownButtonFormField<GroceryQuantityUnit>(
                              initialValue: _unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: GroceryQuantityUnit.count,
                                  child: Text('Count'),
                                ),
                                DropdownMenuItem(
                                  value: GroceryQuantityUnit.dozen,
                                  child: Text('Dozen'),
                                ),
                                DropdownMenuItem(
                                  value: GroceryQuantityUnit.kilogram,
                                  child: Text('kg'),
                                ),
                                DropdownMenuItem(
                                  value: GroceryQuantityUnit.litre,
                                  child: Text('litre'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _unit = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Add grocery item',
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_circle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text('Add the first item to this list.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              title: Text(item.name),
                              subtitle: item.quantity.isEmpty
                                  ? null
                                  : Text(item.quantity),
                              trailing: IconButton(
                                tooltip: 'Remove ${item.name}',
                                onPressed: () => _removeItem(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
