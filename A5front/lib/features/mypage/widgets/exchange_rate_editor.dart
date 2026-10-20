import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/planner_api.dart';

class ExchangeRateEditor extends StatefulWidget {
  const ExchangeRateEditor({super.key, required this.api});
  final PlannerApi api;
  @override
  State<ExchangeRateEditor> createState() => _ExchangeRateEditorState();
}

class _ExchangeRateEditorState extends State<ExchangeRateEditor> {
  final amount = TextEditingController();
  final source = TextEditingController();
  DateTime date = DateTime.now();
  bool busy = true;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rate = await widget.api.getExchangeRate();
      if (!mounted) return;
      amount.text = '${rate['krwPerJpy']}';
      source.text = '${rate['sourceUrl']}';
      date = DateTime.parse('${rate['rateDate']}');
    } catch (e) {
      message = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    amount.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final value = double.tryParse(amount.text.trim());
    if (value == null ||
        value <= 0 ||
        value > 10000 ||
        !(Uri.tryParse(source.text.trim())?.hasAuthority ?? false)) {
      setState(() => message = '1엔당 원화 금액과 출처 주소를 확인하세요.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final now=DateTime.now().toUtc().add(const Duration(hours:9));
      date=DateTime(now.year,now.month,now.day);
      await widget.api.saveExchangeRate({
        'krwPerJpy': value,
        'rateDate': DateFormat('yyyy-MM-dd').format(date),
        'sourceUrl': source.text.trim(),
      });
      if (mounted) setState(() => message = '환율을 저장했습니다.');
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '관리자 · 환율 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('전체 금액 표시에 사용하는 기준 환율입니다. 100엔 금액이 아닌 1엔당 원화 금액을 입력하세요.'),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '1엔당 원화',
              suffixText: '원',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: source,
            enabled: !busy,
            decoration: const InputDecoration(labelText: '환율 출처 주소'),
          ),
          TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null && mounted)
                      setState(() => date = selected);
                  },
            icon: const Icon(Icons.calendar_month),
            label: Text('기준일 ${DateFormat('yyyy.MM.dd').format(date)}'),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(message!),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? '확인 중…' : '환율 DB에 저장'),
          ),
        ],
      ),
    ),
  );
}
