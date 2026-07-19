import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import '../voice/gemma_command_interpreter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final HouseholdRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<HouseholdData> _data;
  final GemmaCommandInterpreter _gemmaInterpreter =
      const GemmaCommandInterpreter();
  late Future<GemmaModelStatus> _gemmaStatus;
  bool _installingGemma = false;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.load();
    _gemmaStatus = _gemmaInterpreter.status();
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

  Future<void> _showGemmaSetup(GemmaModelStatus status) async {
    final action = await showDialog<GemmaSetupAction>(
      context: context,
      builder: (_) => GemmaSetupDialog(status: status),
    );
    if (action != GemmaSetupAction.chooseFile || !mounted) return;

    setState(() => _installingGemma = true);
    try {
      final installed = await _gemmaInterpreter.pickAndInstallModel();
      if (!mounted) return;
      setState(() => _gemmaStatus = Future.value(installed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemma is installed and ready to use.')),
      );
    } on PlatformException catch (exception) {
      if (!mounted || exception.code == 'MODEL_PICK_CANCELLED') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exception.message ?? 'Gemma could not be installed.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _installingGemma = false);
    }
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
              const SizedBox(height: 10),
              FutureBuilder<GemmaModelStatus>(
                future: _gemmaStatus,
                builder: (context, gemmaSnapshot) {
                  final gemma =
                      gemmaSnapshot.data ?? GemmaModelStatus.unavailable;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.memory_outlined),
                      ),
                      title: const Text('On-device Gemma (pilot)'),
                      subtitle: Text(
                        _installingGemma
                            ? 'Installing the selected model. This may take a few minutes.'
                            : gemma.isReady
                            ? 'Gemma 4 E2B is ready for private command interpretation.'
                            : 'Not installed. Tap to set up the optional pilot model.',
                      ),
                      trailing: Icon(
                        _installingGemma
                            ? Icons.downloading_outlined
                            : gemma.isReady
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                      ),
                      onTap: _installingGemma
                          ? null
                          : () => _showGemmaSetup(gemma),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

enum GemmaSetupAction { chooseFile }

class GemmaSetupDialog extends StatelessWidget {
  const GemmaSetupDialog({super.key, required this.status});

  final GemmaModelStatus status;

  static final _modelPage = Uri.parse(
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm',
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('On-device Gemma pilot'),
      content: SingleChildScrollView(
        child: Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text:
                    'Gemma interprets a voice transcript entirely on this phone. It is optional and does not replace the review step.\n\n',
              ),
              const TextSpan(
                text:
                    '1. Download the LiteRT-LM Gemma 4 E2B model (about 2.6 GB) from the approved model page.\n2. Return here and choose ',
              ),
              TextSpan(
                text: status.isReady
                    ? 'Replace model'
                    : 'Choose downloaded file',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text:
                    '. Gruhasthi will validate the file and copy it to the correct private location automatically.\n\n'
                    'Use Wi-Fi and keep about 4 GB of free device storage. The file must be named gemma-4-E2B-it.litertlm.',
              ),
            ],
          ),
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
        TextButton(
          onPressed: () =>
              launchUrl(_modelPage, mode: LaunchMode.externalApplication),
          child: const Text('Download model'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, GemmaSetupAction.chooseFile),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: Text(
            status.isReady ? 'Replace model' : 'Choose downloaded file',
          ),
        ),
      ],
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
