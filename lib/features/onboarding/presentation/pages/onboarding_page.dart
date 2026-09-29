import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/onboarding_controller.dart';
import '../widgets/dots_indicator.dart';
import '../widgets/onboarding_slide.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const Duration _autoAdvanceDuration = Duration(seconds: 5);
  static const Duration _pageTransitionDuration = Duration(milliseconds: 400);

  final PageController _pageController = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_autoAdvanceDuration, (_) => _autoAdvance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _autoAdvance() {
    final OnboardingState state = ref.read(onboardingControllerProvider);
    if (state.isLast) {
      return;
    }
    _animateTo(state.currentIndex + 1);
  }

  void _animateTo(int index) {
    _pageController.animateToPage(
      index,
      duration: _pageTransitionDuration,
      curve: Curves.easeInOut,
    );
  }

  void _goNext() {
    final int index = ref.read(onboardingControllerProvider).currentIndex + 1;
    _animateTo(
      index >= OnboardingState.pageCount
          ? OnboardingState.pageCount - 1
          : index,
    );
  }

  void _goBack() {
    final int index = ref.read(onboardingControllerProvider).currentIndex - 1;
    _animateTo(index < 0 ? 0 : index);
  }

  void _skip() {
    _animateTo(OnboardingState.pageCount - 1);
  }

  void _startApp() {}

  @override
  Widget build(BuildContext context) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    const List<OnboardingSlide> slides = <OnboardingSlide>[
      OnboardingSlide(
        image: 'assets/images/onboarding/onboarding_1.png',
        title: 'Dictez vos ventes',
        subtitle:
            'Enregistrez vos ventes en parlant naturellement, même quand vos mains sont occupées.',
      ),
      OnboardingSlide(
        image: 'assets/images/onboarding/onboarding_2.png',
        title: 'Suivez votre stock',
        subtitle:
            'Contrôlez vos niveaux de stock en temps réel et repérez les produits à réapprovisionner.',
      ),
      OnboardingSlide(
        image: 'assets/images/onboarding/onboarding_3.png',
        title: 'Anticipez les ruptures',
        subtitle:
            "Recevez des alertes d'approvisionnement intelligentes pour ne jamais manquer de produits.",
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: state.isLast
                    ? const SizedBox.shrink()
                    : TextButton(onPressed: _skip, child: const Text('Passer')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: OnboardingState.pageCount,
                onPageChanged: (int index) =>
                    ref.read(onboardingControllerProvider.notifier).goTo(index),
                itemBuilder: (BuildContext context, int index) => slides[index],
              ),
            ),
            const SizedBox(height: 24),
            DotsIndicator(
              count: OnboardingState.pageCount,
              activeIndex: state.currentIndex,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: state.isFirst
                        ? const SizedBox.shrink()
                        : OutlinedButton(
                            onPressed: _goBack,
                            child: const Text('Retour'),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: state.isLast
                        ? FilledButton(
                            onPressed: _startApp,
                            child: const Text('Commencer'),
                          )
                        : FilledButton(
                            onPressed: _goNext,
                            child: const Text('Suivant'),
                          ),
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
