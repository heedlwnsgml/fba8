import 'app_dialog_actions.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppConfirmDialogType { normal, danger }

enum AppLeaveDialogResult { save, discard, cancel }

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = '취소',
  String confirmText = '확인',
  AppConfirmDialogType type = AppConfirmDialogType.normal,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final confirmColor = type == AppConfirmDialogType.danger
          ? AppColors.error
          : AppColors.primary;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          AppDialogActions(
            children: [
              _DialogOutlinedButton(
                text: cancelText,
                onPressed: () => Navigator.pop(context, false),
              ),
              _DialogFilledButton(
                text: confirmText,
                color: confirmColor,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<AppLeaveDialogResult> showAppLeaveDialog({
  required BuildContext context,
  required String title,
  required String message,
  String saveText = '저장',
  String discardText = '저장하지 않기',
  String cancelText = '취소',
}) async {
  final result = await showDialog<AppLeaveDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDialogActions(
                children: [
                  _DialogOutlinedButton(
                    text: discardText,
                    textColor: AppColors.error,
                    borderColor: AppColors.error,
                    onPressed: () =>
                        Navigator.pop(context, AppLeaveDialogResult.discard),
                  ),
                  _DialogFilledButton(
                    text: saveText,
                    color: AppColors.primary,
                    onPressed: () =>
                        Navigator.pop(context, AppLeaveDialogResult.save),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, AppLeaveDialogResult.cancel),
                child: Text(cancelText),
              ),
            ],
          ),
        ],
      );
    },
  );

  return result ?? AppLeaveDialogResult.cancel;
}

class _DialogFilledButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const _DialogFilledButton({
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _DialogOutlinedButton extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _DialogOutlinedButton({
    required this.text,
    required this.onPressed,
    this.textColor = AppColors.textPrimary,
    this.borderColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
