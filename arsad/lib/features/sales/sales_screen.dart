import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import '../barcode/barcode_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override State<SalesScreen> createState() => _SalesScreenState();
}
class _SalesScreenState extends State<SalesScreen> {
  final search = TextEditingController();
  final cart = <int,Map<String,Object?>>{};
  String payment = 'cash';
  bool saving = false;

  Future<List<Map<String,Object?>>> products() async {
    final db = await LocalDatabase.instance.database;
    return db.query('products', where:'is_active=1 AND (name LIKE ? OR barcode LIKE ?)', whereArgs:['%${search.text}%','%${search.text}%'], limit:40);
  }
  int get total => cart.values.fold(0, (sum, item) => sum + (item['sale_price_halalas'] as int) * (item['qty'] as int));
  void add(Map<String,Object?> product) {
    final id = product['id'] as int;
    setState(() {
      if (cart.containsKey(id)) { cart[id]!['qty'] = (cart[id]!['qty'] as int) + 1; }
      else { cart[id] = {...product, 'qty':1}; }
    });
  }
  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScreen()));
    if (code != null && mounted) {
      final db=await LocalDatabase.instance.database;
      final found=await db.query('products',where:'barcode=? AND is_active=1',whereArgs:[code],limit:1);
      if(!mounted)return;
      if(found.isNotEmpty){add(found.first);}else{search.text=code;setState((){});}
    }
  }
  Future<void> editPrice(int id) async {
    final item=cart[id]; if(item==null)return;
    final controller=TextEditingController(text:((item['sale_price_halalas'] as int)/100).toStringAsFixed(2));
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('تعديل سعر الوحدة'),content:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'السعر بالريال')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ'))]));
    if(ok==true&&mounted){try{final value=Money.parseHalalas(controller.text);setState(()=>item['sale_price_halalas']=value);}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
  }
  Future<void> save() async {
    if (cart.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      await LocalDatabase.instance.createInvoice(
        items: cart.values.map((item) => <String,Object?>{'product_id':item['id'],'product_name':item['name'],'quantity':item['qty'],'unit_price_halalas':item['sale_price_halalas']}).toList(),
        paymentMethod: payment,
        stockEnabled: await LocalDatabase.instance.stockEnabled(),
      );
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة وتسجيل الحركة المالية'))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الفاتورة: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مبيعات جديدة'), actions:[IconButton(onPressed:scan, icon:const Icon(Icons.qr_code_scanner))]),
    body: Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:search,onChanged:(_) => setState(() {}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث أو امسح الباركود'))),
      SizedBox(height:160,child:FutureBuilder<List<Map<String,Object?>>>(future:products(),builder:(context,snapshot){
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        return ListView.builder(itemCount:snapshot.data!.length,itemBuilder:(context,index){final product=snapshot.data![index];return ListTile(title:Text(product['name'] as String),subtitle:Text(Money.format(product['sale_price_halalas'] as int)),trailing:IconButton(icon:const Icon(Icons.add_circle,color:Colors.blue),onPressed:()=>add(product)));});
      })),
      const Divider(),
      Expanded(child:ListView(children:cart.entries.map((entry)=>ListTile(
        title:Text(entry.value['name'] as String),
        subtitle:Text('الكمية: ${entry.value['qty']} • سعر الوحدة: ${Money.format(entry.value['sale_price_halalas'] as int)}'),
        onTap:()=>editPrice(entry.key),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(onPressed:()=>setState(()=>entry.value['qty']=(entry.value['qty'] as int)+1),icon:const Icon(Icons.add)),
          IconButton(onPressed:()=>setState(()=>entry.value['qty']=(entry.value['qty'] as int)>1?(entry.value['qty'] as int)-1:1),icon:const Icon(Icons.remove)),
          IconButton(onPressed:()=>setState(()=>cart.remove(entry.key)),icon:const Icon(Icons.delete,color:Colors.red)),
        ]),
      )).toList())),
      Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        Text('الإجمالي: ${Money.format(total)}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        SegmentedButton<String>(segments:const [ButtonSegment(value:'cash',label:Text('نقد'),icon:Icon(Icons.payments)),ButtonSegment(value:'network',label:Text('شبكة'),icon:Icon(Icons.credit_card))],selected:{payment},onSelectionChanged:(value)=>setState(()=>payment=value.first)),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'جار الحفظ':'حفظ الفاتورة'))),
      ])),
    ]),
  );
}
