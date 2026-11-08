import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/thermal_printer.dart';
import '../../data/local_database.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});
  @override State<PrinterScreen> createState()=>_PrinterScreenState();
}
class _PrinterScreenState extends State<PrinterScreen> {
  List<Map<String,String>> devices=[];
  String? selected;
  int paper=58;
  bool loading=false;
  String? message;

  Future<void> load() async {
    setState(()=>loading=true);
    try {
      message=null;
      final db=await LocalDatabase.instance.database;
      final rows=await db.query('app_settings',where:'key IN (?,?)',whereArgs:['printer_address','printer_paper']);
      for(final row in rows){if(row['key']=='printer_address')selected=row['value'] as String;if(row['key']=='printer_paper')paper=int.tryParse(row['value'] as String)??58;}
      devices=await ThermalPrinterService.bondedDevices();
      if(selected!=null && !devices.any((device)=>device['address']==selected))selected=null;
    } catch(e){message='$e';}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> save() async {
    final db=await LocalDatabase.instance.database;
    if(selected==null)throw Exception('اختر طابعة مقترنة أولاً');
    await db.insert('app_settings',{'key':'printer_address','value':selected!},conflictAlgorithm:ConflictAlgorithm.replace);
    await db.insert('app_settings',{'key':'printer_paper','value':'$paper'},conflictAlgorithm:ConflictAlgorithm.replace);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ إعدادات الطابعة')));
  }

  Future<void> testPrint() async {
    if(selected==null)throw Exception('اختر طابعة مقترنة أولاً');
    final bytes=<int>[0x1B,0x40,...'ARSAD - TEST PRINT\nBluetooth ESC/POS\nPaper: $paper mm\n\n'.codeUnits,0x1D,0x56,0x41,0x03];
    await ThermalPrinterService.printBytes(address:selected!,bytes:bytes);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال صفحة الاختبار إلى الطابعة')));
  }

  @override void initState(){super.initState();load();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('إعدادات الطابعة')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('اقرن الطابعة الحرارية من إعدادات Bluetooth في الهاتف أولاً، ثم اضغط تحديث.'),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:loading?null:load,icon:const Icon(Icons.refresh),label:const Text('تحديث الطابعات المقترنة')),
      if(loading)const LinearProgressIndicator(),
      if(message!=null)Text(message!,style:const TextStyle(color:Colors.red)),
      DropdownButtonFormField<String>(initialValue:selected,decoration:const InputDecoration(labelText:'الطابعة'),items:devices.map((device)=>DropdownMenuItem(value:device['address'],child:Text('${device['name']} • ${device['address']}'))).toList(),onChanged:(value)=>setState(()=>selected=value)),
      const SizedBox(height:12),
      DropdownButtonFormField<int>(initialValue:paper,decoration:const InputDecoration(labelText:'عرض الورق'),items:const [DropdownMenuItem(value:58,child:Text('58 mm')),DropdownMenuItem(value:80,child:Text('80 mm'))],onChanged:(value)=>setState(()=>paper=value??58)),
      const SizedBox(height:16),
      FilledButton(onPressed:()async{try{await save();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('حفظ الإعدادات')),
      OutlinedButton.icon(onPressed:()async{try{await testPrint();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},icon:const Icon(Icons.print),label:const Text('اختبار الطباعة')),
    ]),
  );
}
