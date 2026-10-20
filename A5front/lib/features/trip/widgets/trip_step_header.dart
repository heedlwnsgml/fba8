import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/trip_draft.dart';

class TripStepHeader extends StatelessWidget {
  final int currentStep;
  final int totalStep;
  final String title;
  final String backRoute;

  const TripStepHeader({
    super.key,
    required this.currentStep,
    this.totalStep = 6,
    this.title = '일정 생성',
    this.backRoute = AppRoutes.home,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => context.go(backRoute),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.home_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),

          _DefaultsPin(step: currentStep),
          Text(
            '$currentStep / $totalStep',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultsPin extends StatefulWidget {
  const _DefaultsPin({required this.step});
  final int step;
  @override
  State<_DefaultsPin> createState() => _DefaultsPinState();
}

class _DefaultsPinState extends State<_DefaultsPin> {
  bool busy = false;
  Timer? noticeTimer;
  ScaffoldMessengerState? noticeMessenger;
  @override
  void dispose() {
    noticeTimer?.cancel();
    final messenger = noticeMessenger;
    if (messenger != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) messenger.hideCurrentMaterialBanner();
      });
    }
    super.dispose();
  }

  Future<void> update(bool clear) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (clear)
        await TripDraft.instance.clearDefaults(widget.step);
      else
        await TripDraft.instance.saveDefaults(widget.step);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        noticeMessenger = messenger;
        noticeTimer?.cancel();
        messenger.hideCurrentMaterialBanner();
        messenger.showMaterialBanner(
          MaterialBanner(
            actions: [
              TextButton(
                onPressed: () => messenger.hideCurrentMaterialBanner(),
                child: const Text('닫기'),
              ),
            ],
            content: Text(
              clear
                  ? '이 화면의 기본값을 해제했습니다.'
                  : '현재 입력값을 기본값으로 고정했습니다. 다시 누르면 해제됩니다.',
            ),
          ),
        );
        noticeTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) messenger.hideCurrentMaterialBanner();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '눌러 기본값 고정 · 다시 눌러 해제',
    triggerMode: TooltipTriggerMode.manual,
    child: InkResponse(
      onTap: busy
          ? null
          : () => update(TripDraft.instance.hasDefaults(widget.step)),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          TripDraft.instance.hasDefaults(widget.step)
              ? Icons.push_pin
              : Icons.push_pin_outlined,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}
