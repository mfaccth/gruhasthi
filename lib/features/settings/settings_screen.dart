import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/household_repository.dart';
import '../../domain/household_models.dart';
import 'device_locality_detector.dart';
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
  final DeviceLocalityDetector _localityDetector =
      const DeviceLocalityDetector();

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
      builder: (_) => LocalityDialog(
        initialLocality: data.locality,
        onDetectLocality: _localityDetector.detect,
      ),
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
    final selection = await showDialog<GemmaSetupSelection>(
      context: context,
      builder: (_) => GemmaSetupDialog(status: status),
    );
    if (selection == null || !mounted) return;

    await _downloadAndInstallGemma(selection.model);
  }

  Future<void> _downloadAndInstallGemma(GemmaModel model) async {
    setState(() => _installingGemma = true);
    try {
      await _gemmaInterpreter.startModelDownload(model);
      if (!mounted) return;
      final installed = await showDialog<GemmaModelStatus>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            GemmaDownloadDialog(interpreter: _gemmaInterpreter, model: model),
      );
      if (installed == null || !mounted) return;
      setState(() => _gemmaStatus = Future.value(installed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${installed.model.displayName} is ready.')),
      );
    } on PlatformException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exception.message ?? 'Gemma could not be downloaded.'),
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
                  subtitle: Text(
                    data.locality.isEmpty
                        ? 'Not set — used for nearby store searches'
                        : data.locality,
                  ),
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
                            ? '${gemma.model.displayName} is ready for private command interpretation.'
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

class GemmaSetupSelection {
  const GemmaSetupSelection(this.model);

  final GemmaModel model;
}

class GemmaSetupDialog extends StatefulWidget {
  const GemmaSetupDialog({super.key, required this.status});

  final GemmaModelStatus status;

  @override
  State<GemmaSetupDialog> createState() => _GemmaSetupDialogState();
}

class _GemmaSetupDialogState extends State<GemmaSetupDialog> {
  late GemmaModel _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.status.isReady
        ? widget.status.model
        : GemmaModel.e2b;
  }

  Future<void> _openModelSource() async {
    final opened = await launchUrl(
      Uri.parse(_selectedModel.modelPage),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the model download page.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReplacing = widget.status.isReady;
    return AlertDialog(
      title: const Text(
        'On-device Gemma pilot',
        maxLines: 1,
        softWrap: false,
        style: TextStyle(fontSize: 22),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gemma interprets a voice transcript privately on this phone. It remains optional and never replaces review.',
            ),
            const SizedBox(height: 14),
            RadioGroup<GemmaModel>(
              groupValue: _selectedModel,
              onChanged: (value) => setState(() => _selectedModel = value!),
              child: Column(
                children: [
                  for (final model in GemmaModel.values)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedModel = model),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<GemmaModel>(
                                  value: model,
                                  activeColor: const Color(0xFFB64E70),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  model.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: _ModelDetails(model: model),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Download & install uses Wi-Fi and continues in Android’s download manager. Gruhasthi verifies the selected model before activating it.',
            ),
            const SizedBox(height: 8),
            _ModelDetails(model: _selectedModel),
            TextButton.icon(
              onPressed: _openModelSource,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Model source and terms'),
            ),
          ],
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
          onPressed: () =>
              Navigator.pop(context, GemmaSetupSelection(_selectedModel)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB64E70),
            foregroundColor: Colors.white,
          ),
          child: Text(
            isReplacing ? 'Replace with download' : 'Download & install',
          ),
        ),
      ],
    );
  }
}

class _ModelDetails extends StatelessWidget {
  const _ModelDetails({required this.model});

  final GemmaModel model;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailBullet(text: model.description, style: style),
        _DetailBullet(text: model.downloadSize, style: style),
        _DetailBullet(text: model.storageGuidance, style: style),
        _DetailBullet(text: model.memoryGuidance, style: style),
      ],
    );
  }
}

class _DetailBullet extends StatelessWidget {
  const _DetailBullet({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: style),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class GemmaDownloadDialog extends StatefulWidget {
  const GemmaDownloadDialog({
    super.key,
    required this.interpreter,
    required this.model,
  });

  final GemmaCommandInterpreter interpreter;
  final GemmaModel model;

  @override
  State<GemmaDownloadDialog> createState() => _GemmaDownloadDialogState();
}

class _GemmaDownloadDialogState extends State<GemmaDownloadDialog> {
  Timer? _pollTimer;
  GemmaDownloadStatus? _status;
  bool _installing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_installing) return;
    try {
      final status = await widget.interpreter.modelDownloadStatus();
      if (!mounted) return;
      if (status.hasFailed || status.state == 'none') {
        setState(() {
          _status = status;
          _error = status.message.isEmpty
              ? 'The download did not complete. Check Wi-Fi and try again.'
              : status.message;
        });
        _pollTimer?.cancel();
        return;
      }
      setState(() => _status = status);
      if (status.isDownloaded) await _installDownloadedModel();
    } on PlatformException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _installDownloadedModel() async {
    if (_installing) return;
    setState(() => _installing = true);
    _pollTimer?.cancel();
    try {
      final installed = await widget.interpreter.installDownloadedModel(
        widget.model,
      );
      if (mounted) Navigator.pop(context, installed);
    } on PlatformException catch (exception) {
      if (mounted) {
        setState(() {
          _installing = false;
          _error =
              exception.message ??
              'The downloaded model could not be verified.';
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (!_installing) await widget.interpreter.cancelModelDownload();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final progress = status?.progress;
    final downloadedMb = (status?.bytesDownloaded ?? 0) / (1024 * 1024);
    final totalMb = (status?.totalBytes ?? 0) / (1024 * 1024);
    return AlertDialog(
      title: Text(
        _installing
            ? 'Verifying ${widget.model.displayName}'
            : 'Downloading ${widget.model.displayName}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _installing
                ? 'Checking the download and activating the model. This can take a few minutes.'
                : 'Downloading over Wi-Fi. You can leave Gruhasthi open while this completes.',
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: _installing ? null : progress,
            color: const Color(0xFFB64E70),
            backgroundColor: const Color(0xFFFFE1E7),
          ),
          const SizedBox(height: 10),
          Text(
            totalMb > 0
                ? '${downloadedMb.toStringAsFixed(0)} MB of ${totalMb.toStringAsFixed(0)} MB'
                : 'Preparing download…',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF9D4664))),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: _installing ? null : _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF42363A),
            side: const BorderSide(color: Color(0xFF42363A)),
          ),
          child: Text(_error == null ? 'Cancel download' : 'Close'),
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
  const LocalityDialog({
    super.key,
    required this.initialLocality,
    required this.onDetectLocality,
    this.isFirstRun = false,
  });

  final String initialLocality;
  final Future<String> Function() onDetectLocality;
  final bool isFirstRun;

  @override
  State<LocalityDialog> createState() => _LocalityDialogState();
}

class _LocalityDialogState extends State<LocalityDialog> {
  late final TextEditingController _locality;
  bool _detecting = false;
  String? _detectionError;

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

  Future<void> _useCurrentLocation() async {
    if (_detecting) return;
    setState(() {
      _detecting = true;
      _detectionError = null;
    });
    try {
      final locality = await widget.onDetectLocality();
      if (mounted) _locality.text = locality;
    } on PlatformException catch (exception) {
      if (mounted) setState(() => _detectionError = exception.message);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isFirstRun ? 'Set your locality' : 'Your locality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _locality,
            autofocus: !widget.isFirstRun,
            textCapitalization: TextCapitalization.words,
            cursorColor: const Color(0xFFB64E70),
            cursorWidth: 2.5,
            decoration: const InputDecoration(
              labelText: 'Your neighbourhood or locality',
              hintText: 'e.g. Battery Park, New York City',
              helperText: 'Include your city and country for better results.',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFB64E70), width: 2),
              ),
              floatingLabelStyle: TextStyle(color: Color(0xFFB64E70)),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _detecting ? null : _useCurrentLocation,
            icon: _detecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(
              _detecting ? 'Finding your locality…' : 'Use current location',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8F3555),
              side: const BorderSide(color: Color(0xFF8F3555)),
            ),
          ),
          if (_detectionError != null) ...[
            const SizedBox(height: 8),
            Text(
              _detectionError!,
              style: const TextStyle(color: Color(0xFF9C2D55)),
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF42363A),
            side: const BorderSide(color: Color(0xFF42363A)),
          ),
          child: Text(widget.isFirstRun ? 'Not now' : 'Cancel'),
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
