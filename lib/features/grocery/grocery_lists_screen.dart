import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import '../whatsapp/whatsapp_message.dart';
import '../whatsapp/whatsapp_preview_screen.dart';
import '../voice/voice_command_sheet.dart';
import '../stores/stores_screen.dart';

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

  Future<void> _openEditor(
    Store store, {
    String initialItem = '',
    String initialQuantity = '',
    GroceryQuantityUnit initialUnit = GroceryQuantityUnit.count,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GroceryListEditor(
          repository: widget.repository,
          store: store,
          initialItem: initialItem,
          initialQuantity: initialQuantity,
          initialUnit: initialUnit,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _chooseStore(HouseholdData data) async {
    final store = await showModalBottomSheet<Store>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a store')),
            for (final store in data.stores)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF1C9),
                  child: Icon(Icons.storefront_outlined),
                ),
                title: Text(store.name),
                onTap: () => Navigator.pop(context, store),
              ),
          ],
        ),
      ),
    );
    if (store != null && mounted) await _openEditor(store);
  }

  Future<void> _openManageStores() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StoresScreen(repository: widget.repository),
      ),
    );
    await _refresh();
  }

  Future<void> _openWhatsAppPreview(Store store, List<GroceryItem> items) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsAppPreviewScreen(store: store, items: items),
      ),
    );
  }

  Store? _storeNamed(HouseholdData data, String name) {
    for (final store in data.stores) {
      if (store.name.toLowerCase() == name.toLowerCase()) return store;
    }
    return null;
  }

  Future<void> _makeVoiceRequest(HouseholdData data) async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _GroceryVoiceCaptureSheet(),
    );
    if (!mounted || transcript == null || transcript.trim().isEmpty) return;
    final command = await showModalBottomSheet<VoiceCommand>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: VoiceCommandSheet(
          storeNames: data.stores.map((store) => store.name).toList(),
          initialTranscript: transcript,
        ),
      ),
    );
    if (!mounted || command == null) return;
    switch (command) {
      case AddGroceryVoiceCommand(
        :final storeName,
        :final item,
        :final quantity,
        :final unit,
      ):
        final store = _storeNamed(data, storeName);
        if (store != null) {
          await _openEditor(
            store,
            initialItem: item,
            initialQuantity: quantity,
            initialUnit: unit,
          );
        }
      case OpenGroceryVoiceCommand(storeName: null):
        break;
      case OpenGroceryVoiceCommand(:final storeName):
        if (storeName != null) {
          final store = _storeNamed(data, storeName);
          if (store != null) await _openEditor(store);
        }
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Try “Add milk to Village.”')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: FutureBuilder<HouseholdData>(
          future: _data,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final readyStore = data.stores.cast<Store?>().firstWhere(
              (store) =>
                  store != null &&
                  data.itemsFor(store.id).isNotEmpty &&
                  hasUsableWhatsAppNumber(store.whatsAppNumber),
              orElse: () => null,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    foregroundColor: const Color(0xFF796C70),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back'),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Grocery lists',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _openManageStores,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8F3555),
                      ),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: () => _chooseStore(data),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    alignment: Alignment.centerLeft,
                    backgroundColor: const Color(0xFFFFF4C8),
                    foregroundColor: const Color(0xFF703146),
                    side: const BorderSide(
                      color: Color(0xFFC99525),
                      width: 1.5,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create a list for a store'),
                ),
                const SizedBox(height: 14),
                for (final store in data.stores) ...[
                  _GroceryStoreCard(
                    store: store,
                    items: data.itemsFor(store.id),
                    onTap: () => _openEditor(store),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 16),
                _VoiceGroceryTip(onVoiceRequest: () => _makeVoiceRequest(data)),
                if (readyStore != null) ...[
                  const SizedBox(height: 24),
                  _ReadyToSendCard(
                    store: readyStore,
                    items: data.itemsFor(readyStore.id),
                    onEdit: () => _openEditor(readyStore),
                    onSend: () => _openWhatsAppPreview(
                      readyStore,
                      data.itemsFor(readyStore.id),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroceryStoreCard extends StatelessWidget {
  const _GroceryStoreCard({
    required this.store,
    required this.items,
    required this.onTap,
  });

  final Store store;
  final List<GroceryItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready =
        items.isNotEmpty && hasUsableWhatsAppNumber(store.whatsAppNumber);
    final status = items.isEmpty
        ? 'No items · Draft'
        : '${items.length} items · ${ready ? 'Ready to send' : 'Draft'}';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        minVerticalPadding: 18,
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF1C9),
          child: Icon(Icons.storefront_outlined),
        ),
        title: Text(store.name),
        subtitle: Text(status),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _VoiceGroceryTip extends StatelessWidget {
  const _VoiceGroceryTip({this.onVoiceRequest});

  final Future<void> Function()? onVoiceRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFFFE1E7),
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.graphic_eq),
                SizedBox(width: 10),
                Text('Try a voice request'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('“Add 1 litre milk to Village.”'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onVoiceRequest == null
                  ? null
                  : () => onVoiceRequest!(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB64E70),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.mic_none_outlined),
              label: const Text('Make a voice request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyToSendCard extends StatelessWidget {
  const _ReadyToSendCard({
    required this.store,
    required this.items,
    required this.onEdit,
    required this.onSend,
  });

  final Store store;
  final List<GroceryItem> items;
  final VoidCallback onEdit;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final itemNames = items.map((item) => item.name).join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to send?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text('To: ${store.name} · WhatsApp\n$itemNames'),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8F3555),
                      side: const BorderSide(
                        color: Color(0xFF9D4664),
                        width: 1.4,
                      ),
                    ),
                    child: const Text('Edit list'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB64E70),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Send on WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroceryVoiceCaptureSheet extends StatefulWidget {
  const _GroceryVoiceCaptureSheet();

  @override
  State<_GroceryVoiceCaptureSheet> createState() =>
      _GroceryVoiceCaptureSheetState();
}

class _GroceryVoiceCaptureSheetState extends State<_GroceryVoiceCaptureSheet> {
  final SpeechToText _speech = SpeechToText();
  String _transcript = '';
  bool _holding = false;
  bool _starting = false;
  String? _error;

  Future<void> _startListening() async {
    if (_holding || _starting) return;
    setState(() {
      _holding = true;
      _starting = true;
      _error = null;
      _transcript = '';
    });
    final available = await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _error = error.errorMsg);
      },
    );
    if (!mounted || !_holding || !available) {
      if (mounted) {
        setState(() {
          _holding = false;
          _starting = false;
          _error ??= 'Microphone is not available.';
        });
      }
      return;
    }
    setState(() => _starting = false);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'en_IN',
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
      ),
      onResult: (result) {
        if (mounted) setState(() => _transcript = result.recognizedWords);
      },
    );
  }

  Future<void> _stopListening() async {
    if (!_holding && !_starting) return;
    setState(() => _holding = false);
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (_transcript.trim().isEmpty) {
      setState(
        () => _error = 'No words heard. Hold while speaking and try again.',
      );
      return;
    }
    Navigator.pop(context, _transcript.trim());
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Make a voice request',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _holding
                  ? 'Listening… release when you are done.'
                  : 'Press and hold to speak.',
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _holding
                      ? const Color(0xFFB64E70)
                      : const Color(0xFFF4BEC9),
                ),
                child: Icon(
                  _holding ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _transcript.isEmpty
                  ? 'Your words will appear here.'
                  : _transcript,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFF9D4664))),
            ],
          ],
        ),
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
