import 'app_dialog_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Gives Android system back the same destination as the page's back button.
class SystemBackPage extends StatefulWidget {
  const SystemBackPage({super.key, this.backRoute, required this.child});
  final String? backRoute;
  final Widget child;

  @override
  State<SystemBackPage> createState() => _SystemBackPageState();
}

class _SystemBackPageState extends State<SystemBackPage> {
  bool _confirming = false;

  Future<void> _back() async {
    if (_confirming) return;
    if (widget.backRoute != null) {
      context.go(widget.backRoute!);
      return;
    }
    _confirming = true;
    try {
      final exit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('앱을 종료할까요?'),
          actions: [
            AppDialogActions(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('종료'),
                ),
              ],
            ),
          ],
        ),
      );
      if (exit == true && mounted) await SystemNavigator.pop();
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return widget.child;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: widget.child,
    );
  }
}
