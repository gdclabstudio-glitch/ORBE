import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class OnboardingPage extends StatefulWidget {
  final StorageService storageService;

  const OnboardingPage({super.key, required this.storageService});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _completedKey = 'onboarding_completed';
  final PageController _pageController = PageController();
  int _page = 0;
  bool _saving = false;

  final _slides = const [
    _OnboardingSlide(
      icon: Icons.celebration,
      title: 'A rede social do seu universo',
      description:
          'Entre no ORBE, compartilhe seus melhores momentos e conecte-se com pessoas que fazem parte da sua energia.',
      colors: [Color(0xFF7C1AFF), Color(0xFFEC4899)],
    ),
    _OnboardingSlide(
      icon: Icons.photo_library_outlined,
      title: 'Memórias que ficam',
      description:
          'Publique fotos, GIFs e stickers no feed de memórias. Curta e comente em tempo real.',
      colors: [Color(0xFFFF6A00), Color(0xFFFFB000)],
    ),
    _OnboardingSlide(
      icon: Icons.chat_bubble_outline,
      title: 'Conecte-se com a galera',
      description:
          'Participe do grupo geral ou inicie conversas privadas com suas pessoas favoritas.',
      colors: [Color(0xFF00A8CC), Color(0xFF7C1AFF)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.storageService.write(key: _completedKey, value: '1');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.colors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) =>
                      _SlideContent(slide: _slides[index]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: index == _page ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: index == _page ? 1 : .45,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: slide.colors.first,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _saving
                          ? 'Preparando...'
                          : (_page == _slides.length - 1
                              ? 'Entrar no ORBE'
                              : 'Continuar'),
                    ),
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

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> colors;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
  });
}

class _SlideContent extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: Icon(slide.icon, size: 82, color: Colors.white),
          ),
          const SizedBox(height: 42),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
