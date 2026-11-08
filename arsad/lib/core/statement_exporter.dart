import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:excel/excel.dart' hide TextSpan;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/local_database.dart';

class StatementExporter {
  static Future<void> export({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required bool asPdf,
    String? periodLabel,
  }) async {
    final db = await LocalDatabase.instance.database;
    final settings = await db.query('store_settings', where: 'id=1', limit: 1);
    final store = settings.isEmpty ? <String, Object?>{} : settings.first;
    final storeName = (store['store_name'] ?? 'متجري').toString();
    final phone = (store['phone'] ?? '').toString();
    final address = (store['address'] ?? '').toString();
    final now = DateTime.now();
    final issued = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (asPdf) {
      const perPage = 23;
      final count = rows.isEmpty ? 1 : (rows.length / perPage).ceil();
      final doc = pw.Document();
      for (var page = 0; page < count; page++) {
        final start = page * perPage;
        final end = (start + perPage < rows.length) ? start + perPage : rows.length;
        final png = await _renderPage(
          storeName: storeName, phone: phone, address: address,
          title: title, headers: headers, rows: rows.sublist(start, end),
          page: page + 1, pages: count, issued: issued,
          periodLabel: periodLabel, totalRows: rows.length,
        );
        doc.addPage(pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          build: (_) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        ));
      }
      await Share.shareXFiles([
        XFile.fromData(await doc.save(), mimeType: 'application/pdf', name: 'arsad-statement.pdf')
      ], text: title);
    } else {
      final book = Excel.createExcel();
      final sheet = book['كشف الحساب'];
      sheet.appendRow([TextCellValue(storeName)]);
      sheet.appendRow([TextCellValue('أرصد | ARSAD — $title')]);
      sheet.appendRow([TextCellValue('تاريخ الإصدار: $issued')]);
      if (periodLabel != null && periodLabel.isNotEmpty) {
        sheet.appendRow([TextCellValue('الفترة: $periodLabel')]);
      }
      if (phone.isNotEmpty) sheet.appendRow([TextCellValue('الهاتف: $phone')]);
      if (address.isNotEmpty) sheet.appendRow([TextCellValue('العنوان: $address')]);
      sheet.appendRow([TextCellValue('')]);
      final headerRow = sheet.maxRows;
      sheet.appendRow(headers.map((x) => TextCellValue(x)).toList());
      for (final row in rows) {
        sheet.appendRow(row.map((x) => TextCellValue(x)).toList());
      }
      final navy = ExcelColor.fromHexString('#17365D');
      final pale = ExcelColor.fromHexString('#EAF0F7');
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRow));
        cell.cellStyle = CellStyle(
          bold: true, fontColorHex: ExcelColor.white, backgroundColorHex: navy,
          horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
        );
        sheet.setColumnWidth(c, headers[c].length > 12 ? 24 : 18);
      }
      for (var r = headerRow + 1; r < sheet.maxRows; r++) {
        for (var c = 0; c < headers.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = CellStyle(
            backgroundColorHex: r.isEven ? pale : ExcelColor.white,
            horizontalAlign: HorizontalAlign.Right, verticalAlign: VerticalAlign.Center,
          );
        }
      }
      for (var r = 0; r < headerRow; r++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle =
            CellStyle(bold: true, fontSize: r == 0 ? 16 : 12, fontColorHex: navy);
      }
      final bytes = book.save();
      if (bytes == null) throw Exception('تعذر إنشاء ملف Excel');
      await Share.shareXFiles([
        XFile.fromData(Uint8List.fromList(bytes),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: 'arsad-statement.xlsx')
      ], text: title);
    }
  }

  static Future<Uint8List> _renderPage({
    required String storeName, required String phone, required String address,
    required String title, required List<String> headers, required List<List<String>> rows,
    required int page, required int pages, required String issued, required String? periodLabel,
    required int totalRows,
  }) async {
    const width = 1240.0, height = 1754.0, margin = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    final navy = Paint()..color = const Color(0xFF17365D);
    final border = Paint()..color = const Color(0xFFD5DDE8)..style = PaintingStyle.stroke..strokeWidth = 1;
    final pale = Paint()..color = const Color(0xFFEAF0F7);
    canvas.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(margin, margin, width - margin * 2, 190),
      const Radius.circular(18)), navy);
    canvas.drawCircle(const Offset(112, 125), 48, Paint()..color = Colors.white);
    final logo = TextPainter(
      text: const TextSpan(text: 'A', style: TextStyle(fontFamily: 'sans-serif',
        fontSize: 58, fontWeight: FontWeight.bold, color: Color(0xFF17365D))),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    logo.paint(canvas, const Offset(94, 92));
    void draw(String value, double x, double y, double maxWidth, {
      double size = 25, Color color = const Color(0xFF172033), bool bold = false,
      TextAlign align = TextAlign.right, int maxLines = 2,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: TextStyle(fontFamily: 'sans-serif',
          fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: ui.TextDirection.rtl, textAlign: align,
        maxLines: maxLines, ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x, y));
    }
    draw(storeName, width - margin - 650, margin + 28, 610, size: 42, color: Colors.white, bold: true);
    draw('أرصد | ARSAD', width - margin - 650, margin + 85, 610, size: 25, color: const Color(0xFFDCE8F5), bold: true);
    final info = [if (phone.isNotEmpty) 'الهاتف: $phone', if (address.isNotEmpty) address].join('  •  ');
    if (info.isNotEmpty) {
      draw(info, width - margin - 650, margin + 135, 610, size: 19, color: Colors.white);
    }
    var y = margin + 220;
    draw(title, margin, y, width - margin * 2, size: 36, bold: true, align: TextAlign.center);
    y += 54;
    draw('تاريخ الإصدار: $issued', width - margin - 470, y, 450, size: 19);
    if (periodLabel != null && periodLabel.isNotEmpty) {
      draw('الفترة: $periodLabel', margin, y, 520, size: 19);
    }
    y += 48;
    final tableWidth = width - margin * 2;
    final colWidth = tableWidth / headers.length;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, y, tableWidth, 64), const Radius.circular(8)), pale);
    for (var i = 0; i < headers.length; i++) {
      draw(headers[i], margin + i * colWidth + 8, y + 17, colWidth - 16,
        size: headers.length > 5 ? 19 : 22, bold: true, align: TextAlign.center);
    }
    y += 64;
    for (var r = 0; r < rows.length; r++) {
      final rect = Rect.fromLTWH(margin, y, tableWidth, 48);
      canvas.drawRect(rect, r.isEven ? pale : (Paint()..color = Colors.white));
      canvas.drawRect(rect, border);
      for (var c = 0; c < headers.length && c < rows[r].length; c++) {
        draw(rows[r][c], margin + c * colWidth + 7, y + 12, colWidth - 14,
          size: headers.length > 5 ? 17 : 19, align: TextAlign.center, maxLines: 1);
      }
      y += 48;
    }
    y += 26;
    canvas.drawLine(Offset(margin, y), Offset(width - margin, y), border);
    draw('عدد السجلات: $totalRows', width - margin - 360, y + 18, 340, size: 20, bold: true);
    draw('صفحة $page من $pages', margin, height - margin - 32, 300, size: 19, color: const Color(0xFF64748B));
    draw('نظام أرصد للمبيعات والحسابات', width - margin - 450, height - margin - 32, 430, size: 18, color: const Color(0xFF64748B));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }
}
