// TODO(voice-capture): remove legacy local merge helpers in a UI-only cleanup.
// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import '../help/app_help.dart';
import '../settings/settings_screen.dart';
import '../stores/stores_screen.dart';
import '../voice/gemma_command_interpreter.dart';
import '../voice/voice_command_sheet.dart';
import '../voice/voice_transcript_accumulator.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.repository,
    this.initialName,
    this.initialPhone,
  });

  final HouseholdRepository repository;
  final String? initialName;
  final String? initialPhone;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late Future<HouseholdData> _data;
  final GemmaCommandInterpreter _gemmaInterpreter =
      const GemmaCommandInterpreter();

  @override
  void initState() {
    super.initState();
    _data = widget.repository.load();
    if (widget.initialName != null || widget.initialPhone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future<void>.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            _edit(
              null,
              initialName: widget.initialName ?? '',
              initialPhone: widget.initialPhone ?? '',
            );
          });
        }
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _data = widget.repository.load());
  }

  Future<void> _edit(
    Contact? contact, {
    String initialName = '',
    String initialPhone = '',
  }) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (_) => ContactEditorDialog(
        contact: contact,
        initialName: initialName,
        initialPhone: initialPhone,
      ),
    );
    if (result == null) return;
    final data = await widget.repository.load();
    final updatedContacts = contact == null
        ? [...data.contacts, result]
        : data.contacts
              .map((entry) => entry.id == result.id ? result : entry)
              .toList(growable: false);
    await widget.repository.save(data.copyWith(contacts: updatedContacts));
    await _refresh();
  }

  Future<void> _delete(Contact contact) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${contact.name}?'),
        content: const Text(
          'This only removes the saved contact from Gruhasthi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final data = await widget.repository.load();
    await widget.repository.save(
      data.copyWith(
        contacts: data.contacts
            .where((entry) => entry.id != contact.id)
            .toList(),
      ),
    );
    await _refresh();
  }

  Future<void> _makeVoiceRequest() async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ContactVoiceCaptureSheet(),
    );
    if (!mounted || transcript == null || transcript.trim().isEmpty) return;
    final data = await widget.repository.load();
    if (!mounted) return;
    final ruleCommand = VoiceCommand.fromTranscript(
      transcript,
      data.stores.map((store) => store.name).toList(),
    );
    if (await _openStoreWhatsAppFromVoice(ruleCommand, data)) return;
    if (_isUsableContactCommand(ruleCommand)) {
      await _openContactEditor(ruleCommand as AddContactVoiceCommand);
      return;
    }

    final gemmaStatus = await _gemmaInterpreter.status();
    if (!mounted) return;
    if (!gemmaStatus.isReady) {
      await _showVoiceFailure(
        transcript,
        'I could not identify a contact from that request.',
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
      if (await _openStoreWhatsAppFromVoice(command, data)) return;
      if (_isUsableContactCommand(command)) {
        await _openContactEditor(command as AddContactVoiceCommand);
        return;
      }
      await _showVoiceFailure(
        transcript,
        'I could not identify a contact from that request.',
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

  bool _isUsableContactCommand(VoiceCommand command) =>
      command is AddContactVoiceCommand && command.name.trim().isNotEmpty;

  Future<bool> _openStoreWhatsAppFromVoice(
    VoiceCommand command,
    HouseholdData data,
  ) async {
    if (command is! UpdateStoreWhatsAppVoiceCommand) return false;
    Store? store;
    for (final entry in data.stores) {
      if (entry.name.toLowerCase() == command.storeName.toLowerCase()) {
        store = entry;
        break;
      }
    }
    if (store == null || !mounted) return false;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StoresScreen(
          repository: widget.repository,
          initialStoreId: store!.id,
          initialWhatsApp: command.whatsAppNumber,
        ),
      ),
    );
    await _refresh();
    return true;
  }

  Future<void> _openContactEditor(AddContactVoiceCommand command) =>
      _edit(null, initialName: command.name, initialPhone: command.phoneNumber);

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
    final action = await showDialog<_VoiceFailureAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not add contact'),
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
              onPressed: () => Navigator.pop(context, _VoiceFailureAction.help),
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Contact voice help'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8F3555),
                side: const BorderSide(color: Color(0xFF8F3555)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _VoiceFailureAction.settings),
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
            onPressed: () => Navigator.pop(context, _VoiceFailureAction.retry),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF4C8),
              foregroundColor: const Color(0xFF8F3555),
              side: const BorderSide(color: Color(0xFF8F3555), width: 1.5),
            ),
            child: const Text('Try again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _VoiceFailureAction.manual),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C2D55),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add manually'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _VoiceFailureAction.retry:
        await _makeVoiceRequest();
      case _VoiceFailureAction.manual:
        await _edit(null);
      case _VoiceFailureAction.help:
        await _openContactVoiceHelp();
      case _VoiceFailureAction.settings:
        await _openSettings();
      case null:
        break;
    }
  }

  Future<void> _openContactVoiceHelp() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        const AppHelpSheet(initialVoiceCategory: VoiceHelpCategory.contacts),
  );

  Future<void> _openSettings() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SettingsScreen(repository: widget.repository),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(right: 8),
                      foregroundColor: const Color(0xFF796C70),
                    ),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Back'),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    tooltip: 'Add contact by voice',
                    onPressed: _makeVoiceRequest,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2B8C5),
                      foregroundColor: const Color(0xFF703146),
                    ),
                    icon: const Icon(Icons.mic_none_outlined),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _edit(null),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB64E70),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add contact'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contacts',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: FutureBuilder<HouseholdData>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final contacts = snapshot.data!.contacts;
                    if (contacts.isEmpty) {
                      return const Center(
                        child: Text(
                          'Add a contact for future payments or messages.',
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                contact.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                            title: Text(contact.name),
                            subtitle: Text(
                              contact.phoneNumber.isEmpty
                                  ? 'No phone number added'
                                  : contact.phoneNumber,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _edit(contact);
                                if (value == 'remove') _delete(contact);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            ),
                            onTap: () => _edit(contact),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _VoiceFailureAction { retry, manual, help, settings }

class _ContactVoiceCaptureSheet extends StatefulWidget {
  const _ContactVoiceCaptureSheet();

  @override
  State<_ContactVoiceCaptureSheet> createState() =>
      _ContactVoiceCaptureSheetState();
}

class _ContactVoiceCaptureSheetState extends State<_ContactVoiceCaptureSheet> {
  final SpeechToText _speech = SpeechToText();
  final VoiceTranscriptAccumulator _voiceTranscript =
      VoiceTranscriptAccumulator();
  final ScrollController _transcriptScrollController = ScrollController();
  String _transcript = '';
  String _completedTranscript = '';
  String _lastFinalSegment = '';
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
      _completedTranscript = '';
      _lastFinalSegment = '';
      _voiceTranscript.reset();
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

  /// Android speech recognition can deliver a final result for only the last
  /// phrase after a pause. Keep the earlier partial result instead of letting
  /// that last phrase replace the beginning of the request.
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
      _voiceTranscript.commitPartial();
      _transcript = _voiceTranscript.transcript;
    });
    await _speech.stop();
    // Give the recognizer enough time to deliver its trailing final fragment.
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
              'Add a contact by voice',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _holding
                  ? 'Listening… release when you are done.'
                  : 'Press and hold to speak.',
            ),
            const SizedBox(height: 18),
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

class ContactEditorDialog extends StatefulWidget {
  const ContactEditorDialog({
    super.key,
    this.contact,
    this.initialName = '',
    this.initialPhone = '',
  });

  final Contact? contact;
  final String initialName;
  final String initialPhone;

  @override
  State<ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<ContactEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _whatsApp;
  bool _nameFocused = false;
  bool _phoneFocused = false;
  bool _whatsAppFocused = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.contact?.name ?? widget.initialName,
    );
    _phone = TextEditingController(
      text: widget.contact?.phoneNumber ?? widget.initialPhone,
    );
    _whatsApp = TextEditingController(
      text: widget.contact?.whatsAppNumber ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _whatsApp.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, bool focused) {
    return InputDecoration(
      labelText: label,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      labelStyle: focused ? const TextStyle(color: Color(0xFFE2A900)) : null,
      floatingLabelStyle: focused
          ? const TextStyle(color: Color(0xFFE2A900))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? 'Add contact' : 'Edit contact'),
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
                textCapitalization: TextCapitalization.words,
                cursorColor: const Color(0xFFE2A900),
                decoration: _fieldDecoration('Name', _nameFocused),
              ),
            ),
            Focus(
              onFocusChange: (focused) {
                setState(() => _phoneFocused = focused);
              },
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                cursorColor: const Color(0xFFE2A900),
                decoration: _fieldDecoration('Phone number', _phoneFocused),
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
                  'WhatsApp number (optional)',
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
              Contact(
                id:
                    widget.contact?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
                phoneNumber: _phone.text.trim(),
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
