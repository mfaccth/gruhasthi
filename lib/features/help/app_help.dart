import 'package:flutter/material.dart';

enum VoiceHelpCategory { contacts, groceryLists, stores, navigation }

class AppHelpSheet extends StatelessWidget {
  const AppHelpSheet({super.key, this.initialVoiceCategory});

  final VoiceHelpCategory? initialVoiceCategory;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & app tour',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('A quick guide to getting things done with Gruhasthi.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB64E70),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Take the app tour'),
            ),
            const SizedBox(height: 16),
            Text(
              'Voice commands',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text('Press and hold the microphone, then try a phrase below.'),
            const SizedBox(height: 10),
            _VoiceCommandCategory(
              category: VoiceHelpCategory.contacts,
              selected: initialVoiceCategory == VoiceHelpCategory.contacts,
              icon: Icons.contacts_outlined,
              title: 'Contacts',
              phrases: const [
                '“Add contact Vasu, phone number 9845051410.”',
                '“Show me contacts.”',
              ],
            ),
            _VoiceCommandCategory(
              category: VoiceHelpCategory.groceryLists,
              selected:
                  initialVoiceCategory == VoiceHelpCategory.groceryLists,
              icon: Icons.shopping_basket_outlined,
              title: 'Grocery lists',
              phrases: const [
                '“Add 1 kg rice to Village.”',
                '“Add half litre milk to Big Basket.”',
                '“Open Village list.”',
              ],
            ),
            _VoiceCommandCategory(
              category: VoiceHelpCategory.stores,
              selected: initialVoiceCategory == VoiceHelpCategory.stores,
              icon: Icons.storefront_outlined,
              title: 'Stores',
              phrases: const [
                '“Add store Star Bazaar.”',
                '“Show me stores.”',
              ],
            ),
            _VoiceCommandCategory(
              category: VoiceHelpCategory.navigation,
              selected: initialVoiceCategory == VoiceHelpCategory.navigation,
              icon: Icons.navigation_outlined,
              title: 'Navigation',
              phrases: const [
                '“Go to contacts list.”',
                '“Show grocery lists.”',
              ],
            ),
            const _HelpExample(
              icon: Icons.shopping_basket_outlined,
              title: 'Grocery lists',
              detail:
                  'Create a separate list for each store, review it, then send it on WhatsApp.',
            ),
            const _HelpExample(
              icon: Icons.currency_rupee,
              title: 'Payments',
              detail:
                  'Gruhasthi opens the payment app; you review and confirm the payment there.',
            ),
            const _HelpExample(
              icon: Icons.memory_outlined,
              title: 'On-device Gemma',
              detail:
                  'If the built-in voice parser is unsure, Gemma can understand requests privately on your phone.',
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceCommandCategory extends StatelessWidget {
  const _VoiceCommandCategory({
    required this.category,
    required this.selected,
    required this.icon,
    required this.title,
    required this.phrases,
  });

  final VoiceHelpCategory category;
  final bool selected;
  final IconData icon;
  final String title;
  final List<String> phrases;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFB64E70)
        : const Color(0xFFE8D7DA);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? const Color(0xFFFFE4EA) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFF1C9),
              child: Icon(icon, color: const Color(0xFF703146)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final phrase in phrases)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('• $phrase'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpExample extends StatelessWidget {
  const _HelpExample({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFF1C9),
        child: Icon(icon, color: const Color(0xFF703146)),
      ),
      title: Text(title),
      subtitle: Text(detail),
    );
  }
}

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _controller = PageController();
  var _page = 0;

  static const _pages = [
    _TourPage(
      icon: Icons.home_outlined,
      title: 'Welcome to Gruhasthi',
      message: 'A simple household helper for your everyday routines.',
    ),
    _TourPage(
      icon: Icons.mic_none_rounded,
      title: 'Speak naturally',
      message:
          'Press and hold the microphone, say what you need, then release to review.',
    ),
    _TourPage(
      icon: Icons.shopping_basket_outlined,
      title: 'Manage grocery lists',
      message:
          'Make a list for each store and send a reviewed order on WhatsApp.',
    ),
    _TourPage(
      icon: Icons.contacts_outlined,
      title: 'Contacts and payments',
      message:
          'Save contacts, prepare payments, and complete the confirmation safely in your payment app.',
    ),
    _TourPage(
      icon: Icons.memory_outlined,
      title: 'Private on-device help',
      message:
          'When needed, Gemma can understand requests privately on your device. You always review before saving.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final lastPage = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8F3555),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) =>
                      _TourPageView(page: _pages[index]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: index == _page ? 24 : 8,
                    decoration: BoxDecoration(
                      color: index == _page
                          ? const Color(0xFFB64E70)
                          : const Color(0xFFF2B8C5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8F3555),
                        backgroundColor: const Color(0xFFFFF4C8),
                        side: const BorderSide(
                          color: Color(0xFF8F3555),
                          width: 1.5,
                        ),
                      ),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  FilledButton(
                    onPressed: lastPage
                        ? _finish
                        : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB64E70),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(lastPage ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourPage {
  const _TourPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

class _TourPageView extends StatelessWidget {
  const _TourPageView({required this.page});

  final _TourPage page;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF2B8C5),
              ),
              child: Icon(page.icon, size: 74, color: const Color(0xFF8F3555)),
            ),
            const SizedBox(height: 42),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              page.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF796C70),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
