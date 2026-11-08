import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
class ReturnsScreen extends StatefulWidget {const ReturnsScreen({super.key});@override State<ReturnsScreen> createState()=>_ReturnsScreenState();}
class _ReturnsScreenState extends State<ReturnsScreen>{
 final invoiceNo=TextEditingController();Map<String,Object?>? invoice;List<Map<String,Object?>> items=[];final qty=<int,TextEditingController>{};bool loading=false;
 Future<void> find()async{setState(()=>loading=true);try{final db=await LocalDatabase.instance.database;final inv=await db.query('invoices',where:'invoice_no=?',whereArgs:[invoiceNo.text.trim()],limit:1);if(inv.isEmpty)throw Exception('لم يتم العثور على الفاتورة');final lines=await db.query('invoice_items',where:'invoice_id=?',whereArgs:[inv.first['id']]);setState((){invoice=inv.first;items=lines;qty.clear();for(final x in lines){final remaining=(x['quantity'] as num).toDouble()-(x['returned_quantity'] as num).toDouble();qty[x['id'] as int]=TextEditingController(text:remaining>0?'0':'0');}});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}
 Future<void> save()async{if(invoice==null)return;try{final selected=<int,double>{};for(final e in qty.entries){final n=double.tryParse(e.value.text)??0;if(n>0)selected[e.key]=n;}await LocalDatabase.instance.createReturn(invoiceId:invoice!['id'] as int,quantities:selected,reason:'مرتجع من شاشة المردودات',stockEnabled:await LocalDatabase.instance.stockEnabled());if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل المردود')));setState(()=>invoice=null);}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل المردود: $e')));}}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('المردودات')),body:ListView(padding:const EdgeInsets.all(16),children:[
 TextField(controller:invoiceNo,decoration:const InputDecoration(labelText:'رقم الفاتورة')),
 FilledButton(onPressed:loading?null:find,child:const Text('بحث عن الفاتورة')),
 if(invoice!=null)...[
 Text('فاتورة: ${invoice!['invoice_no']} • ${invoice!['payment_method']=='cash'?'نقد':'شبكة'}'),
 ...items.map((x){final id=x['id'] as int;final remain=(x['quantity'] as num)-(x['returned_quantity'] as num);return Card(child:ListTile(title:Text(x['product_name'] as String),subtitle:Text('المتبقي للإرجاع: $remain'),trailing:SizedBox(width:76,child:TextField(controller:qty[id],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'كمية')))));}),
 FilledButton(onPressed:save,child:const Text('حفظ المردود'))
 ]]));
}
