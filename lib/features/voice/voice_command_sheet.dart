import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gemma_command_interpreter.dart';

sealed class VoiceCommand {
  const VoiceCommand();

  factory VoiceCommand.fromTranscript(
    String transcript,
    List<String> storeNames,
  ) {
    final normalized = transcript.trim().toLowerCase();
    final contactMatch = RegExp(
      r'^add\s+(?:a\s+|the\s+)?contact\s+(.+?)\s+(?:phone\s+)?number\s+(?:is\s+)?(.+)$',
    ).firstMatch(normalized);
    if (contactMatch != null) {
      return AddContactVoiceCommand(
        name: displayContactName(contactMatch.group(1)!.trim()),
        phoneNumber: spokenPhoneNumber(contactMatch.group(2)!.trim()),
      );
    }
    final directContactMatch = RegExp(
      r'^add\s+(?:a\s+|the\s+)?contact\s+(.+?)\s+(\+?[\d][\d\s-]{5,})[.!]?$',
    ).firstMatch(normalized);
    if (directContactMatch != null) {
      return AddContactVoiceCommand(
        name: displayContactName(directContactMatch.group(1)!.trim()),
        phoneNumber: spokenPhoneNumber(directContactMatch.group(2)!.trim()),
      );
    }
    if (RegExp(r'^open\s+(?:the\s+)?stores?[.!]?$').hasMatch(normalized)) {
      return const OpenStoresVoiceCommand();
    }
    if (RegExp(
      r'^(?:show(?:\s+me)?|go\s+to|open)(?:\s+the)?\s+contacts?(?:\s+list)?[.!]?$',
    ).hasMatch(normalized)) {
      return const OpenContactsVoiceCommand();
    }
    final addStoreWithWhatsAppMatch = RegExp(
      r'^(?:please\s+)?add\s+(?:a\s+|the\s+)?store\s+(.+?)\s+whats\s*app\s+(?:number\s+)?(?:is\s+)?(.+)$',
    ).firstMatch(normalized);
    if (addStoreWithWhatsAppMatch != null) {
      return AddStoreVoiceCommand(
        name: displayContactName(addStoreWithWhatsAppMatch.group(1)!.trim()),
        whatsAppNumber: spokenPhoneNumber(
          addStoreWithWhatsAppMatch.group(2)!.trim(),
        ),
      );
    }
    final addStoreMatch = RegExp(
      r'^(?:please\s+)?add\s+(?:a\s+|the\s+)?store\s+(.+?)[.!]?$',
    ).firstMatch(normalized);
    if (addStoreMatch != null) {
      return AddStoreVoiceCommand(
        name: displayContactName(addStoreMatch.group(1)!.trim()),
      );
    }
    for (final store in storeNames) {
      final normalizedStore = store.toLowerCase();
      final flexibleStoreName = normalizedStore
          .split(RegExp(r'\s+'))
          .map(RegExp.escape)
          .join(r'\s*');
      final updateWhatsAppPatterns = [
        RegExp(
          '^(?:please\\s+)?(?:update|change|set)\\s+(?:the\\s+)?whats\\s*app\\s+(?:number\\s+)?(?:for\\s+)?$flexibleStoreName\\s+(?:to|is)\\s+(.+?)[.!]?\\s*${r'$'}',
        ),
        RegExp(
          '^(?:please\\s+)?(?:update|change|set)\\s+(?:the\\s+)?$flexibleStoreName\\s+whats\\s*app\\s+(?:number\\s+)?(?:to|is)\\s+(.+?)[.!]?\\s*${r'$'}',
        ),
      ];
      for (final pattern in updateWhatsAppPatterns) {
        final updateMatch = pattern.firstMatch(normalized);
        if (updateMatch == null) continue;
        final whatsAppNumber = spokenPhoneNumber(updateMatch.group(1)!.trim());
        if (whatsAppNumber.isNotEmpty) {
          return UpdateStoreWhatsAppVoiceCommand(
            storeName: store,
            whatsAppNumber: whatsAppNumber,
          );
        }
      }
      final addPattern = RegExp(
        '^(?:please\\s+)?add\\s+(.+?)\\s+to\\s+(?:the\\s+)?$flexibleStoreName(?:\\s+list)?[.!]?\\s*',
      );
      final addMatch = addPattern.firstMatch(normalized);
      if (addMatch != null) {
        final grocery = groceryDetails(addMatch.group(1)!.trim());
        return AddGroceryVoiceCommand(
          storeName: store,
          item: grocery.item,
          quantity: grocery.quantity,
          unit: grocery.unit,
        );
      }
      if (normalized.contains(normalizedStore) &&
          (normalized.contains('list') || normalized.contains('grocery'))) {
        return OpenGroceryVoiceCommand(storeName: store);
      }
    }
    if (storeNames.length == 1) {
      final updateCurrentStoreMatch = RegExp(
        r'^(?:please\s+)?(?:update|change|set)\s+(?:the\s+)?whats\s*app\s+(?:number\s+)?(?:to|is)\s+(.+?)[.!]?\s*$',
      ).firstMatch(normalized);
      if (updateCurrentStoreMatch != null) {
        final whatsAppNumber = spokenPhoneNumber(
          updateCurrentStoreMatch.group(1)!.trim(),
        );
        if (whatsAppNumber.isNotEmpty) {
          return UpdateStoreWhatsAppVoiceCommand(
            storeName: storeNames.single,
            whatsAppNumber: whatsAppNumber,
          );
        }
      }
    }
    if (normalized.contains('grocery') || normalized.contains('list')) {
      return const OpenGroceryVoiceCommand();
    }
    return const UnrecognizedVoiceCommand();
  }

  factory VoiceCommand.fromGemmaResult(
    Map<Object?, Object?> result,
    List<String> storeNames, {
    String transcript = '',
  }) {
    final action = (result['action'] as String? ?? '').trim();
    final store = _matchingStore(result['store'] as String? ?? '', storeNames);
    final rawItem = (result['item'] as String? ?? '').trim();
    final itemDetails = groceryDetails(rawItem);
    final modelQuantity = groceryQuantity(result['quantity'] as String? ?? '');
    final interpretedQuantity = modelQuantity.isEmpty
        ? itemDetails.quantity
        : modelQuantity;
    final interpretedUnit = modelQuantity.isEmpty
        ? itemDetails.unit
        : groceryUnitFromValue(result['unit'] as String? ?? '');
    final dozenFromTranscript = groceryDozenFromTranscript(transcript);
    final quantity = dozenFromTranscript?.quantity ?? interpretedQuantity;
    final unit = dozenFromTranscript?.unit ?? interpretedUnit;
    final item = itemDetails.quantity.isEmpty ? rawItem : itemDetails.item;
    final name = (result['name'] as String? ?? '').trim();
    final phone = spokenPhoneNumber(result['phoneNumber'] as String? ?? '');
    final whatsApp = spokenPhoneNumber(
      result['whatsAppNumber'] as String? ?? '',
    );

    return switch (action) {
      'add_grocery' when store != null && item.isNotEmpty =>
        AddGroceryVoiceCommand(
          storeName: store,
          item: item,
          quantity: quantity,
          unit: unit,
        ),
      'open_grocery' => OpenGroceryVoiceCommand(storeName: store),
      'add_contact' when name.isNotEmpty => AddContactVoiceCommand(
        name: displayContactName(name),
        phoneNumber: phone,
      ),
      'open_stores' => const OpenStoresVoiceCommand(),
      'open_contacts' => const OpenContactsVoiceCommand(),
      'add_store' when name.isNotEmpty => AddStoreVoiceCommand(
        name: displayContactName(name),
        whatsAppNumber: whatsApp,
      ),
      'update_store_whatsapp' when store != null && whatsApp.isNotEmpty =>
        UpdateStoreWhatsAppVoiceCommand(
          storeName: store,
          whatsAppNumber: whatsApp,
        ),
      _ => const UnrecognizedVoiceCommand(),
    };
  }

  static String? _matchingStore(String candidate, List<String> storeNames) {
    final normalizedCandidate = _storeKey(candidate);
    if (normalizedCandidate.isEmpty) return null;
    for (final store in storeNames) {
      if (_storeKey(store) == normalizedCandidate) return store;
    }
    return null;
  }

  static String _storeKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String spokenPhoneNumber(String value) {
  const digits = {
    'zero': '0',
    'oh': '0',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
  };
  final words = value.split(RegExp(r'[\s,-]+'));
  final converted = words.map((word) => digits[word] ?? word).join();
  return converted.replaceAll(RegExp(r'[^+\d]'), '');
}

String displayContactName(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class OpenGroceryVoiceCommand extends VoiceCommand {
  const OpenGroceryVoiceCommand({this.storeName});

  final String? storeName;
}

class AddGroceryVoiceCommand extends VoiceCommand {
  const AddGroceryVoiceCommand({
    required this.storeName,
    required this.item,
    this.quantity = '',
    this.unit = GroceryQuantityUnit.count,
  });

  final String storeName;
  final String item;
  final String quantity;
  final GroceryQuantityUnit unit;
}

enum GroceryQuantityUnit { count, dozen, kilogram, litre }

class GroceryDetails {
  const GroceryDetails({
    required this.item,
    required this.quantity,
    required this.unit,
  });

  final String item;
  final String quantity;
  final GroceryQuantityUnit unit;
}

GroceryDetails groceryDetails(String value) {
  final normalized = _normalizeAndHalfQuantity(value.trim()).replaceFirst(
    RegExp(
      r'^(?:and\s+)?(?:(?:a\s+)?half(?:\s+a)?|1\s*/\s*2)\b',
      caseSensitive: false,
    ),
    '0.5',
  );
  final match = RegExp(
    r'^(?:(one|two|three|four|five|six|seven|eight|nine|ten|\d+(?:\.\d+)?)\s*(dozens|dozen|kilo\s*grams?|kilograms|kilogram|kilos|kilo|kgs|kg|litres|litre|liters|liter|counts|count|pieces|piece|packets|packet|l)?\s*(?:of\s+)?)?(.+)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) {
    return GroceryDetails(
      item: normalized,
      quantity: '',
      unit: GroceryQuantityUnit.count,
    );
  }
  final quantity = groceryQuantity(match.group(1) ?? '');
  final item = (match.group(3) ?? normalized).trim();
  return GroceryDetails(
    item: item.isEmpty ? normalized : item,
    quantity: quantity,
    unit: groceryUnitFromValue(match.group(2) ?? ''),
  );
}

String _normalizeAndHalfQuantity(String value) {
  final match = RegExp(
    r'^(one|two|three|four|five|six|seven|eight|nine|ten|\d+(?:\.\d+)?)\s+and\s+(?:a\s+)?half\b',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return value;
  final whole = groceryQuantity(match.group(1) ?? '');
  if (whole.isEmpty) return value;
  final quantity = double.parse(whole) + 0.5;
  return value.replaceRange(0, match.end, quantity.toString());
}

String groceryQuantity(String value) {
  const spokenNumbers = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'half': '0.5',
  };
  final normalized = value.trim().toLowerCase();
  return spokenNumbers[normalized] ??
      (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized) ? normalized : '');
}

GroceryQuantityUnit groceryUnitFromValue(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '');
  if (const {'dozen', 'dozens'}.contains(normalized)) {
    return GroceryQuantityUnit.dozen;
  }
  if (const {
    'kg',
    'kgs',
    'kilo',
    'kilos',
    'kilogram',
    'kilograms',
  }.contains(normalized)) {
    return GroceryQuantityUnit.kilogram;
  }
  if (const {'l', 'litre', 'litres', 'liter', 'liters'}.contains(normalized)) {
    return GroceryQuantityUnit.litre;
  }
  return GroceryQuantityUnit.count;
}

GroceryDetails? groceryDozenFromTranscript(String transcript) {
  final match = RegExp(
    r'\b(one|two|three|four|five|six|seven|eight|nine|ten|\d+(?:\.\d+)?)\s+dozens?\b',
    caseSensitive: false,
  ).firstMatch(transcript);
  if (match == null) return null;
  final quantity = groceryQuantity(match.group(1) ?? '');
  if (quantity.isEmpty) return null;
  return GroceryDetails(
    item: '',
    quantity: quantity,
    unit: GroceryQuantityUnit.dozen,
  );
}

String groceryQuantityLabel(String quantity, GroceryQuantityUnit unit) {
  if (quantity.isEmpty) return '';
  return switch (unit) {
    GroceryQuantityUnit.count => quantity,
    GroceryQuantityUnit.dozen => '$quantity dozen',
    GroceryQuantityUnit.kilogram => '$quantity kg',
    GroceryQuantityUnit.litre => '$quantity litre',
  };
}

class AddContactVoiceCommand extends VoiceCommand {
  const AddContactVoiceCommand({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;
}

class OpenStoresVoiceCommand extends VoiceCommand {
  const OpenStoresVoiceCommand();
}

class OpenContactsVoiceCommand extends VoiceCommand {
  const OpenContactsVoiceCommand();
}

class AddStoreVoiceCommand extends VoiceCommand {
  const AddStoreVoiceCommand({required this.name, this.whatsAppNumber = ''});

  final String name;
  final String whatsAppNumber;
}

class UpdateStoreWhatsAppVoiceCommand extends VoiceCommand {
  const UpdateStoreWhatsAppVoiceCommand({
    required this.storeName,
    required this.whatsAppNumber,
  });

  final String storeName;
  final String whatsAppNumber;
}

class UnrecognizedVoiceCommand extends VoiceCommand {
  const UnrecognizedVoiceCommand();
}

class VoiceCommandSheet extends StatefulWidget {
  const VoiceCommandSheet({
    super.key,
    required this.storeNames,
    this.initialTranscript = '',
    this.gemmaInterpreter = const GemmaCommandInterpreter(),
  });

  final List<String> storeNames;
  final String initialTranscript;
  final GemmaCommandInterpreter gemmaInterpreter;

  @override
  State<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

class _VoiceCommandSheetState extends State<VoiceCommandSheet> {
  final TextEditingController _transcriptController = TextEditingController();
  String _transcript = '';
  String _status = 'Review what I heard.';
  GemmaModelStatus? _gemmaStatus;
  VoiceCommand? _gemmaCommand;
  int? _gemmaElapsedMs;
  bool _usedRuleFallback = false;
  bool _interpretingWithGemma = false;

  @override
  void initState() {
    super.initState();
    _transcript = widget.initialTranscript;
    _transcriptController.text = _transcript;
    if (_transcript.isNotEmpty) _status = 'Review what I heard.';
    _loadGemmaStatus();
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _loadGemmaStatus() async {
    final status = await widget.gemmaInterpreter.status();
    if (mounted) setState(() => _gemmaStatus = status);
  }

  Future<void> _interpretWithGemma() async {
    if (_transcript.trim().isEmpty || _interpretingWithGemma) return;
    setState(() {
      _interpretingWithGemma = true;
      _status = 'Understanding this on your device…';
    });
    try {
      final response = await widget.gemmaInterpreter.interpret(
        transcript: _transcript,
        storeNames: widget.storeNames,
      );
      final gemmaCommand = VoiceCommand.fromGemmaResult(
        response,
        widget.storeNames,
        transcript: _transcript,
      );
      final ruleCommand = VoiceCommand.fromTranscript(
        _transcript,
        widget.storeNames,
      );
      final useRuleFallback =
          gemmaCommand is UnrecognizedVoiceCommand &&
          ruleCommand is! UnrecognizedVoiceCommand;
      final command = useRuleFallback ? ruleCommand : gemmaCommand;
      if (!mounted) return;
      setState(() {
        _gemmaCommand = command;
        _gemmaElapsedMs = (response['elapsedMs'] as num?)?.toInt();
        _usedRuleFallback = useRuleFallback;
        _status = useRuleFallback
            ? 'Gemma was unsure, but this command was safely recognised.'
            : command is UnrecognizedVoiceCommand
            ? 'Gemma could not safely match this request. The usual review is still available.'
            : 'Understood on this device with Gemma. Please review before continuing.';
      });
    } on PlatformException catch (exception) {
      if (!mounted) return;
      setState(
        () => _status =
            exception.message ?? 'Gemma could not interpret that request.',
      );
    } finally {
      if (mounted) setState(() => _interpretingWithGemma = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final command =
        _gemmaCommand ??
        VoiceCommand.fromTranscript(_transcript, widget.storeNames);
    final canReview = _transcript.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tap to speak', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 18),
            if (_transcript.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('I heard', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              TextField(
                controller: _transcriptController,
                onChanged: (value) => setState(() {
                  _transcript = value;
                  _gemmaCommand = null;
                  _gemmaElapsedMs = null;
                  _usedRuleFallback = false;
                  _status = 'Review what I heard.';
                }),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  helperText: 'Edit the words before continuing if needed.',
                ),
              ),
            ],
            if (canReview && _gemmaStatus?.isReady == true) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _interpretingWithGemma ? null : _interpretWithGemma,
                icon: _interpretingWithGemma
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _interpretingWithGemma
                      ? 'Understanding on device…'
                      : 'Interpret with on-device Gemma (pilot)',
                ),
              ),
            ],
            if (_gemmaCommand != null) ...[
              const SizedBox(height: 12),
              _GemmaResultCard(
                command: _gemmaCommand!,
                elapsedMs: _gemmaElapsedMs,
                usedRuleFallback: _usedRuleFallback,
              ),
            ],
            if (canReview) ...[
              const SizedBox(height: 18),
              _CommandReview(command: command),
            ],
            if (_transcript.isEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Hold the microphone on the home screen while speaking, then release to review.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GemmaResultCard extends StatelessWidget {
  const _GemmaResultCard({
    required this.command,
    required this.elapsedMs,
    required this.usedRuleFallback,
  });

  final VoiceCommand command;
  final int? elapsedMs;
  final bool usedRuleFallback;

  @override
  Widget build(BuildContext context) {
    final (icon, interpretation) = switch (command) {
      AddGroceryVoiceCommand(:final storeName, :final item) => (
        Icons.shopping_basket_outlined,
        'Add ${groceryItemWithQuantity(command)} to $storeName',
      ),
      OpenGroceryVoiceCommand(:final storeName) => (
        Icons.list_alt_outlined,
        storeName == null ? 'Open all grocery lists' : 'Open $storeName list',
      ),
      AddContactVoiceCommand(:final name, :final phoneNumber) => (
        Icons.person_add_alt_1_outlined,
        phoneNumber.isEmpty
            ? 'Add contact $name'
            : 'Add contact $name: $phoneNumber',
      ),
      OpenStoresVoiceCommand() => (Icons.storefront_outlined, 'Open stores'),
      OpenContactsVoiceCommand() => (Icons.contacts_outlined, 'Open contacts'),
      AddStoreVoiceCommand(:final name, :final whatsAppNumber) => (
        Icons.add_business_outlined,
        whatsAppNumber.isEmpty
            ? 'Add store $name'
            : 'Add store $name: WhatsApp $whatsAppNumber',
      ),
      UpdateStoreWhatsAppVoiceCommand(
        :final storeName,
        :final whatsAppNumber,
      ) =>
        (
          Icons.edit_outlined,
          'Update $storeName WhatsApp number: $whatsAppNumber',
        ),
      UnrecognizedVoiceCommand() => (
        Icons.help_outline,
        'No safe action was identified from this request',
      ),
    };
    final theme = Theme.of(context);
    return Card(
      color: const Color(0xFFFFF0F3),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFB64E70)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usedRuleFallback
                        ? 'Built-in command match'
                        : 'Gemma interpreted',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF8F3555),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(interpretation, style: theme.textTheme.titleSmall),
                  if (elapsedMs != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Processed privately on this device in ${elapsedMs! / 1000.0}s',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandReview extends StatelessWidget {
  const _CommandReview({required this.command});

  final VoiceCommand command;

  @override
  Widget build(BuildContext context) {
    switch (command) {
      case AddGroceryVoiceCommand(:final storeName):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          child: Text(
            'Review ${groceryItemWithQuantity(command)} for $storeName',
          ),
        );
      case AddContactVoiceCommand(:final name):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: Text('Review contact $name'),
        );
      case OpenStoresVoiceCommand():
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          child: const Text('Open stores'),
        );
      case OpenContactsVoiceCommand():
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          child: const Text('Open contacts'),
        );
      case AddStoreVoiceCommand(:final name):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: Text('Review store $name'),
        );
      case UpdateStoreWhatsAppVoiceCommand(:final storeName):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: Text('Review $storeName WhatsApp number'),
        );
      case OpenGroceryVoiceCommand(:final storeName):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          child: Text(
            storeName == null ? 'Open grocery lists' : 'Open $storeName list',
          ),
        );
      case UnrecognizedVoiceCommand():
        return const SizedBox.shrink();
    }
  }
}

String groceryItemWithQuantity(VoiceCommand command) {
  if (command is! AddGroceryVoiceCommand) return '';
  final quantity = groceryQuantityLabel(command.quantity, command.unit);
  return quantity.isEmpty ? command.item : '$quantity ${command.item}';
}
