import 'package:flutter/material.dart';

class AppDialogActions extends StatelessWidget {
  const AppDialogActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: children[i],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
