import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import '../barcode/barcode_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override State<SalesScreen> createState()=>_SalesScreenState();
}
class _SalesScreenState extends State<SalesScreen> {
  final search=TextEditingController();
  final cart=<int,Map<String,Object?>>{};
  String payment='cash';
  bool saving=false;

  Future<List<Map<String,Object?>>> products() async {
    final db=await LocalDatabase.instance.database;
    return db.query('products',where:'is_active=1 AND (name LIKE ? OR barcode LIKE ?)',whereArgs:['%$${search.text}%','%$${search.text}%'],orderBy:'name',limit:40);
  }
  int lineTotal(Map<String,Object?> item)=>(item['sale_price_halalas'] as int)*(item['qty'] as int);
  int get total=>cart.values.fold(0,(sum,item)=>sum+lineTotal(item));

  void add(Map<String,Object?> product) {
    final id=product['id'] as int;
    setState((){if(cart.containsKey(id)){cart[id]!['qty']=(cart[id]!['qty'] as int)+1;}else{cart[id]={...product,'qty':1};}});
  }
  Future<void> scan() async {
    final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const BarcodeScreen()));
    if(code==null||!mounted)return;
    final db=await LocalDatabase.instance.database;
    final found=await db.query('products',where:'barcode=? AND is_active=1',whereArgs:[code],limit:1);
    if(!mounted)return;
    if(found.isNotEmpty){add(found.first);search.clear();}else{search.text=code;setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الصنف غير مسجل، يمكنك إضافته من زر إضافة منتج جديد')));}
  }

  Future<void> editPrice(int id) async {
    final item=cart[id];if(item==null)return;
    final controller=TextEditingController(text:((item['sale_price_halalas'] as int)/100).toStringAsFixed(2));
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('تعديل سعر الوحدة'),content:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'السعر بالريال')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ'))]));
    if(ok==true&&mounted){try{final value=Money.parseHalalas(controller.text);setState(()=>item['sale_price_halalas']=value);}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
    controller.dispose();
  }

  Future<void> addNewProduct() async {
    final name=TextEditingController(text:search.text.trim());
    final barcode=TextEditingController();
    final price=TextEditingController();
    final quantity=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('إضافة منتج جديد للفاتورة'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الصنف')),
        TextField(controller:barcode,decoration:InputDecoration(labelText:'الباركود (اختياري)',suffixIcon:IconButton(icon:const Icon(Icons.qr_code_scanner),onPressed:()async{final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const BarcodeScreen()));if(code!=null)barcode.text=code;}))),
        TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'سعر البيع (ر.س)')),
        TextField(controller:quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية بالمخزون (اختياري)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ وإضافة للفاتورة'))]));
    if(ok==true){
      try{
        if(name.text.trim().isEmpty)throw Exception('أدخل اسم الصنف');
        final db=await LocalDatabase.instance.database;
        final id=await db.insert('products',{'name':name.text.trim(),'barcode':barcode.text.trim().isEmpty?null:barcode.text.trim(),'sale_price_halalas':Money.parseHalalas(price.text),'quantity':quantity.text.trim().isEmpty?null:double.parse(quantity.text),'created_at':DateTime.now().toIso8601String(),'is_active':1});
        final rows=await db.query('products',where:'id=?',whereArgs:[id],limit:1);
        if(rows.isNotEmpty&&mounted){add(rows.first);search.clear();}
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذرت إضافة المنتج: $e')));}
    }
    name.dispose();barcode.dispose();price.dispose();quantity.dispose();
  }

  Future<void> save() async {
    if(cart.isEmpty||saving)return;
    setState(()=>saving=true);
    try{
      await LocalDatabase.instance.createInvoice(items:cart.values.map((item)=><String,Object?>{'product_id':item['id'],'product_name':item['name'],'quantity':item['qty'],'unit_price_halalas':item['sale_price_halalas']}).toList(),paymentMethod:payment,stockEnabled:await LocalDatabase.instance.stockEnabled());
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ الفاتورة وتسجيل الحركة المالية')));Navigator.pop(context);}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الفاتورة: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('مبيعات جديدة'),actions:[IconButton(tooltip:'مسح الباركود',onPressed:scan,icon:const Icon(Icons.qr_code_scanner))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,12,4),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'اكتب اسم الصنف أو الباركود'))),
      SizedBox(height:150,child:FutureBuilder<List<Map<String,Object?>>>(future:products(),builder:(context,snapshot){
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        if(snapshot.data!.isEmpty)return const Center(child:Text('لا توجد أصناف مطابقة'));
        return ListView.builder(itemCount:snapshot.data!.length,itemBuilder:(context,index){final p=snapshot.data![index];return ListTile(dense:true,title:Text(p['name'] as String),subtitle:Text('سعر الوحدة: ${Money.format(p['sale_price_halalas'] as int)}'),trailing:IconButton(icon:const Icon(Icons.add_circle,color:Colors.blue),onPressed:()=>add(p)));});
      })),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:OutlinedButton.icon(onPressed:addNewProduct,icon:const Icon(Icons.add),label:const Text('إضافة منتج جديد'))),
      const Divider(),
      Expanded(child:cart.isEmpty?const Center(child:Text('لم تتم إضافة منتجات إلى الفاتورة')):ListView(children:cart.entries.map((entry){
        final item=entry.value;final qty=item['qty'] as int;final price=item['sale_price_halalas'] as int;
        return Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(item['name'] as String,style:const TextStyle(fontWeight:FontWeight.bold)),
          const SizedBox(height:5),
          Wrap(alignment:WrapAlignment.spaceBetween,spacing:12,runSpacing:6,children:[
            Text('الكمية: $qty'),
            Text('سعر الوحدة: ${Money.format(price)}'),
            Text('الإجمالي: ${Money.format(qty*price)}',style:const TextStyle(fontWeight:FontWeight.bold)),
          ]),
          Row(children:[
            IconButton(tooltip:'زيادة الكمية',onPressed:()=>setState(()=>item['qty']=qty+1),icon:const Icon(Icons.add_circle_outline)),
            IconButton(tooltip:'تقليل الكمية',onPressed:()=>setState(()=>item['qty']=qty>1?qty-1:1),icon:const Icon(Icons.remove_circle_outline)),
            TextButton(onPressed:()=>editPrice(entry.key),child:const Text('تعديل السعر')),
            const Spacer(),
            IconButton(onPressed:()=>setState(()=>cart.remove(entry.key)),icon:const Icon(Icons.delete,color:Colors.red)),
          ])
        ])));
      }).toList())),
      Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('إجمالي الفاتورة',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text(Money.format(total),style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))]),
        SegmentedButton<String>(segments:const [ButtonSegment(value:'cash',label:Text('نقد'),icon:Icon(Icons.payments)),ButtonSegment(value:'network',label:Text('شبكة'),icon:Icon(Icons.credit_card))],selected:{payment},onSelectionChanged:(v)=>setState(()=>payment=v.first)),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving||cart.isEmpty?null:save,icon:const Icon(Icons.save),label:Text(saving?'جار الحفظ':'حفظ الفاتورة'))),
      ]))
    ])
  );
}
