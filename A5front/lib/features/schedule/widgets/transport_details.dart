import 'package:flutter/material.dart';

/// Shared, left-aligned route sections for timeline cards and pin details.
class TransportDetails extends StatelessWidget {
  const TransportDetails({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final totals = lines
        .where((s) => s.startsWith('총 이동 시간:') || s.startsWith('교통비:'))
        .toList();
    final steps = lines
        .where(
          (s) =>
              !totals.contains(s) &&
              !s.startsWith('이동:') &&
              RegExp(r'·\s*(?:약\s*)?\d+분$').hasMatch(s),
        )
        .toList();
    final notes = lines
        .where(
          (s) =>
              !totals.contains(s) && !steps.contains(s) && !s.startsWith('이동:'),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFFB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2458A6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _ride(steps[i])),
              ],
            ),
          ),
        if (totals.isNotEmpty) ...[
          const Divider(height: 18),
          for (final line in totals)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            '참고',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                note,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _ride(String line) {
    final parts = line.split(' · ');
    if (parts.length < 2) return Text(line, textAlign: TextAlign.left);
    final duration = parts.removeLast();
    final shownDuration =
        parts.first.contains('대기') && !duration.startsWith('약 ')
        ? '약 $duration'
        : duration;
    final stations = parts
        .where((s) {
          if (!s.contains('→')) return false;
          final ends = s
              .split('→')
              .map((v) => v.replaceAll(RegExp(r'\s+'), ''))
              .toList();
          return !(RegExp(r'대기|환승').hasMatch(parts.first) &&
              ends.length == 2 &&
              ends[0] == ends[1]);
        })
        .join(' · ');
    final title = parts.where((s) => !s.contains('→')).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$title · $shownDuration',
          textAlign: TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45),
        ),
        if (stations.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            stations,
            textAlign: TextAlign.left,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ],
    );
  }
}
