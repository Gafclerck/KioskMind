import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

enum AppToastType { success, error, info }

extension AppToastTypeStyle on AppToastType {
  IconData get icon => switch (this) {
    AppToastType.success => Icons.check_circle,
    AppToastType.error => Icons.error_outline,
    AppToastType.info => Icons.info_outline,
  };

  Color get color => switch (this) {
    AppToastType.success => AppColors.success,
    AppToastType.error => AppColors.error,
    AppToastType.info => AppColors.info,
  };
}

class ToastData {
  const ToastData({
    required this.message,
    required this.type,
    required this.id,
  });

  final String message;
  final AppToastType type;
  final int id;
}

class ToastService {
  final StreamController<ToastData> _controller =
      StreamController<ToastData>.broadcast();

  Stream<ToastData> get toasts => _controller.stream;

  int _nextId = 0;

  void show({required String message, required AppToastType type}) {
    _controller.add(ToastData(message: message, type: type, id: _nextId++));
  }
}

final toastServiceProvider = Provider<ToastService>((ref) => ToastService());

abstract final class AppToast {
  static void show(
    WidgetRef ref, {
    required String message,
    required AppToastType type,
  }) {
    ref.read(toastServiceProvider).show(message: message, type: type);
  }
}

class AppToastHost extends ConsumerStatefulWidget {
  const AppToastHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends ConsumerState<AppToastHost> {
  static const Duration _visibleDuration = Duration(milliseconds: 2800);
  static const Duration _animationDuration = Duration(milliseconds: 260);

  final List<_ActiveToast> _active = <_ActiveToast>[];
  StreamSubscription<ToastData>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(toastServiceProvider).toasts.listen(_push);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final _ActiveToast toast in _active) {
      toast.timer?.cancel();
    }
    super.dispose();
  }

  void _push(ToastData data) {
    final _ActiveToast toast = _ActiveToast(data);
    setState(() {
      _active.add(toast);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          toast.visible = true;
        });
      }
    });
    toast.timer = Timer(_visibleDuration, () => _dismiss(toast));
  }

  void _dismiss(_ActiveToast toast) {
    if (!mounted) {
      return;
    }
    setState(() {
      toast.visible = false;
    });
    toast.timer = Timer(
      _animationDuration + const Duration(milliseconds: 100),
      () {
        if (mounted) {
          setState(() {
            _active.remove(toast);
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          left: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final _ActiveToast toast in _active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedSlide(
                    offset: toast.visible ? Offset.zero : const Offset(0, 0.4),
                    duration: _animationDuration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: toast.visible ? 1 : 0,
                      duration: _animationDuration,
                      child: _ToastCard(details: toast.data),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveToast {
  _ActiveToast(this.data);

  final ToastData data;
  bool visible = false;
  Timer? timer;
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.details});

  final ToastData details;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: details.type.color,
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(details.type.icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  details.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
