import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/household_models.dart';
import 'whatsapp_message.dart';

class WhatsAppPreviewScreen extends StatefulWidget {
  const WhatsAppPreviewScreen({
    super.key,
    required this.store,
    required this.items,
  });

  final Store store;
  final List<GroceryItem> items;

  @override
  State<WhatsAppPreviewScreen> createState() => _WhatsAppPreviewScreenState();
}

class _WhatsAppPreviewScreenState extends State<WhatsAppPreviewScreen> {
  late final TextEditingController _message;
  bool _launching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message = TextEditingController(
      text: groceryMessage(widget.store, widget.items),
    );
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    setState(() {
      _launching = true;
      _error = null;
    });
    final launched = await launchUrl(
      whatsAppMessageUri(widget.store.whatsAppNumber, _message.text),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    setState(() {
      _launching = false;
      if (!launched) {
        _error = 'Could not open WhatsApp. Check that it is installed.';
      }
    });
    if (launched && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 116,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    foregroundColor: const Color(0xFF796C70),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back'),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'Review WhatsApp message',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                widget.store.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.store.whatsAppNumber,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF796C70),
                ),
              ),
              const SizedBox(height: 22),
              Text('Message', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Expanded(
                child: TextField(
                  controller: _message,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    helperText: 'Edit the message if needed before continuing.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'WhatsApp opens next. You will choose the chat and tap Send in WhatsApp.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _launching ? null : _openWhatsApp,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9C2D55),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE6A6B9),
                    disabledForegroundColor: Colors.white70,
                  ),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _launching ? 'Opening WhatsApp…' : 'Continue to WhatsApp',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
