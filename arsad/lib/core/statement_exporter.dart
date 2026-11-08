import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class StatementExporter {
  static Future<void> export({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required bool asPdf,
  }) async {
    if (asPdf) {
      final pages=<pw.MemoryImage>[];
      const perPage=28;
      final calculatedPages=(rows.length/perPage).ceil();
      final pageCount=calculatedPages<1?1:calculatedPages;
      for(var page=0;page<pageCount;page++){
        final start=page*perPage;
        final end=(start+perPage<rows.length)?start+perPage:rows.length;
        final image=await _renderArabicPage(title,headers,rows.sublist(start,end),page+1,pageCount);
        pages.add(pw.MemoryImage(image));
      }
      final doc=pw.Document();
      for(final pageImage in pages){
        doc.addPage(pw.Page(pageFormat:const pw.PdfPageFormat(595,842,marginAll:18),build:(_)=>pw.Center(child:pw.Image(pageImage,fit:pw.BoxFit.contain))));
      }
      await Share.shareXFiles([XFile.fromData(await doc.save(),mimeType:'application/pdf',name:'arsad-statement.pdf')],text:title);
    } else {
      final book=Excel.createExcel();
      final sheet=book['كشف الحساب'];
      sheet.appendRow(headers.map((x)=>TextCellValue(x)).toList());
      for(final row in rows){sheet.appendRow(row.map((x)=>TextCellValue(x)).toList());}
      final bytes=book.save();
      if(bytes==null)throw Exception('تعذر إنشاء ملف Excel');
      await Share.shareXFiles([XFile.fromData(Uint8List.fromList(bytes),mimeType:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',name:'arsad-statement.xlsx')],text:title);
    }
  }

  static Future<Uint8List> _renderArabicPage(String title,List<String> headers,List<List<String>> rows,int page,int pages) async {
    const width=1240.0,height=1754.0,margin=54.0;
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    final bg=Paint()..color=const Color(0xFFFFFFFF);
    canvas.drawRect(const Rect.fromLTWH(0,0,width,height),bg);
    final navy=Paint()..color=const Color(0xFF073B78);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(margin,margin,width-margin*2,150),const Radius.circular(28)),navy);
    void draw(String value,double x,double y,double maxWidth,{double size=30,Color color=const Color(0xFF172033),bool bold=false,TextAlign align=TextAlign.right}){
      final painter=TextPainter(text:TextSpan(text:value,style:TextStyle(fontFamily:'sans-serif',fontSize:size,color:color,fontWeight:bold?FontWeight.bold:FontWeight.normal)),textDirection:ui.TextDirection.rtl,textAlign:align,maxLines:2,ellipsis:'…');
      painter.layout(maxWidth:maxWidth);
      painter.paint(canvas,Offset(x,y));
    }
    draw('أرصد | ARSAD',width-margin-500,margin+20,440,size:38,color:Colors.white,bold:true);
    draw(title,width-margin-650,margin+82,590,size:32,color:Colors.white,bold:true);
    var y=margin+190;
    final colWidth=(width-margin*2)/headers.length;
    canvas.drawRect(Rect.fromLTWH(margin,y,width-margin*2,66),Paint()..color=const Color(0xFFEAF1FA));
    for(var i=0;i<headers.length;i++){draw(headers[i],margin+(i+1)*colWidth-12,y+17,colWidth-24,size:23,bold:true);}
    y+=66;
    for(var r=0;r<rows.length;r++){
      final row=rows[r];
      final rect=Rect.fromLTWH(margin,y,width-margin*2,52);
      if(r.isEven)canvas.drawRect(rect,Paint()..color=const Color(0xFFF7F9FC));
      for(var i=0;i<headers.length&&i<row.length;i++){draw(row[i],margin+(i+1)*colWidth-12,y+12,colWidth-24,size:21);}
      y+=52;
    }
    draw('صفحة $page من $pages',width-margin-240,height-margin-25,220,size:20,color:const Color(0xFF64748B));
    final picture=recorder.endRecording();
    final image=await picture.toImage(width.toInt(),height.toInt());
    final data=await image.toByteData(format:ui.ImageByteFormat.png);
    image.dispose();picture.dispose();
    return data!.buffer.asUint8List();
  }
}
