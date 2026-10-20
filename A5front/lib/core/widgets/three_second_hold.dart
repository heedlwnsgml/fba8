import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ThreeSecondHold extends StatelessWidget {
  const ThreeSecondHold({super.key, required this.child, this.onHeld});
  final Widget child;
  final VoidCallback? onHeld;
  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      if (onHeld != null)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(seconds: 3),
                debugOwner: this,
              ),
              (gesture) {
                gesture.onLongPress = onHeld;
              },
            ),
    },
    child: child,
  );
}
