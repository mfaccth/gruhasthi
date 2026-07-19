import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/household_repository.dart';
import '../../data/secure_payment_repository.dart';
import '../../domain/household_models.dart';
import '../contacts/contacts_screen.dart';
import '../grocery/grocery_lists_screen.dart';
import '../payments/payment_recipients_screen.dart';
import '../settings/settings_screen.dart';
import '../stores/stores_screen.dart';
import '../voice/voice_command_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.paymentRepository,
  });

  final HouseholdRepository repository;
  final SecurePaymentRepository paymentRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HouseholdData> _data;
  final SpeechToText _holdToTalkSpeech = SpeechToText();
  bool _holdingMicrophone = false;
  bool _startingHoldToTalk = false;
  bool _speechListening = false;
  bool _restartingHoldToTalk = false;
  bool _askedForName = false;
  String _heldTranscript = '';
  String _completedTranscript = '';
  String _lastFinalSegment = '';

  @override
  void initState() {
    super.initState();
    _data = widget.repository.load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askForName());
  }

  @override
  void dispose() {
    _holdToTalkSpeech.stop();
    super.dispose();
  }

  Future<void> _openGroceryLists() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GroceryListsScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openStores() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StoresScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openContacts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactsScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openPayments() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentRecipientsScreen(
          householdRepository: widget.repository,
          paymentRepository: widget.paymentRepository,
        ),
      ),
    );
  }

  Future<void> _askForName() async {
    if (_askedForName) return;
    _askedForName = true;
    final data = await widget.repository.load();
    if (!mounted || data.userName.trim().isNotEmpty) return;
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UserNameDialog(isFirstRun: true),
    );
    if (name == null || !mounted) return;
    await widget.repository.save(data.copyWith(userName: name));
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openVoice({String initialTranscript = ''}) async {
    final data = await widget.repository.load();
    if (!mounted) return;
    final command = await showModalBottomSheet<VoiceCommand>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: VoiceCommandSheet(
          storeNames: data.stores
              .map((store) => store.name)
              .toList(growable: false),
          initialTranscript: initialTranscript,
        ),
      ),
    );
    if (!mounted || command == null) return;
    switch (command) {
      case OpenGroceryVoiceCommand(storeName: null):
        await _openGroceryLists();
      case OpenGroceryVoiceCommand(:final storeName):
        final store = _findStore(data, storeName!);
        if (store != null) await _openGroceryEditor(store);
      case AddGroceryVoiceCommand(
        :final storeName,
        :final item,
        :final quantity,
        :final unit,
      ):
        final store = _findStore(data, storeName);
        if (store != null) {
          await _openGroceryEditor(
            store,
            initialItem: item,
            initialQuantity: quantity,
            initialUnit: unit,
          );
        }
      case AddContactVoiceCommand(:final name, :final phoneNumber):
        await _openContactsForVoice(name, phoneNumber);
      case OpenStoresVoiceCommand():
        await _openStores();
      case AddStoreVoiceCommand(:final name, :final whatsAppNumber):
        await _openStoresForVoice(name, whatsAppNumber);
      case UnrecognizedVoiceCommand():
        break;
    }
  }

  Future<void> _startHoldToTalk() async {
    if (_holdingMicrophone || _startingHoldToTalk) return;
    setState(() {
      _holdingMicrophone = true;
      _startingHoldToTalk = true;
      _speechListening = false;
      _heldTranscript = '';
      _completedTranscript = '';
      _lastFinalSegment = '';
    });

    final available = await _holdToTalkSpeech.initialize(
      onStatus: _onHoldToTalkStatus,
      onError: (_) {
        if (mounted) {
          setState(() {
            _holdingMicrophone = false;
            _speechListening = false;
          });
        }
      },
    );
    if (!mounted || !_holdingMicrophone || !available) {
      if (mounted) setState(() => _startingHoldToTalk = false);
      return;
    }
    setState(() => _startingHoldToTalk = false);
    await _listenWhileHeld();
  }

  void _onHoldToTalkStatus(String status) {
    final listening = status == 'listening';
    if (mounted) setState(() => _speechListening = listening);
    if (!listening && _holdingMicrophone && !_startingHoldToTalk) {
      _restartHoldToTalk();
    }
  }

  void _restartHoldToTalk() {
    if (_restartingHoldToTalk) return;
    _restartingHoldToTalk = true;
    Future<void>.delayed(const Duration(milliseconds: 120), () async {
      _restartingHoldToTalk = false;
      await _listenWhileHeld();
    });
  }

  Future<void> _listenWhileHeld() async {
    if (!_holdingMicrophone || _speechListening) return;
    setState(() => _speechListening = true);
    await _holdToTalkSpeech.listen(
      onResult: (result) {
        final segment = result.recognizedWords.trim();
        if (!mounted || segment.isEmpty) return;
        setState(() {
          if (result.finalResult) {
            if (segment != _lastFinalSegment) {
              _completedTranscript = _joinTranscript(
                _completedTranscript,
                segment,
              );
              _lastFinalSegment = segment;
            }
            _heldTranscript = _completedTranscript;
          } else {
            _heldTranscript = _joinTranscript(_completedTranscript, segment);
          }
        });
      },
      listenOptions: SpeechListenOptions(
        localeId: 'en_IN',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  String _joinTranscript(String first, String second) {
    if (first.isEmpty) return second;
    if (second.startsWith(first)) return second;
    return '$first $second';
  }

  Future<void> _stopHoldToTalk() async {
    if (!_holdingMicrophone && !_startingHoldToTalk) return;
    setState(() {
      _holdingMicrophone = false;
      _speechListening = false;
    });
    await _holdToTalkSpeech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final transcript = _heldTranscript.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No words heard. Hold the microphone while speaking.'),
        ),
      );
      return;
    }
    await _openVoice(initialTranscript: transcript);
  }

  Store? _findStore(HouseholdData data, String storeName) {
    for (final store in data.stores) {
      if (store.name.toLowerCase() == storeName.toLowerCase()) return store;
    }
    return null;
  }

  Future<void> _openContactsForVoice(String name, String phoneNumber) async {
    // Let the voice bottom sheet finish its dismissal before pushing the
    // Contacts route. This is important on Android, where an immediate push
    // can be lost during the bottom-sheet transition.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactsScreen(
          repository: widget.repository,
          initialName: name,
          initialPhone: phoneNumber,
        ),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openStoresForVoice(String name, String whatsAppNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StoresScreen(
          repository: widget.repository,
          initialName: name,
          initialWhatsApp: whatsAppNumber,
        ),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  Future<void> _openGroceryEditor(
    Store store, {
    String initialItem = '',
    String initialQuantity = '',
    GroceryQuantityUnit initialUnit = GroceryQuantityUnit.count,
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
        ),
      ),
    );
    if (mounted) setState(() => _data = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<HouseholdData>(
                future: _data,
                builder: (context, snapshot) => _Header(
                  locality:
                      snapshot.data?.locality ?? 'Kundalahalli, Bengaluru',
                  onOpenGroceryLists: _openGroceryLists,
                  onOpenContacts: _openContacts,
                  onOpenPayments: _openPayments,
                  onOpenStores: _openStores,
                  onOpenSettings: _openSettings,
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<HouseholdData>(
                future: _data,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _VoiceHome(
                          greeting: greetingForHour(
                            DateTime.now().hour,
                            snapshot.data!.userName,
                          ),
                          onOpenGroceryLists: _openGroceryLists,
                          onOpenStores: _openStores,
                          onOpenContacts: _openContacts,
                          onOpenPayments: _openPayments,
                          onPressMicrophone: _startHoldToTalk,
                          onReleaseMicrophone: _stopHoldToTalk,
                          isListening: _holdingMicrophone,
                          liveTranscript: _heldTranscript,
                        ),
                      ),
                    ),
                  );
                },
              ),
              FutureBuilder<HouseholdData>(
                future: _data,
                builder: (context, snapshot) => _LaunchStoresNotice(
                  stores: snapshot.data?.stores ?? const [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.locality,
    required this.onOpenGroceryLists,
    required this.onOpenContacts,
    required this.onOpenPayments,
    required this.onOpenStores,
    required this.onOpenSettings,
  });

  final String locality;
  final VoidCallback onOpenGroceryLists;
  final VoidCallback onOpenContacts;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenStores;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locality,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF796C70),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<_HomeMenuDestination>(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu_rounded, color: Color(0xFFB64E70)),
          color: const Color(0xFFFFF4C8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          offset: const Offset(0, 46),
          onSelected: (destination) {
            switch (destination) {
              case _HomeMenuDestination.groceryLists:
                onOpenGroceryLists();
              case _HomeMenuDestination.contacts:
                onOpenContacts();
              case _HomeMenuDestination.pay:
                onOpenPayments();
              case _HomeMenuDestination.stores:
                onOpenStores();
              case _HomeMenuDestination.settings:
                onOpenSettings();
            }
          },
          itemBuilder: (context) => [
            _HomeMenuItem(
              destination: _HomeMenuDestination.groceryLists,
              icon: Icons.shopping_basket_outlined,
              label: 'Grocery lists',
            ),
            _HomeMenuItem(
              destination: _HomeMenuDestination.contacts,
              icon: Icons.contacts_outlined,
              label: 'Contacts',
            ),
            _HomeMenuItem(
              destination: _HomeMenuDestination.pay,
              icon: Icons.currency_rupee,
              label: 'Pay',
            ),
            _HomeMenuItem(
              destination: _HomeMenuDestination.stores,
              icon: Icons.storefront_outlined,
              label: 'Stores',
            ),
            _HomeMenuItem(
              destination: _HomeMenuDestination.settings,
              icon: Icons.settings_outlined,
              label: 'Settings',
            ),
          ],
        ),
      ],
    );
  }
}

enum _HomeMenuDestination { groceryLists, contacts, pay, stores, settings }

class _HomeMenuItem extends PopupMenuItem<_HomeMenuDestination> {
  _HomeMenuItem({
    required _HomeMenuDestination destination,
    required IconData icon,
    required String label,
  }) : super(
         value: destination,
         height: 52,
         child: _HomeMenuRow(icon: icon, label: label),
       );
}

class _HomeMenuRow extends StatelessWidget {
  const _HomeMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8F3555)),
          const SizedBox(width: 14),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right, color: Color(0xFF8F3555)),
        ],
      ),
    );
  }
}

String greetingForHour(int hour, String userName) {
  final greeting = switch (hour) {
    >= 5 && < 12 => 'Good morning',
    >= 12 && < 17 => 'Good afternoon',
    _ => 'Good evening',
  };
  return userName.trim().isEmpty ? greeting : '$greeting, ${userName.trim()}';
}

class _VoiceHome extends StatelessWidget {
  const _VoiceHome({
    required this.greeting,
    required this.onOpenGroceryLists,
    required this.onOpenStores,
    required this.onOpenContacts,
    required this.onOpenPayments,
    required this.onPressMicrophone,
    required this.onReleaseMicrophone,
    required this.isListening,
    required this.liveTranscript,
  });

  final String greeting;
  final VoidCallback onOpenGroceryLists;
  final VoidCallback onOpenStores;
  final VoidCallback onOpenContacts;
  final VoidCallback onOpenPayments;
  final VoidCallback onPressMicrophone;
  final VoidCallback onReleaseMicrophone;
  final bool isListening;
  final String liveTranscript;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centre = constraints.maxWidth / 2;
        final microphoneTop = (constraints.maxHeight - 120) / 2;
        return SizedBox(
          height: constraints.maxHeight,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Positioned(
                top: 36,
                left: 0,
                right: 0,
                child: Text(
                  'What can I do for you?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (isListening)
                Positioned(
                  top: 68,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 72,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5EA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      liveTranscript.isEmpty
                          ? 'Listening…'
                          : liveTranscriptForDisplay(liveTranscript),
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              Positioned(
                top: microphoneTop,
                left: 0,
                right: 0,
                child: Center(
                  child: _VoiceTarget(
                    onPressStart: onPressMicrophone,
                    onPressEnd: onReleaseMicrophone,
                    isListening: isListening,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: centre - 76,
                child: _RadialAction(
                  label: 'Contacts',
                  icon: Icons.contacts_outlined,
                  backgroundColor: const Color(0xFFE5F3EE),
                  onPressed: onOpenContacts,
                ),
              ),
              Positioned(
                bottom: 0,
                left: centre + 8,
                child: _RadialAction(
                  label: 'Stores',
                  icon: Icons.storefront_outlined,
                  backgroundColor: const Color(0xFFEEE7F7),
                  onPressed: onOpenStores,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: _RadialAction(
                  label: 'Grocery lists',
                  icon: Icons.shopping_basket_outlined,
                  backgroundColor: const Color(0xFFFFF1C9),
                  onPressed: onOpenGroceryLists,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _RadialAction(
                  label: 'Pay',
                  icon: Icons.currency_rupee,
                  backgroundColor: const Color(0xFFF9E2E7),
                  onPressed: onOpenPayments,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String liveTranscriptForDisplay(String transcript) {
  const charactersPerLine = 22;
  final words = transcript.trim().split(RegExp(r'\s+'));
  final lines = <String>[];
  var line = '';
  for (final word in words) {
    final next = line.isEmpty ? word : '$line $word';
    if (line.isNotEmpty && next.length > charactersPerLine) {
      lines.add(line);
      line = word;
    } else {
      line = next;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.join('\n');
}

class _RadialAction extends StatelessWidget {
  const _RadialAction({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 68,
        height: 68,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: const Color(0xFF43383B),
            padding: const EdgeInsets.all(5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceTarget extends StatelessWidget {
  const _VoiceTarget({
    required this.onPressStart,
    required this.onPressEnd,
    required this.isListening,
  });

  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Press and hold to speak',
          child: Semantics(
            button: true,
            label: 'Press and hold to speak',
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => onPressStart(),
              onPointerUp: (_) => onPressEnd(),
              onPointerCancel: (_) => onPressEnd(),
              child: Ink(
                width: 120,
                height: 120,
                decoration: ShapeDecoration(
                  color: isListening
                      ? const Color(0xFFF1B4C1)
                      : const Color(0xFFF7CBD2),
                  shape: const CircleBorder(),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Color(0xFFF7CBD2),
                      shape: CircleBorder(),
                    ),
                    child: Align(
                      alignment: Alignment(0, 0.18),
                      child: Icon(
                        Icons.mic_none_rounded,
                        size: 44,
                        color: Color(0xFFFFF4C8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isListening
              ? 'Listening… release to stop'
              : 'Press and hold to speak',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Try “Add milk to Village list”',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF796C70)),
        ),
      ],
    );
  }
}

class _LaunchStoresNotice extends StatelessWidget {
  const _LaunchStoresNotice({required this.stores});

  final List<Store> stores;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pilot stores: ${stores.map((store) => store.name).join(' and ')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
