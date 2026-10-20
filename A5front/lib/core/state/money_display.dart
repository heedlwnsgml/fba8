import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Original prices and pass comparisons remain in JPY; conversion is display-only.
class MoneyDisplay extends ChangeNotifier {
  String currency = 'KRW';
  double? krwPerJpy;
  static const roundingNotice =
      '원화 금액은 환산 후 100원 단위로 올림해 표시합니다. 예: 12,341원 → 12,400원';
  static int roundWon(num won) => (won / 100).ceil() * 100;
  void configure({String? currency, num? rate}) {
    final next = currency ?? this.currency;
    final nextRate = rate != null && rate.isFinite && rate > 0
        ? rate.toDouble()
        : krwPerJpy;
    if (this.currency == next && krwPerJpy == nextRate) return;
    this.currency = next;
    krwPerJpy = nextRate;
    notifyListeners();
  }

  void reset() {
    currency = 'KRW';
    krwPerJpy = null;
    notifyListeners();
  }

  String yen(num amount) {
    final number = NumberFormat('#,##0');
    if (currency == 'JPY') return '${number.format(amount)}엔';
    if (krwPerJpy == null) return '환율 확인 필요';
    return '${number.format(roundWon(amount * krwPerJpy!))}원';
  }

  String text(String value) => value.replaceAllMapped(
    RegExp(
      r'(?:[¥￥]\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)|([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*엔)',
    ),
    (m) => yen(num.parse((m[1] ?? m[2]!).replaceAll(',', ''))),
  );
}
