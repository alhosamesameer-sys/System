import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import '../barcode/barcode_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override State<ProductsScreen> createState()=>_ProductsScreenState();
}
class _ProductsScreenState extends State<ProductsScreen> {
  final search=TextEditingController();
  Future<List<Map<String,Object?>>> load() async => (await LocalDatabase.instance.database).query('products',where:'is_active=1 AND (name LIKE ? OR barcode LIKE ?)',whereArgs:['%${search.text}%','%${search.text}%'],orderBy:'name');

  Future<String?> scanCode() => Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const BarcodeScreen()));

  Future<void> edit([Map<String,Object?>? item]) async {
    final name=TextEditingController(text:item?['name'] as String? ?? '');
    final barcode=TextEditingController(text:item?['barcode'] as String? ?? '');
    final price=TextEditingController(text:item==null?'':((item['sale_price_halalas'] as int)/100).toStringAsFixed(2));
    final qty=TextEditingController(text:item?['quantity']?.toString() ?? '');
    String unit=item?['unit'] as String? ?? 'حبة';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setDialog)=>AlertDialog(
      title:Text(item==null?'إضافة صنف':'تعديل صنف'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الصنف')),
        TextField(controller:barcode,decoration:InputDecoration(labelText:'الباركود',suffixIcon:IconButton(tooltip:'مسح الباركود بالكاميرا',icon:const Icon(Icons.qr_code_scanner),onPressed:()async{final code=await scanCode();if(code!=null){barcode.text=code;}}))),
        DropdownButtonFormField<String>(value:unit,decoration:const InputDecoration(labelText:'الوحدة'),items:['حبة','باكت','كرتون','علبة','كيلو','جرام','لتر','متر'].map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:(v){if(v!=null)setDialog(()=>unit=v);}),
        TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'سعر البيع (ر.س)')),
        TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية (اختياري)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))])));
    if(ok!=true)return;
    try {
      final db=await LocalDatabase.instance.database;
      final data={'name':name.text.trim(),'barcode':barcode.text.trim().isEmpty?null:barcode.text.trim(),'sale_price_halalas':Money.parseHalalas(price.text),'unit':unit,'quantity':qty.text.trim().isEmpty?null:double.parse(qty.text),'created_at':DateTime.now().toIso8601String()};
      if(data['name']=='' )throw Exception('اسم الصنف مطلوب');
      if(item==null){await db.insert('products',data);}else{await db.update('products',data,where:'id=?',whereArgs:[item['id']]);}
      if(mounted)setState((){});
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('لم يتم الحفظ: $e (قد يكون الباركود مكرراً)')));}
    finally{name.dispose();barcode.dispose();price.dispose();qty.dispose();}
  }
  Future<void> scan() async {final code=await scanCode();if(code!=null&&mounted){search.text=code;setState((){});}}
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('الأصناف'),actions:[IconButton(onPressed:scan,icon:const Icon(Icons.qr_code_scanner)),IconButton(onPressed:()=>edit(),icon:const Icon(Icons.add))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث بالاسم أو الباركود'))),
      Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:load(),builder:(c,s)=>!s.hasData?const Center(child:CircularProgressIndicator()):ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final p=s.data![i];return Card(child:ListTile(title:Text(p['name'] as String),subtitle:Text('باركود: ${p['barcode']??'—'}'),leading:const Icon(Icons.inventory_2),trailing:Text(Money.format(p['sale_price_halalas'] as int)),onTap:()=>edit(p),onLongPress:()async{await(await LocalDatabase.instance.database).update('products',{'is_active':0},where:'id=?',whereArgs:[p['id']]);if(mounted)setState((){});}));})))
    ]),
    floatingActionButton:FloatingActionButton(onPressed:()=>edit(),child:const Icon(Icons.add)));
}
