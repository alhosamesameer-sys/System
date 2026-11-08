import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import '../barcode/barcode_screen.dart';

class SalesScreen extends StatefulWidget { const SalesScreen({super.key}); @override State<SalesScreen> createState()=>_SalesScreenState(); }
class _SalesScreenState extends State<SalesScreen> {
 final search=TextEditingController(); final cart=<int,Map<String,Object?>>{}; String payment='cash'; bool saving=false;
 Future<List<Map<String,Object?>>> products() async => (await LocalDatabase.instance.database).query('products',where:'is_active=1 AND (name LIKE ? OR barcode LIKE ?)',whereArgs:['%${search.text}%','%${search.text}%'],limit:40);
 int get total=>cart.values.fold(0,(v,p)=>v+(p['sale_price_halalas'] as int)*(p['qty'] as int));
 void add(Map<String,Object?> p){final id=p['id'] as int;setState((){if(cart.containsKey(id)){cart[id]!['qty']=(cart[id]!['qty'] as int)+1;}else{cart[id]={...p,'qty':1};}});}
 Future<void> scan()async{final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const BarcodeScreen()));if(code!=null){search.text=code;setState((){});}}
 Future<void> save()async{if(cart.isEmpty||saving)return;setState(()=>saving=true);try{final stock=await LocalDatabase.instance.stockEnabled();await LocalDatabase.instance.createInvoice(items:cart.values.map((p)=>{'product_id':p['id'],'product_name':p['name'],'quantity':p['qty'],'unit_price_halalas':p['sale_price_halalas']}).toList(),paymentMethod:payment,stockEnabled:stock);if(mounted){setState(cart.clear);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ الفاتورة وتسجيل الحركة المالية')));Navigator.pop(context);}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الفاتورة: $e')));}finally{if(mounted)setState(()=>saving=false);}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مبيعات جديدة'),actions:[IconButton(onPressed:scan,icon:const Icon(Icons.qr_code_scanner))]),body:Column(children:[
 Padding(padding:const EdgeInsets.all(12),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث أو امسح الباركود')),
 SizedBox(height:160,child:FutureBuilder<List<Map<String,Object?>>>(future:products(),builder:(c,s)=>!s.hasData?const Center(child:CircularProgressIndicator()):ListView(children:s.data!.map((p)=>ListTile(title:Text(p['name'] as String),subtitle:Text(Money.format(p['sale_price_halalas'] as int)),trailing:IconButton(icon:const Icon(Icons.add_circle,color:Colors.blue),onPressed:()=>add(p))).toList()))),
 const Divider(),Expanded(child:ListView(children:cart.entries.map((e)=>ListTile(title:Text(e.value['name'] as String),subtitle:Text('الكمية: ${e.value['qty']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>setState(()=>e.value['qty']=(e.value['qty'] as int)+1),icon:const Icon(Icons.add)),IconButton(onPressed:()=>setState(()=>e.value['qty']=(e.value['qty'] as int)-1<=0?1:(e.value['qty'] as int)-1),icon:const Icon(Icons.remove)),IconButton(onPressed:()=>setState(()=>cart.remove(e.key)),icon:const Icon(Icons.delete,color:Colors.red))]))).toList())),
 Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text('الإجمالي: ${Money.format(total)}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Row(children:[Expanded(child:RadioListTile<String>(value:'cash',groupValue:payment,title:const Text('نقد'),onChanged:(v)=>setState(()=>payment=v!))),Expanded(child:RadioListTile<String>(value:'network',groupValue:payment,title:const Text('شبكة'),onChanged:(v)=>setState(()=>payment=v!)))]),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'جار الحفظ':'حفظ الفاتورة')))]))
 ]));
}
