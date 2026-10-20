// Layout port of NaDongHwi/TravelPlanner_Backend PdfExportService, commit 73ed603.
// Keeps Flutter's current formatted data, currencies and beneficial-pass filtering.
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _navy = PdfColor.fromInt(0xff1f3a5f),
    _soft = PdfColor.fromInt(0xffe8eef5),
    _teal = PdfColor.fromInt(0xff0f766e),
    _tealSoft = PdfColor.fromInt(0xffe6f4f2),
    _ink = PdfColor.fromInt(0xff22272e),
    _gray = PdfColor.fromInt(0xff6b7280),
    _line = PdfColor.fromInt(0xffdde2e8),
    _paper = PdfColor.fromInt(0xfff6f7f9);

String itineraryPdfDayHeading(int day, String date) =>
    '$day일차 일정${date.isNotEmpty && !RegExp(r'날짜 미정|날짜 미지정').hasMatch(date) ? ' · $date' : ''}';
List<String> _chunks(String text) {
  var remaining = text.trim();
  final parts = <String>[];
  while (remaining.runes.length > 320) {
    final prefix = String.fromCharCodes(remaining.runes.take(320));
    final sentence = prefix.lastIndexOf('. '), space = prefix.lastIndexOf(' ');
    final split = sentence > 120
        ? sentence + 1
        : (space > 120 ? space : prefix.length);
    parts.add(remaining.substring(0, split).trim());
    remaining = remaining.substring(split).trim();
  }
  if (remaining.isNotEmpty) parts.add(remaining);
  return parts;
}

pw.Text _text(
  String value, {
  double size = 9.5,
  PdfColor color = _ink,
  bool bold = false,
}) => pw.Text(
  value,
  style: pw.TextStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    lineSpacing: 2,
  ),
);
pw.Widget pdfSectionTitle(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 18, bottom: 7),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _navy)),
  ),
  child: _text(text, size: 12, color: _navy, bold: true),
);

/// Compact time column and place column follow Donghwi's daily timetable.
/// Independent rows can flow across pages even when a description is unusually long.
List<pw.Widget> itineraryPdfCard({
  required String title,
  required String time,
  required String category,
  required String information,
  required String movement,
  required String explanation,
  int? number,
  Uri? directionsUrl,
  Uri? airportAccessUrl,
  String? detailKey,
  bool expanded = false,
}) {
  final info = <String, String>{};
  String? key;
  for (final line in information.split('\n')) {
    final match = RegExp(
      r'^(체류시간|주소|전화번호|영업시간|영업일|휴무일|평균 숙박요금|1박 최저가|숙박비|식사 장소 유형|공항 내 이동):\s*(.*)$',
    ).firstMatch(line);
    if (match != null) {
      key = match[1]!;
      info[key] = match[2]!;
    } else if (key != null && line.trim().isNotEmpty) {
      info[key] = '${info[key]}\n$line';
    }
  }
  if (info['식사 장소 유형'] == '식당') info.remove('식사 장소 유형');
  final access = info.remove('공항 내 이동');
  final stay = info.remove('체류시간');
  pw.Widget row(
    String stamp,
    pw.Widget content, {
    bool first = false,
    PdfColor? background,
  }) => pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(15),
      1: const pw.FlexColumnWidth(85),
    },
    children: [
      pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 6, right: 8, bottom: 3),
            decoration: first
                ? const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: _line, width: .6),
                    ),
                  )
                : null,
            child: _text(stamp, size: 11, color: _navy, bold: true),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(10, 5, 7, 4),
            decoration: pw.BoxDecoration(
              color: background,
              border: pw.Border(
                top: pw.BorderSide(
                  color: first ? _line : PdfColors.white,
                  width: first ? 0.6 : 0,
                ),
              ),
            ),
            child: content,
          ),
        ],
      ),
    ],
  );
  final visibleInfo = info.entries
      .where(
        (entry) =>
            expanded ||
            [
              '영업시간',
              '영업일',
              '휴무일',
              '평균 숙박요금',
              '1박 최저가',
              '숙박비',
            ].contains(entry.key),
      )
      .toList();
  final visibleMovement = expanded
      ? movement
      : movement
            .split('\n')
            .where((line) => line.startsWith('이동:') || line.startsWith('교통비:'))
            .join('\n');
  final desc = explanation.replaceFirst(RegExp(r'^설명:\s*'), '').trim();
  return [
    row(
      time,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (detailKey != null)
            pw.Anchor(
              name: '${expanded ? 'details' : 'stop'}-$detailKey',
              child: _text(
                number == null ? title : '$number. $title',
                size: 11,
                bold: true,
              ),
            )
          else
            _text(
              number == null ? title : '$number. $title',
              size: 11,
              bold: true,
            ),
          pw.SizedBox(height: 2),
          _text(
            '$category${stay != null ? ' · 체류시간 $stay' : ''}',
            size: 8,
            color: _teal,
          ),
        ],
      ),
      first: true,
    ),
    for (final chunk in _chunks(desc)) row('', _text(chunk, size: 9)),
    if (visibleInfo.isNotEmpty)
      row('', _text('방문 정보', size: 8, bold: true, color: _gray)),
    for (final entry in visibleInfo)
      for (final chunk in _chunks(entry.value))
        row(
          '',
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 65,
                child: _text(entry.key, size: 8, color: _gray),
              ),
              pw.Expanded(child: _text(chunk, size: 8.5, color: _gray)),
            ],
          ),
        ),
    if (movement.trim().isNotEmpty ||
        access != null ||
        directionsUrl != null) ...[
      row(
        '',
        _text(
          movement.trim().isEmpty && access != null
              ? '공항에서 대중교통으로 이동'
              : '이 장소까지 오는 방법',
          size: 8.5,
          bold: true,
          color: _teal,
        ),
        background: _tealSoft,
      ),
      if (access != null)
        for (final chunk in _chunks(access))
          row('', _text(chunk, size: 8.5, color: _teal), background: _tealSoft),
      if (airportAccessUrl != null)
        row(
          '',
          pw.UrlLink(
            destination: airportAccessUrl.toString(),
            child: _text('공항 → 승차 지점 실제 경로 보기', size: 8.5, color: _teal),
          ),
          background: _tealSoft,
        ),
      for (final chunk in _chunks(visibleMovement))
        row('', _text(chunk, size: 8.5, color: _teal), background: _tealSoft),
      if (directionsUrl != null)
        row(
          '',
          pw.UrlLink(
            destination: directionsUrl.toString(),
            child: _text('실제 경로 보기', size: 8.5, color: _teal),
          ),
          background: _tealSoft,
        ),
    ],
    if (detailKey != null)
      row(
        '',
        pw.Link(
          destination: '${expanded ? 'stop' : 'details'}-$detailKey',
          child: _text(
            expanded ? '일정으로 돌아가기' : '방문·이동 상세 보기',
            size: 9,
            color: _teal,
          ),
        ),
      ),
    pw.SizedBox(height: 7),
  ];
}

class ItineraryPdfDay {
  ItineraryPdfDay({
    required this.number,
    required this.date,
    required this.guidance,
    required this.items,
    this.details = const [],
  });
  final int number;
  final String date;
  final Map<String, String> guidance;
  final List<pw.Widget> items;
  final List<pw.Widget> details;
}

Future<Uint8List> buildDonghwiSchedulePdf({
  required pw.Font regular,
  required pw.Font bold,
  required pw.Font japanese,
  required String title,
  required String period,
  required Map<String, String> information,
  required Map<String, String> costs,
  required List<Map<String, String>> lodgings,
  required List<String> passes,
  required List<String> notes,
  required List<ItineraryPdfDay> days,
  String comment = '',
}) async {
  final doc = pw.Document(title: '$title 일정표', creator: 'Travel Planner');
  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    fontFallback: [japanese],
  );
  final today = DateTime.now().toUtc().add(const Duration(hours: 9));
  pw.Widget footer(pw.Context c) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      _text(
        '$title · ${today.year}.${today.month.toString().padLeft(2, '0')}.${today.day.toString().padLeft(2, '0')} 만듦',
        size: 7.5,
        color: _gray,
      ),
      _text('${c.pageNumber} / ${c.pagesCount}', size: 7.5, color: _gray),
    ],
  );
  pw.MultiPage page(List<pw.Widget> content) => pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    maxPages: 100,
    margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 50),
    theme: theme,
    footer: footer,
    build: (_) => content,
  );
  final entries = information.entries
      .where((e) => e.value.trim().isNotEmpty)
      .toList();
  doc.addPage(
    page([
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(22),
        color: _navy,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _text(
              'TRAVEL PLAN',
              size: 8.5,
              color: const PdfColor.fromInt(0xffa9c1dd),
            ),
            pw.SizedBox(height: 7),
            _text(title, size: 22, bold: true, color: PdfColors.white),
            pw.SizedBox(height: 8),
            _text(period, size: 11, color: const PdfColor.fromInt(0xffdce6f1)),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(14),
          1: const pw.FlexColumnWidth(36),
          2: const pw.FlexColumnWidth(14),
          3: const pw.FlexColumnWidth(36),
        },
        children: [
          for (var i = 0; i < entries.length; i += 2)
            pw.TableRow(
              children: [
                for (var j = i; j < i + 2; j++) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    color: _paper,
                    child: _text(
                      j < entries.length ? entries[j].key : '',
                      size: 8.5,
                      color: _gray,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    child: _text(
                      j < entries.length ? entries[j].value : '',
                      size: 9,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      if (costs.isNotEmpty) ...[
        pdfSectionTitle('예상 경비'),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final entry in costs.entries)
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                  padding: const pw.EdgeInsets.all(10),
                  color: _paper,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _text(entry.key, size: 8.5, color: _gray),
                      pw.SizedBox(height: 6),
                      _text(entry.value, size: 14, bold: true, color: _navy),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 6),
        _text('식비·입장료는 포함되지 않습니다.', size: 8, color: _gray),
      ],
      if (lodgings.isNotEmpty) ...[
        pdfSectionTitle('숙소'),
        pw.TableHelper.fromTextArray(
          headers: ['숙소', '기간', '숙박비'],
          data: [
            for (final lodging in lodgings)
              [
                lodging['name'] ?? '',
                lodging['period'] ?? '',
                lodging['price'] ?? '',
              ],
          ],
          headerStyle: pw.TextStyle(
            fontSize: 8.5,
            color: _navy,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: _soft),
          cellStyle: const pw.TextStyle(fontSize: 9),
          border: null,
          cellPadding: const pw.EdgeInsets.all(7),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
      if (passes.isNotEmpty) ...[
        pdfSectionTitle('추천 교통패스'),
        for (final line in passes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: _text(line, size: 9),
          ),
      ],
      if (comment.trim().isNotEmpty) ...[
        pdfSectionTitle('플래너 코멘트'),
        for (final chunk in _chunks(comment))
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            color: _tealSoft,
            child: _text(chunk, size: 9),
          ),
      ],
      if (notes.isNotEmpty) ...[
        pdfSectionTitle('알아 둘 점'),
        for (final line in notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: _text('• $line', size: 8.5, color: _gray),
          ),
      ],
    ]),
  );
  for (final day in days) {
    doc.addPage(
      page([
        pw.Row(
          children: [
            pw.Container(
              width: 85,
              padding: const pw.EdgeInsets.all(12),
              color: _navy,
              child: pw.Column(
                children: [
                  _text('DAY', size: 8, color: PdfColors.white),
                  _text(
                    '${day.number}',
                    size: 22,
                    bold: true,
                    color: PdfColors.white,
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                color: _soft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _text(
                      itineraryPdfDayHeading(day.number, day.date),
                      size: 13,
                      bold: true,
                      color: _navy,
                    ),
                    pw.SizedBox(height: 4),
                    _text(
                      [day.guidance['관광 시간'], day.guidance['교통비']]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      size: 8.5,
                      color: _gray,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        for (final entry in day.guidance.entries.where(
          (e) => !['관광 시간', '교통비'].contains(e.key),
        ))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 60,
                  child: _text(entry.key, size: 8, color: _gray),
                ),
                pw.Expanded(child: _text(entry.value, size: 8.5)),
              ],
            ),
          ),
        pw.SizedBox(height: 10),
        ...day.items,
      ]),
    );
  }
  for (final day in days.where((day) => day.details.isNotEmpty)) {
    doc.addPage(
      page([
        pdfSectionTitle('${day.number}일차 · 방문·이동 상세 정보'),
        _text(
          '일정의 상세 보기에서 이동한 페이지입니다. 각 장소 아래에서 일정으로 돌아갈 수 있습니다.',
          size: 8,
          color: _gray,
        ),
        pw.SizedBox(height: 12),
        ...day.details,
      ]),
    );
  }
  return doc.save();
}
