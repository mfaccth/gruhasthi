import 'package:flutter/material.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add contact',
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add contact'),
        backgroundColor: const Color(0xFFF2B8C5),
        foregroundColor: const Color(0xFF43383B),
      ),
      body: FutureBuilder<HouseholdData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final contacts = snapshot.data!.contacts;
          if (contacts.isEmpty) {
            return const Center(
              child: Text('Add a contact for future payments or messages.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name.substring(0, 1).toUpperCase()),
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
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                  onTap: () => _edit(contact),
                ),
              );
            },
          );
        },
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
