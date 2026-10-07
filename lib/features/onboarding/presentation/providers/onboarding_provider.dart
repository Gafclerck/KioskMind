import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  const OnboardingState({required this.currentIndex});

  static const int pageCount = 3;

  final int currentIndex;

  bool get isFirst => currentIndex == 0;

  bool get isLast => currentIndex == pageCount - 1;
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState(currentIndex: 0);

  void goTo(int index) {
    final int target = index < 0
        ? 0
        : index >= OnboardingState.pageCount
        ? OnboardingState.pageCount - 1
        : index;
    if (target == state.currentIndex) {
      return;
    }
    state = OnboardingState(currentIndex: target);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );
