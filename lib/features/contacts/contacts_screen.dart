import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import '../voice/voice_command_sheet.dart';

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
      case AddContactVoiceCommand(:final name, :final phoneNumber):
        await _edit(null, initialName: name, initialPhone: phoneNumber);
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Try “Add contact Aarti, phone number 9876543210.”'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: const Color(0xFF796C70),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contacts',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
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

class _ContactVoiceCaptureSheet extends StatefulWidget {
  const _ContactVoiceCaptureSheet();

  @override
  State<_ContactVoiceCaptureSheet> createState() =>
      _ContactVoiceCaptureSheetState();
}

class _ContactVoiceCaptureSheetState extends State<_ContactVoiceCaptureSheet> {
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
              'Add a contact by voice',
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
