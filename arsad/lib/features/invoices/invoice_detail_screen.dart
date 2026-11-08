import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../core/money.dart';
import '../../core/thermal_printer.dart';
import '../../data/local_database.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key,required this.invoiceId});
  Future<Map<String,Object?>> load() async {
    final db=await LocalDatabase.instance.database;
    final inv=(await db.query('invoices',where:'id=?',whereArgs:[invoiceId])).first;
    final lines=await db.query('invoice_items',where:'invoice_id=?',whereArgs:[invoiceId]);
    final store=(await db.query('store_settings',where:'id=1')).first;
    return {'invoice':inv,'items':lines,'store':store};
  }
  Future<void> printInvoice(Map<String,Object?> data) async {
    final doc=pw.Document();
    final inv=data['invoice'] as Map<String,Object?>;
    final lines=data['items'] as List<Map<String,Object?>>;
    final store=data['store'] as Map<String,Object?>;
    doc.addPage(pw.Page(build:(ctx)=>pw.Directionality(textDirection:pw.TextDirection.rtl,child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
      pw.Text(store['store_name'] as String,style:const pw.TextStyle(fontSize:20)),
      pw.Text('ARSAD • فاتورة رقم: ${inv['invoice_no']}'),
      pw.Text('التاريخ: ${inv['created_at']}'),
      pw.Divider(),
      ...lines.map((x)=>pw.Text('${x['product_name']}  × ${x['quantity']}  = ${Money.format(x['line_total_halalas'] as int)}')),
      pw.Divider(),
      pw.Text('الإجمالي: ${Money.format(inv['total_halalas'] as int)}'),
      pw.Text('الدفع: ${inv['payment_method']=='cash'?'نقد':'شبكة'}'),
    ]))));
    await Printing.layoutPdf(onLayout:(_)=>doc.save());
  }

  Future<void> shareInvoice(Map<String,Object?> data) async {
    final inv=data['invoice'] as Map<String,Object?>;
    final lines=data['items'] as List<Map<String,Object?>>;
    final store=data['store'] as Map<String,Object?>;
    final text=<String>[
      store['store_name'] as String,
      'فاتورة رقم: ${inv['invoice_no']}',
      'التاريخ: ${inv['created_at']}',
      ...lines.map((x)=>'${x['product_name']} × ${x['quantity']} — ${Money.format(x['line_total_halalas'] as int)}'),
      'الإجمالي: ${Money.format(inv['total_halalas'] as int)}',
      'طريقة الدفع: ${inv['payment_method']=='cash'?'نقد':'شبكة'}',
    ].join('\n');
    await Share.share(text,subject:'فاتورة أرصد ${inv['invoice_no']}');
  }

  Future<void> printThermal(Map<String,Object?> data) async {
    final db=await LocalDatabase.instance.database;
    final settings=await db.query('app_settings',where:'key IN (?,?)',whereArgs:['printer_address','printer_paper']);
    String? address;var paper=58;
    for(final row in settings){if(row['key']=='printer_address')address=row['value'] as String;if(row['key']=='printer_paper')paper=int.tryParse(row['value'] as String)??58;}
    if(address==null||address.isEmpty)throw Exception('اختر طابعة من إعدادات الطابعة أولاً');
    final inv=data['invoice'] as Map<String,Object?>;
    final lines=data['items'] as List<Map<String,Object?>>;
    final store=data['store'] as Map<String,Object?>;
    final profile=await CapabilityProfile.load();
    final generator=Generator(paper==80?PaperSize.mm80:PaperSize.mm58,profile);
    final bytes=<int>[];
    bytes.addAll(generator.text(store['store_name'] as String,styles:const PosStyles(align:PosAlign.center,bold:true,height:PosTextSize.size2,width:PosTextSize.size2)));
    bytes.addAll(generator.text('ARSAD',styles:const PosStyles(align:PosAlign.center,bold:true)));
    bytes.addAll(generator.text('Invoice: ${inv['invoice_no']}'));
    bytes.addAll(generator.text('Date: ${inv['created_at']}'));
    bytes.addAll(generator.hr());
    for(final item in lines){
      bytes.addAll(generator.text('${item['product_name']} x ${item['quantity']}'));
      bytes.addAll(generator.text('Unit: ${Money.format(item['unit_price_halalas'] as int)}  Total: ${Money.format(item['line_total_halalas'] as int)}'));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('TOTAL: ${Money.format(inv['total_halalas'] as int)}',styles:const PosStyles(bold:true,align:PosAlign.center)));
    bytes.addAll(generator.text('Payment: ${inv['payment_method']=='cash'?'CASH':'NETWORK'}'));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    await ThermalPrinterService.printBytes(address:address,bytes:bytes);
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('تفاصيل الفاتورة')),
    body:FutureBuilder<Map<String,Object?>>(future:load(),builder:(context,snapshot){
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final inv=snapshot.data!['invoice'] as Map<String,Object?>;
      final lines=snapshot.data!['items'] as List<Map<String,Object?>>;
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text('فاتورة ${inv['invoice_no']}'),
        ...lines.map((x)=>ListTile(title:Text(x['product_name'] as String),subtitle:Text('الكمية: ${x['quantity']}'),trailing:Text(Money.format(x['line_total_halalas'] as int)))),
        Text('الإجمالي: ${Money.format(inv['total_halalas'] as int)}'),
        FilledButton.icon(onPressed:()=>printInvoice(snapshot.data!),icon:const Icon(Icons.print),label:const Text('طباعة / PDF')),
        OutlinedButton.icon(onPressed:()=>shareInvoice(snapshot.data!),icon:const Icon(Icons.share),label:const Text('مشاركة الفاتورة')),
        OutlinedButton.icon(onPressed:()async{try{await printThermal(snapshot.data!);}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذرت الطباعة الحرارية: $e')));}},icon:const Icon(Icons.bluetooth),label:const Text('طباعة حرارية Bluetooth')),
      ]);
    }),
  );
}
