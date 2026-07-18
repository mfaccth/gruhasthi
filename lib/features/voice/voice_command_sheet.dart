import 'package:flutter/material.dart';

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
      final addPattern = RegExp(
        '^add\\s+(.+?)\\s+to\\s+(?:the\\s+)?$flexibleStoreName(?:\\s+list)?[.!]?\\s*',
      );
      final addMatch = addPattern.firstMatch(normalized);
      if (addMatch != null) {
        return AddGroceryVoiceCommand(
          storeName: store,
          item: addMatch.group(1)!.trim(),
        );
      }
      if (normalized.contains(normalizedStore) &&
          (normalized.contains('list') || normalized.contains('grocery'))) {
        return OpenGroceryVoiceCommand(storeName: store);
      }
    }
    if (normalized.contains('grocery') || normalized.contains('list')) {
      return const OpenGroceryVoiceCommand();
    }
    return const UnrecognizedVoiceCommand();
  }
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
  const AddGroceryVoiceCommand({required this.storeName, required this.item});

  final String storeName;
  final String item;
}

class AddContactVoiceCommand extends VoiceCommand {
  const AddContactVoiceCommand({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;
}

class OpenStoresVoiceCommand extends VoiceCommand {
  const OpenStoresVoiceCommand();
}

class AddStoreVoiceCommand extends VoiceCommand {
  const AddStoreVoiceCommand({required this.name, this.whatsAppNumber = ''});

  final String name;
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
  });

  final List<String> storeNames;
  final String initialTranscript;

  @override
  State<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

class _VoiceCommandSheetState extends State<VoiceCommandSheet> {
  final TextEditingController _transcriptController = TextEditingController();
  String _transcript = '';
  String _status = 'Review what I heard.';

  @override
  void initState() {
    super.initState();
    _transcript = widget.initialTranscript;
    _transcriptController.text = _transcript;
    if (_transcript.isNotEmpty) _status = 'Review what I heard.';
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final command = VoiceCommand.fromTranscript(_transcript, widget.storeNames);
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
                onChanged: (value) => setState(() => _transcript = value),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  helperText: 'Edit the words before continuing if needed.',
                ),
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

class _CommandReview extends StatelessWidget {
  const _CommandReview({required this.command});

  final VoiceCommand command;

  @override
  Widget build(BuildContext context) {
    switch (command) {
      case AddGroceryVoiceCommand(:final storeName, :final item):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          child: Text('Review $item for $storeName'),
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
      case AddStoreVoiceCommand(:final name):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: Text('Review store $name'),
        );
      case OpenGroceryVoiceCommand(:final storeName):
        return FilledButton(
          onPressed: () => Navigator.pop(context, command),
          child: Text(
            storeName == null ? 'Open grocery lists' : 'Open $storeName list',
          ),
        );
      case UnrecognizedVoiceCommand():
        return const Text(
          'Try “Add contact Manohar, phone number 9876543210.”',
        );
    }
  }
}
