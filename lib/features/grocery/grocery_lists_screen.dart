// TODO(voice-capture): remove legacy local merge helpers in a UI-only cleanup.
// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import '../help/app_help.dart';
import '../settings/settings_screen.dart';
import '../stores/stores_screen.dart';
import '../whatsapp/whatsapp_message.dart';
import '../whatsapp/whatsapp_preview_screen.dart';
import '../voice/gemma_command_interpreter.dart';
import '../voice/voice_command_sheet.dart';
import '../voice/voice_transcript_accumulator.dart';

class GroceryListsScreen extends StatefulWidget {
  const GroceryListsScreen({super.key, required this.repository});

  final HouseholdRepository repository;

  @override
  State<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends State<GroceryListsScreen> {
  late Future<HouseholdData> _data;
  final GemmaCommandInterpreter _gemmaInterpreter =
      const GemmaCommandInterpreter();

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
    bool voiceReview = false,
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
          voiceReview: voiceReview,
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
                  backgroundColor: Color(0xFFFDE4E8),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFF703146),
                  ),
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
    final ruleCommand = VoiceCommand.fromTranscript(
      transcript,
      data.stores.map((store) => store.name).toList(),
    );
    if (await _openGroceryFromCommand(ruleCommand, data)) return;

    final gemmaStatus = await _gemmaInterpreter.status();
    if (!mounted) return;
    if (!gemmaStatus.isReady) {
      await _showVoiceFailure(
        transcript,
        'I could not identify a grocery item and store.',
        showGemmaSetup: true,
      );
      return;
    }

    _showGemmaWorking();
    try {
      final response = await _gemmaInterpreter.interpret(
        transcript: transcript,
        storeNames: data.stores.map((store) => store.name).toList(),
      );
      final command = VoiceCommand.fromGemmaResult(
        response,
        data.stores.map((store) => store.name).toList(),
        transcript: transcript,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (await _openGroceryFromCommand(command, data)) return;
      await _showVoiceFailure(
        transcript,
        'I could not identify a grocery item and store from that request.',
      );
    } on Exception catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showVoiceFailure(
        transcript,
        'I could not understand that request on this device.',
      );
    }
  }

  Future<bool> _openGroceryFromCommand(
    VoiceCommand command,
    HouseholdData data,
  ) async {
    switch (command) {
      case AddGroceryVoiceCommand(
        :final storeName,
        :final item,
        :final quantity,
        :final unit,
      ):
        final store = _storeNamed(data, storeName);
        if (store == null || item.trim().isEmpty) return false;
        await _openEditor(
          store,
          initialItem: item,
          initialQuantity: quantity,
          initialUnit: unit,
          voiceReview: true,
        );
        return true;
      case OpenGroceryVoiceCommand(:final storeName):
        final store = storeName == null ? null : _storeNamed(data, storeName);
        if (store == null) return false;
        await _openEditor(store);
        return true;
      case UpdateStoreWhatsAppVoiceCommand(
        :final storeName,
        :final whatsAppNumber,
      ):
        final store = _storeNamed(data, storeName);
        if (store == null) return false;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => StoresScreen(
              repository: widget.repository,
              initialStoreId: store.id,
              initialWhatsApp: whatsAppNumber,
            ),
          ),
        );
        await _refresh();
        return true;
      default:
        return false;
    }
  }

  void _showGemmaWorking() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Color(0xFFFFF4C8),
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Color(0xFF8F3555)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Understanding with Gemma on this device…',
                  style: TextStyle(
                    color: Color(0xFF42363A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVoiceFailure(
    String transcript,
    String message, {
    bool showGemmaSetup = false,
  }) async {
    final action = await showDialog<_GroceryVoiceFailureAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not add an item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (showGemmaSetup) ...[
              const SizedBox(height: 14),
              const Text(
                'For more flexible wording, you can set up the optional private on-device assistant, Gemma. It runs on this phone and you still review before saving.',
              ),
            ],
            const SizedBox(height: 12),
            Text('I heard:\n“$transcript”'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _GroceryVoiceFailureAction.help),
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Grocery voice help'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8F3555),
                side: const BorderSide(color: Color(0xFF8F3555)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _GroceryVoiceFailureAction.settings),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Set up assistant in Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8F3555),
                side: const BorderSide(color: Color(0xFF8F3555)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, _GroceryVoiceFailureAction.retry),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF4C8),
              foregroundColor: const Color(0xFF8F3555),
              side: const BorderSide(color: Color(0xFF8F3555), width: 1.5),
            ),
            child: const Text('Try again'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _GroceryVoiceFailureAction.chooseStore),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C2D55),
              foregroundColor: Colors.white,
            ),
            child: const Text('Choose a store'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _GroceryVoiceFailureAction.retry:
        final data = await widget.repository.load();
        if (mounted) await _makeVoiceRequest(data);
      case _GroceryVoiceFailureAction.chooseStore:
        final data = await widget.repository.load();
        if (mounted) await _chooseStore(data);
      case _GroceryVoiceFailureAction.help:
        await _openGroceryVoiceHelp();
      case _GroceryVoiceFailureAction.settings:
        await _openSettings();
      case null:
        break;
    }
  }

  Future<void> _openGroceryVoiceHelp() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const AppHelpSheet(
      initialVoiceCategory: VoiceHelpCategory.groceryLists,
    ),
  );

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(repository: widget.repository),
      ),
    );
    if (mounted) await _refresh();
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
                    TextButton.icon(
                      onPressed: _openManageStores,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8F3555),
                      ),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Manage stores'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
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
        ? 'No items yet'
        : ready
        ? '${items.length} items · Ready to send'
        : '${items.length} items · Add a WhatsApp number to send';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        minVerticalPadding: 18,
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFDE4E8),
          child: Icon(Icons.storefront_outlined, color: Color(0xFF703146)),
        ),
        title: Text(store.name),
        subtitle: Text(status),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

enum _GroceryVoiceFailureAction { retry, chooseStore, help, settings }

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

class _GroceryVoiceCaptureSheet extends StatefulWidget {
  const _GroceryVoiceCaptureSheet();

  @override
  State<_GroceryVoiceCaptureSheet> createState() =>
      _GroceryVoiceCaptureSheetState();
}

class _GroceryVoiceCaptureSheetState extends State<_GroceryVoiceCaptureSheet> {
  final SpeechToText _speech = SpeechToText();
  final VoiceTranscriptAccumulator _voiceTranscript =
      VoiceTranscriptAccumulator();
  final ScrollController _transcriptScrollController = ScrollController();
  String _transcript = '';
  String _completedTranscript = '';
  String _lastFinalSegment = '';
  bool _holding = false;
  bool _starting = false;
  bool _speechListening = false;
  bool _restarting = false;
  String? _error;

  Future<void> _startListening() async {
    if (_holding || _starting) return;
    setState(() {
      _holding = true;
      _starting = true;
      _error = null;
      _transcript = '';
      _completedTranscript = '';
      _lastFinalSegment = '';
      _voiceTranscript.reset();
    });
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
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
    await _listenWhileHeld();
  }

  void _onSpeechStatus(String status) {
    final listening = status == 'listening';
    if (mounted) {
      setState(() {
        _speechListening = listening;
        if (!listening) {
          _voiceTranscript.commitPartial();
          _transcript = _voiceTranscript.transcript;
        }
      });
    }
    // Android can finish one recognition session during a natural pause even
    // while the user is still holding the microphone. Start another session
    // so that the remainder of the same request is captured too.
    if (!listening && _holding && !_starting) {
      _restartWhileHeld();
    }
  }

  void _restartWhileHeld() {
    if (_restarting) return;
    _restarting = true;
    Future<void>.delayed(const Duration(milliseconds: 150), () async {
      _restarting = false;
      await _listenWhileHeld();
    });
  }

  Future<void> _listenWhileHeld() async {
    if (!_holding || _speechListening) return;
    if (mounted) setState(() => _speechListening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'en_IN',
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
      ),
      onResult: (result) {
        if (!mounted) return;
        final segment = result.recognizedWords.trim();
        if (segment.isEmpty) return;
        setState(() {
          _voiceTranscript.addResult(segment, isFinal: result.finalResult);
          _transcript = _voiceTranscript.transcript;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_transcriptScrollController.hasClients) return;
          _transcriptScrollController.animateTo(
            _transcriptScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
          );
        });
      },
    );
  }

  /// Android can return a final result for only the phrase after a pause.
  /// Merge it with the visible partial transcript instead of replacing it.
  String _mergeTranscript(String first, String second) {
    final existing = first.trim();
    final incoming = second.trim();
    if (existing.isEmpty) return incoming;
    if (incoming.isEmpty ||
        existing == incoming ||
        existing.endsWith(incoming)) {
      return existing;
    }
    if (incoming.startsWith(existing) || incoming.contains(existing)) {
      return incoming;
    }

    final existingWords = existing.split(RegExp(r'\s+'));
    final incomingWords = incoming.split(RegExp(r'\s+'));
    final maxOverlap = existingWords.length < incomingWords.length
        ? existingWords.length
        : incomingWords.length;
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final existingSuffix = existingWords.sublist(
        existingWords.length - overlap,
      );
      final incomingPrefix = incomingWords.sublist(0, overlap);
      if (_sameWords(existingSuffix, incomingPrefix)) {
        return [...existingWords, ...incomingWords.sublist(overlap)].join(' ');
      }
    }
    return '$existing $incoming';
  }

  bool _sameWords(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].toLowerCase() != second[index].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _stopListening() async {
    if (!_holding && !_starting) return;
    setState(() {
      _holding = false;
      _speechListening = false;
      _voiceTranscript.commitPartial();
      _transcript = _voiceTranscript.transcript;
    });
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (_transcript.trim().isEmpty) {
      setState(
        () => _error = 'No words heard. Hold while speaking and try again.',
      );
      return;
    }
    Navigator.pop(context, _voiceTranscript.finish());
  }

  @override
  void dispose() {
    _speech.stop();
    _transcriptScrollController.dispose();
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
              'Add an item by voice',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _holding
                  ? 'Listening… release when you are done.'
                  : 'Press and hold to speak.',
            ),
            const SizedBox(height: 22),
            Container(
              height: 88,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5EA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _transcript.isEmpty
                  ? const Center(child: Text('Your words will appear here.'))
                  : Scrollbar(
                      controller: _transcriptScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _transcriptScrollController,
                        child: Text(
                          _transcript,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
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
    this.voiceReview = false,
  });

  final HouseholdRepository repository;
  final Store store;
  final String initialItem;
  final String initialQuantity;
  final GroceryQuantityUnit initialUnit;
  final bool voiceReview;

  @override
  State<GroceryListEditor> createState() => _GroceryListEditorState();
}

class _GroceryListEditorState extends State<GroceryListEditor> {
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  final GemmaCommandInterpreter _gemmaInterpreter =
      const GemmaCommandInterpreter();
  late GroceryQuantityUnit _unit;
  List<GroceryItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _initialize();
  }

  Future<void> _initialize() async {
    await _load();
    if (!mounted) return;
    if (widget.voiceReview) {
      await _reviewVoiceItem(
        item: widget.initialItem,
        quantity: widget.initialQuantity,
        unit: widget.initialUnit,
      );
      return;
    }
    _itemController.text = widget.initialItem;
    _quantityController.text = widget.initialQuantity;
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
    await _saveItem(
      name: name,
      quantity: _quantityController.text.trim(),
      unit: _unit,
    );
    _itemController.clear();
    _quantityController.clear();
  }

  Future<void> _saveItem({
    required String name,
    required String quantity,
    required GroceryQuantityUnit unit,
  }) async {
    final item = GroceryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      quantity: groceryQuantityLabel(quantity, unit),
    );
    final data = await widget.repository.load();
    final updated = [...data.itemsFor(widget.store.id), item];
    await widget.repository.save(
      data.copyWith(
        itemsByStore: {...data.itemsByStore, widget.store.id: updated},
      ),
    );
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

  Future<void> _makeVoiceRequest() async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _GroceryVoiceCaptureSheet(),
    );
    if (!mounted || transcript == null || transcript.trim().isEmpty) return;

    final contextualTranscript = _contextualTranscript(transcript);
    final command = VoiceCommand.fromTranscript(contextualTranscript, [
      widget.store.name,
    ]);
    if (await _applyVoiceCommand(command)) return;

    final gemmaStatus = await _gemmaInterpreter.status();
    if (!mounted) return;
    if (!gemmaStatus.isReady) {
      await _showVoiceFailure(
        transcript,
        'I could not identify a grocery item.',
        showGemmaSetup: true,
      );
      return;
    }

    _showGemmaWorking();
    try {
      final response = await _gemmaInterpreter.interpret(
        transcript: contextualTranscript,
        storeNames: [widget.store.name],
      );
      final gemmaCommand = VoiceCommand.fromGemmaResult(response, [
        widget.store.name,
      ], transcript: contextualTranscript);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (await _applyVoiceCommand(gemmaCommand)) return;
      await _showVoiceFailure(
        transcript,
        'I could not identify a grocery item from that request.',
      );
    } on Exception catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showVoiceFailure(
        transcript,
        'I could not understand that request on this device.',
      );
    }
  }

  String _contextualTranscript(String transcript) {
    final normalized = transcript.trim().replaceFirst(
      RegExp(r'^please\s+', caseSensitive: false),
      '',
    );
    if (RegExp(
      r'\b(?:update|change|set)\b.*\bwhats\s*app\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return normalized;
    }
    final storeExpression = RegExp.escape(
      widget.store.name,
    ).replaceAll(' ', r'\\s*');
    if (RegExp(storeExpression, caseSensitive: false).hasMatch(normalized)) {
      return normalized;
    }
    final request = normalized.toLowerCase().startsWith('add ')
        ? normalized
        : 'Add $normalized';
    return '$request to ${widget.store.name}';
  }

  Future<bool> _applyVoiceCommand(VoiceCommand command) async {
    if (command case UpdateStoreWhatsAppVoiceCommand(:final whatsAppNumber)) {
      final data = await widget.repository.load();
      Store? currentStore;
      for (final store in data.stores) {
        if (store.id == widget.store.id) {
          currentStore = store;
          break;
        }
      }
      if (currentStore == null || !mounted) return false;
      final storeToEdit = currentStore;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => StoresScreen(
            repository: widget.repository,
            initialStoreId: storeToEdit.id,
            initialWhatsApp: whatsAppNumber,
          ),
        ),
      );
      if (mounted) setState(() => _items = data.itemsFor(widget.store.id));
      return true;
    }
    if (command is! AddGroceryVoiceCommand || command.item.trim().isEmpty) {
      return false;
    }
    await _reviewVoiceItem(
      item: command.item,
      quantity: command.quantity,
      unit: command.unit,
    );
    return true;
  }

  Future<void> _reviewVoiceItem({
    required String item,
    required String quantity,
    required GroceryQuantityUnit unit,
  }) async {
    final draft = await showDialog<_VoiceGroceryDraft>(
      context: context,
      builder: (_) =>
          _VoiceGroceryItemDialog(item: item, quantity: quantity, unit: unit),
    );
    if (draft == null || !mounted) return;
    await _saveItem(
      name: draft.item,
      quantity: draft.quantity,
      unit: draft.unit,
    );
  }

  void _showGemmaWorking() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Color(0xFFFFF4C8),
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Color(0xFF8F3555)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Understanding with Gemma on this device…',
                  style: TextStyle(
                    color: Color(0xFF42363A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVoiceFailure(
    String transcript,
    String message, {
    bool showGemmaSetup = false,
  }) async {
    final action = await showDialog<_StoreGroceryVoiceFailureAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not add an item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (showGemmaSetup) ...[
              const SizedBox(height: 14),
              const Text(
                'For more flexible wording, you can set up the optional private on-device assistant, Gemma. It runs on this phone and you still review before saving.',
              ),
            ],
            const SizedBox(height: 12),
            Text('I heard:\n“$transcript”'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _StoreGroceryVoiceFailureAction.help),
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Grocery voice help'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8F3555),
                side: const BorderSide(color: Color(0xFF8F3555)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _StoreGroceryVoiceFailureAction.settings,
              ),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Set up assistant in Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8F3555),
                side: const BorderSide(color: Color(0xFF8F3555)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, _StoreGroceryVoiceFailureAction.cancel),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF4C8),
              foregroundColor: const Color(0xFF8F3555),
              side: const BorderSide(color: Color(0xFF8F3555), width: 1.5),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _StoreGroceryVoiceFailureAction.retry),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C2D55),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _StoreGroceryVoiceFailureAction.retry:
        await _makeVoiceRequest();
      case _StoreGroceryVoiceFailureAction.help:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => const AppHelpSheet(
            initialVoiceCategory: VoiceHelpCategory.groceryLists,
          ),
        );
      case _StoreGroceryVoiceFailureAction.settings:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsScreen(repository: widget.repository),
          ),
        );
      case _StoreGroceryVoiceFailureAction.cancel:
      case null:
        break;
    }
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
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        leadingWidth: 94,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 8, right: 4),
            foregroundColor: const Color(0xFF796C70),
          ),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back'),
        ),
        actions: [
          IconButton.filled(
            tooltip: 'Add item by voice',
            onPressed: _loading ? null : _makeVoiceRequest,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF2B8C5),
              foregroundColor: const Color(0xFF703146),
            ),
            icon: const Icon(Icons.mic_none_outlined),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _loading ? null : _openWhatsAppPreview,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB64E70),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFFDE4E8),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFF703146),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.store.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                              key: ValueKey(_unit),
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

class _VoiceGroceryDraft {
  const _VoiceGroceryDraft({
    required this.item,
    required this.quantity,
    required this.unit,
  });

  final String item;
  final String quantity;
  final GroceryQuantityUnit unit;
}

enum _StoreGroceryVoiceFailureAction { retry, help, settings, cancel }

class _VoiceGroceryItemDialog extends StatefulWidget {
  const _VoiceGroceryItemDialog({
    required this.item,
    required this.quantity,
    required this.unit,
  });

  final String item;
  final String quantity;
  final GroceryQuantityUnit unit;

  @override
  State<_VoiceGroceryItemDialog> createState() =>
      _VoiceGroceryItemDialogState();
}

class _VoiceGroceryItemDialogState extends State<_VoiceGroceryItemDialog> {
  late final TextEditingController _itemController;
  late final TextEditingController _quantityController;
  late GroceryQuantityUnit _unit;

  @override
  void initState() {
    super.initState();
    _itemController = TextEditingController(text: widget.item);
    _quantityController = TextEditingController(text: widget.quantity);
    _unit = widget.unit;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add this item?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Grocery item'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<GroceryQuantityUnit>(
                    key: ValueKey(_unit),
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
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
                      if (value != null) setState(() => _unit = value);
                    },
                  ),
                ),
              ],
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
            final item = _itemController.text.trim();
            if (item.isEmpty) return;
            Navigator.pop(
              context,
              _VoiceGroceryDraft(
                item: item,
                quantity: _quantityController.text.trim(),
                unit: _unit,
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
