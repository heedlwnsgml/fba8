import 'package:flutter/material.dart';
import '../../../core/widgets/app_dialog_actions.dart';

class ReplacementPreferencesDialog extends StatefulWidget {
  const ReplacementPreferencesDialog({super.key, this.companion = '혼자'});
  final String companion;
  @override
  State<ReplacementPreferencesDialog> createState() =>
      _ReplacementPreferencesDialogState();
}

class _ReplacementPreferencesDialogState
    extends State<ReplacementPreferencesDialog> {
  static const themes = [
    '기존 취향 유지',
    '맛집',
    '쇼핑',
    '관광',
    '힐링',
    '사진',
    '서브컬쳐',
    '문화',
    '자연',
    '야경',
    '온천',
    '액티비티',
    '카페',
  ];
  static const companions = ['혼자', '친구', '연인', '부모님', '어린이', '배우자', '가족'];
  String theme = themes.first;
  late String companion;
  @override
  void initState() {
    super.initState();
    companion = widget.companion.isEmpty ? '혼자' : widget.companion;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('대체 장소 추천'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('이번 장소에 적용할 테마와 동행인을 선택하세요.'),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: theme,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '테마',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final value in themes)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (v) => setState(() => theme = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: companion,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '동행인',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final value in {...companions, companion})
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (v) => setState(() => companion = v!),
            ),
          ],
        ),
      ),
    ),
    actions: [
      AppDialogActions(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, <String, String>{
              if (theme != themes.first) 'theme': theme,
              'companion': companion,
            }),
            child: const Text('추천 장소 찾기'),
          ),
        ],
      ),
    ],
  );
}
