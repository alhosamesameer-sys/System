import 'package:flutter/material.dart';
import '../../data/local_database.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override State<ReturnsScreen> createState()=>_ReturnsScreenState();
}
class _ReturnsScreenState extends State<ReturnsScreen> {
  final invoiceNo=TextEditingController();
  final reason=TextEditingController(text:'مرتجع من العميل');
  Map<String,Object?>? invoice;
  List<Map<String,Object?>> items=[];
  final qty=<int,TextEditingController>{};
  bool loading=false;
  bool saving=false;

  Future<void> find() async {
    setState(()=>loading=true);
    try {
      final db=await LocalDatabase.instance.database;
      final found=await db.query('invoices',where:'invoice_no=?',whereArgs:[invoiceNo.text.trim()],limit:1);
      if(found.isEmpty)throw Exception('لم يتم العثور على الفاتورة');
      final lines=await db.query('invoice_items',where:'invoice_id=?',whereArgs:[found.first['id']]);
      for(final controller in qty.values){controller.dispose();}
      if(!mounted)return;
      setState((){
        invoice=found.first;items=lines;qty.clear();
        for(final item in lines){qty[item['id'] as int]=TextEditingController(text:'0');}
      });
      if(found.first['status']=='fully_returned')throw Exception('هذه الفاتورة مرتجعة بالكامل');
    } catch(e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally {if(mounted)setState(()=>loading=false);}
  }

  Future<void> save() async {
    if(invoice==null||saving)return;
    setState(()=>saving=true);
    try {
      final selected=<int,double>{};
      for(final entry in qty.entries){final value=double.tryParse(entry.value.text)??0;if(value>0)selected[entry.key]=value;}
      await LocalDatabase.instance.createReturn(invoiceId:invoice!['id'] as int,quantities:selected,reason:reason.text);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل المردود وتحديث الحساب')));setState(()=>invoice=null);}
    } catch(e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل المردود: $e')));}
    finally {if(mounted)setState(()=>saving=false);}
  }
  @override void dispose(){invoiceNo.dispose();reason.dispose();for(final controller in qty.values){controller.dispose();}super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('المردودات')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      TextField(controller:invoiceNo,decoration:const InputDecoration(labelText:'رقم الفاتورة')),
      const SizedBox(height:8),
      FilledButton(onPressed:loading?null:find,child:Text(loading?'جار البحث...':'بحث عن الفاتورة')),
      if(invoice!=null)...[
        const SizedBox(height:12),
        Text('فاتورة: ${invoice!['invoice_no']} • ${invoice!['payment_method']=='cash'?'نقد':'شبكة'}',style:const TextStyle(fontWeight:FontWeight.bold)),
        ...items.map((item){
          final id=item['id'] as int;
          final remaining=(item['quantity'] as num).toDouble()-(item['returned_quantity'] as num).toDouble();
          return Card(child:ListTile(title:Text(item['product_name'] as String),subtitle:Text('المتاح للإرجاع: $remaining'),trailing:SizedBox(width:82,child:TextField(controller:qty[id],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية')))));
        }),
        TextField(controller:reason,decoration:const InputDecoration(labelText:'سبب الإرجاع')),
        const SizedBox(height:8),
        FilledButton(onPressed:saving?null:save,child:Text(saving?'جار الحفظ...':'حفظ المردود')),
      ],
    ]),
  );
}
