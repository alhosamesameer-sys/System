import 'package:flutter/material.dart';
import '../../core/money.dart';
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

  Future<List<Map<String,Object?>>> loadInvoices() async {
    final db=await LocalDatabase.instance.database;
    final q=invoiceNo.text.trim();
    return db.rawQuery('SELECT * FROM invoices WHERE invoice_no LIKE ? OR id IN (SELECT invoice_id FROM invoice_items WHERE product_name LIKE ?) ORDER BY id DESC LIMIT 100',['%$q%','%$q%']);
  }

  Future<void> selectInvoice(Map<String,Object?> selected) async {
    setState(()=>loading=true);
    try {
      final db=await LocalDatabase.instance.database;
      final found=await db.query('invoices',where:'id=?',whereArgs:[selected['id']],limit:1);
      if(found.isEmpty)throw Exception('لم يتم العثور على الفاتورة');
      final lines=await db.query('invoice_items',where:'invoice_id=?',whereArgs:[selected['id']]);
      for(final controller in qty.values){controller.dispose();}
      if(!mounted)return;
      setState((){
        invoice=found.first;items=lines;qty.clear();
        for(final item in lines){qty[item['id'] as int]=TextEditingController(text:'0');}
      });
      if(found.first['status']=='fully_returned')ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('هذه الفاتورة مرتجعة بالكامل')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> save() async {
    if(invoice==null||saving)return;
    setState(()=>saving=true);
    try{
      final selected=<int,double>{};
      for(final entry in qty.entries){final value=double.tryParse(entry.value.text)??0;if(value>0)selected[entry.key]=value;}
      await LocalDatabase.instance.createReturn(invoiceId:invoice!['id'] as int,quantities:selected,reason:reason.text);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل المردود وتحديث الحساب')));setState(()=>invoice=null);}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل المردود: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  @override void dispose(){invoiceNo.dispose();reason.dispose();for(final controller in qty.values){controller.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('المردودات')),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:invoiceNo,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'ابحث برقم الفاتورة أو اسم الصنف'))),
      if(invoice==null)Expanded(child:FutureBuilder<void>(future:loadInvoices(),builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        final invoices=snapshot.data!;
        if(invoices.isEmpty)return const Center(child:Text('لا توجد فواتير مطابقة'));
        return ListView.builder(itemCount:invoices.length,itemBuilder:(context,index){
          final row=invoices[index];
          return Card(child:ListTile(
            leading:const Icon(Icons.receipt_long),
            title:Text('فاتورة ${row['invoice_no']}'),
            subtitle:Text('${row['created_at']} • ${row['payment_method']=='cash'?'نقد':'شبكة'} • ${row['status']=='fully_returned'?'مرتجعة بالكامل':'متاحة للمردود'}'),
            trailing:Text(Money.format(row['total_halalas'] as int)),
            onTap:()=>selectInvoice(row),
          ));
        });
      })),
      if(invoice!=null)Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
        Row(children:[Expanded(child:Text('فاتورة: ${invoice!['invoice_no']} • ${invoice!['payment_method']=='cash'?'نقد':'شبكة'}',style:const TextStyle(fontWeight:FontWeight.bold))),TextButton(onPressed:()=>setState(()=>invoice=null),child:const Text('رجوع'))]),
        Text('إجمالي الفاتورة: ${Money.format(invoice!['total_halalas'] as int)}'),
        const SizedBox(height:8),
        ...items.map((item){
          final id=item['id'] as int;
          final remaining=(item['quantity'] as num).toDouble()-(item['returned_quantity'] as num).toDouble();
          final unit=item['unit_price_halalas'] as int;
          return Card(child:ListTile(
            title:Text(item['product_name'] as String),
            subtitle:Text('سعر الوحدة: ${Money.format(unit)} • المتاح للإرجاع: $remaining'),
            trailing:SizedBox(width:78,child:TextField(controller:qty[id],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية'))),
          ));
        }),
        TextField(controller:reason,decoration:const InputDecoration(labelText:'سبب الإرجاع')),
        const SizedBox(height:8),
        FilledButton(onPressed:saving||invoice!['status']=='fully_returned'?null:save,child:Text(saving?'جار الحفظ...':'حفظ المردود')),
      ]))
    ])
  );
}
