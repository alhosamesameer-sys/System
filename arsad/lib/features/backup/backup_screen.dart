import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/local_database.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});
  static const tables=['users','store_settings','products','invoices','invoice_items','returns','return_items','cash_transactions','network_transactions','expenses','stock_movements','app_settings'];

  Future<void> export(BuildContext context) async {
    final db=await LocalDatabase.instance.database;
    final tableData=<String,Object?>{};
    for(final table in tables){tableData[table]=await db.query(table);}
    final data=<String,Object?>{'format':'ARSAD_BACKUP','version':1,'created_at':DateTime.now().toIso8601String(),'tables':tableData};
    final bytes=utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    await Share.shareXFiles([XFile.fromData(bytes,mimeType:'application/json',name:'arsad-backup.json')]);
  }

  Future<void> restore(BuildContext context) async {
    final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
    if(picked==null)return;
    try {
      final bytes=picked.files.single.bytes;
      if(bytes==null)throw Exception('تعذر قراءة الملف');
      final decoded=jsonDecode(utf8.decode(bytes));
      if(decoded is! Map<String,dynamic> || decoded['format']!='ARSAD_BACKUP' || decoded['version']!=1)throw Exception('صيغة النسخة غير معروفة');
      final tablesMap=decoded['tables'];
      if(tablesMap is! Map<String,dynamic>)throw Exception('بيانات الجداول غير صحيحة');
      for(final table in tables){
        final rows=tablesMap[table];
        if(rows is! List)throw Exception('الجدول $table غير موجود أو غير صالح');
        for(final row in rows){if(row is! Map)throw Exception('صف غير صالح في $table');}
      }
      final db=await LocalDatabase.instance.database;
      await db.transaction((txn) async {
        for(final table in tables.reversed){await txn.delete(table);}
        for(final table in tables){
          final rows=tablesMap[table] as List;
          for(final row in rows){await txn.insert(table,Map<String,Object?>.from(row as Map));}
        }
      });
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تمت الاستعادة بنجاح')));
    } catch(e) {
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشلت الاستعادة: $e')));
    }
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('النسخ الاحتياطي')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('احفظ نسخة JSON في مكان آمن. الاستعادة تستبدل بيانات التطبيق الحالية.'),
      const SizedBox(height:16),
      FilledButton.icon(onPressed:()=>export(context),icon:const Icon(Icons.save_alt),label:const Text('تصدير نسخة احتياطية')),
      OutlinedButton.icon(onPressed:() async {
        final confirmed=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
          title:const Text('تأكيد الاستعادة'),
          content:const Text('سيتم استبدال البيانات الحالية. هل تريد المتابعة؟'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('متابعة'))],
        ));
        if(confirmed==true && context.mounted)await restore(context);
      },icon:const Icon(Icons.restore),label:const Text('استعادة نسخة')),
    ]),
  );
}
