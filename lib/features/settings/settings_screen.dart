import 'package:flutter/material.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final HouseholdRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<HouseholdData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.load();
  }

  Future<void> _editName(HouseholdData data) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => UserNameDialog(initialName: data.userName),
    );
    if (name == null) return;
    await _saveUpdatedData(data.copyWith(userName: name));
  }

  Future<void> _editLocality(HouseholdData data) async {
    final locality = await showDialog<String>(
      context: context,
      builder: (_) => LocalityDialog(initialLocality: data.locality),
    );
    if (locality == null) return;
    await _saveUpdatedData(data.copyWith(locality: locality));
  }

  Future<void> _saveUpdatedData(HouseholdData updatedData) async {
    // Update the Settings cards before the disk write completes, so the
    // saved value is visible as soon as the edit dialog closes.
    if (mounted) setState(() => _data = Future.value(updatedData));
    await widget.repository.save(updatedData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<HouseholdData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: const Text('Your name'),
                  subtitle: Text(
                    data.userName.isEmpty ? 'Not set' : data.userName,
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editName(data),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.location_on_outlined),
                  ),
                  title: const Text('Locality'),
                  subtitle: Text(data.locality),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editLocality(data),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class UserNameDialog extends StatefulWidget {
  const UserNameDialog({
    super.key,
    this.initialName = '',
    this.isFirstRun = false,
  });

  final String initialName;
  final bool isFirstRun;

  @override
  State<UserNameDialog> createState() => _UserNameDialogState();
}

class _UserNameDialogState extends State<UserNameDialog> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isFirstRun ? 'Welcome to Gruhasthi' : 'Your name'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        cursorColor: const Color(0xFFB64E70),
        cursorWidth: 2.5,
        decoration: const InputDecoration(
          labelText: 'Name',
          helperText: 'Used to personalize your greeting.',
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFB64E70), width: 2),
          ),
          floatingLabelStyle: TextStyle(color: Color(0xFFB64E70)),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF42363A),
            side: const BorderSide(color: Color(0xFF42363A)),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
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

class LocalityDialog extends StatefulWidget {
  const LocalityDialog({super.key, required this.initialLocality});

  final String initialLocality;

  @override
  State<LocalityDialog> createState() => _LocalityDialogState();
}

class _LocalityDialogState extends State<LocalityDialog> {
  late final TextEditingController _locality;

  @override
  void initState() {
    super.initState();
    _locality = TextEditingController(text: widget.initialLocality);
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your locality'),
      content: TextField(
        controller: _locality,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        cursorColor: const Color(0xFFB64E70),
        cursorWidth: 2.5,
        decoration: const InputDecoration(
          labelText: 'Locality and city',
          helperText: 'Used for nearby store searches.',
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFB64E70), width: 2),
          ),
          floatingLabelStyle: TextStyle(color: Color(0xFFB64E70)),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF42363A),
            side: const BorderSide(color: Color(0xFF42363A)),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final locality = _locality.text.trim();
            if (locality.isNotEmpty) Navigator.pop(context, locality);
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
