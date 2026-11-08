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
  static const units=['حبة','باكت','كرتون','علبة','كيلو','جرام','لتر','متر'];
  String payment='cash';
  bool saving=false;
  bool showSuggestions=false;

  Future<List<Map<String,Object?>>> products() async {
    final q=search.text.trim();
    if(q.isEmpty)return [];
    final db=await LocalDatabase.instance.database;
    return db.query('products',where:'is_active=1 AND (name LIKE ? OR barcode LIKE ?)',whereArgs:['%$q%','%$q%'],orderBy:'name',limit:8);
  }
  int lineTotal(Map<String,Object?> item)=>(item['sale_price_halalas'] as int)*(item['qty'] as int);
  int get total=>cart.values.fold(0,(sum,item)=>sum+lineTotal(item));

  void add(Map<String,Object?> product) {
    final id=product['id'] as int;
    setState((){
      if(cart.containsKey(id)){cart[id]!['qty']=(cart[id]!['qty'] as int)+1;}
      else{cart[id]={...product,'qty':1,'unit':product['unit']??'حبة'};}
      search.clear();showSuggestions=false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> scan({bool addUnknownAsSearch=true}) async {
    final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const BarcodeScreen()));
    if(code==null||!mounted)return;
    final db=await LocalDatabase.instance.database;
    final found=await db.query('products',where:'barcode=? AND is_active=1',whereArgs:[code],limit:1);
    if(!mounted)return;
    if(found.isNotEmpty){add(found.first);}
    else{search.text=code;setState(()=>showSuggestions=true);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الباركود غير مسجل. يمكنك إضافته كمنتج جديد.')));}
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
    String unit=units.first;
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setDialog)=>AlertDialog(
      title:const Text('إضافة منتج جديد للفاتورة'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الصنف')),
        TextField(controller:barcode,decoration:InputDecoration(labelText:'الباركود',suffixIcon:IconButton(tooltip:'مسح الباركود',icon:const Icon(Icons.qr_code_scanner),onPressed:()async{final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const BarcodeScreen()));if(code!=null)barcode.text=code;}))),
        DropdownButtonFormField<String>(value:unit,decoration:const InputDecoration(labelText:'الوحدة'),items:units.map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:(v){if(v!=null)setDialog(()=>unit=v);}),
        TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'سعر الوحدة (ر.س)')),
        TextField(controller:quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية بالمخزون (اختياري)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ وإضافة للفاتورة'))])));
    if(ok==true){
      try{
        if(name.text.trim().isEmpty)throw Exception('أدخل اسم الصنف');
        final db=await LocalDatabase.instance.database;
        final id=await db.insert('products',{'name':name.text.trim(),'barcode':barcode.text.trim().isEmpty?null:barcode.text.trim(),'unit':unit,'sale_price_halalas':Money.parseHalalas(price.text),'quantity':quantity.text.trim().isEmpty?null:double.parse(quantity.text),'created_at':DateTime.now().toIso8601String(),'is_active':1});
        final rows=await db.query('products',where:'id=?',whereArgs:[id],limit:1);
        if(rows.isNotEmpty&&mounted){add(rows.first);}
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذرت إضافة المنتج: $e')));}
    }
    name.dispose();barcode.dispose();price.dispose();quantity.dispose();
  }

  Future<void> reviewInvoice() async {
    if(cart.isEmpty)return;
    final confirmed=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('مراجعة الفاتورة كاملة'),
      content:SizedBox(width:double.maxFinite,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ...cart.values.map((item)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(item['name'] as String),subtitle:Text('الكمية: ${item['qty']} ${item['unit']} • سعر الوحدة: ${Money.format(item['sale_price_halalas'] as int)}'),trailing:Text(Money.format(lineTotal(item)),style:const TextStyle(fontWeight:FontWeight.bold)))),
        const Divider(),
        ListTile(title:const Text('الإجمالي النهائي',style:TextStyle(fontWeight:FontWeight.bold)),trailing:Text(Money.format(total),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
        Text(payment=='cash'?'طريقة الدفع: نقد':'طريقة الدفع: شبكة'),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('رجوع للتعديل')),FilledButton.icon(onPressed:()=>Navigator.pop(d,true),icon:const Icon(Icons.check),label:const Text('تأكيد وحفظ'))]));
    if(confirmed==true)await save();
  }

  Future<void> save() async {
    if(cart.isEmpty||saving)return;
    setState(()=>saving=true);
    try{
      await LocalDatabase.instance.createInvoice(items:cart.values.map((item)=><String,Object?>{'product_id':item['id'],'product_name':item['name'],'quantity':item['qty'],'unit':item['unit']??'حبة','unit_price_halalas':item['sale_price_halalas']}).toList(),paymentMethod:payment,stockEnabled:await LocalDatabase.instance.stockEnabled());
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ الفاتورة وتسجيل الحركة المالية')));Navigator.pop(context);}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الفاتورة: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('تسجيل البيع'),actions:[IconButton(tooltip:'مسح الباركود',onPressed:scan,icon:const Icon(Icons.qr_code_scanner))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,12,6),child:TextField(controller:search,onChanged:(v)=>setState(()=>showSuggestions=v.trim().isNotEmpty),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'ابحث باسم المنتج أو اكتب الباركود',suffixIcon:IconButton(tooltip:'تصوير الباركود',onPressed:scan,icon:const Icon(Icons.camera_alt_outlined))))),
      if(showSuggestions&&search.text.trim().isNotEmpty)
        SizedBox(height:150,child:FutureBuilder<List<Map<String,Object?>>>(future:products(),builder:(context,snapshot){
          if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
          final matches=snapshot.data!;
          if(matches.isEmpty)return Padding(padding:const EdgeInsets.all(12),child:Column(children:[const Text('لا توجد نتائج مطابقة'),TextButton.icon(onPressed:addNewProduct,icon:const Icon(Icons.add),label:const Text('إضافة هذا المنتج جديدًا'))]));
          return ListView.builder(itemCount:matches.length,itemBuilder:(context,index){final p=matches[index];return ListTile(dense:true,title:Text(p['name'] as String),subtitle:Text('الباركود: ${p['barcode']??'—'} • ${p['unit']??'حبة'} • سعر الوحدة: ${Money.format(p['sale_price_halalas'] as int)}'),trailing:const Icon(Icons.add_circle,color:Colors.teal),onTap:()=>add(p));});
        })),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:OutlinedButton.icon(onPressed:addNewProduct,icon:const Icon(Icons.add),label:const Text('إضافة منتج جديد'))),
      const Divider(),
      Expanded(child:cart.isEmpty?const Center(child:Text('امسح باركود أو ابحث عن منتج لإضافته للفاتورة')):ListView(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),children:cart.entries.map((entry){
        final item=entry.value;final qty=item['qty'] as int;final price=item['sale_price_halalas'] as int;final unit=item['unit'] as String? ?? 'حبة';
        return Card(elevation:2,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(item['name'] as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:_fieldLabel('الكمية',Text('$qty',textAlign:TextAlign.center))),
            const SizedBox(width:8),
            Expanded(child:_fieldLabel('الوحدة',DropdownButtonHideUnderline(child:DropdownButton<String>(isExpanded:true,value:units.contains(unit)?unit:units.first,items:units.map((u)=>DropdownMenuItem(value:u,child:Text(u,style:const TextStyle(fontSize:13)))).toList(),onChanged:(v){if(v!=null)setState(()=>item['unit']=v);}))),
            const SizedBox(width:8),
            Expanded(child:_fieldLabel('السعر',Text(Money.format(price),textAlign:TextAlign.center,style:const TextStyle(fontSize:12)))),
          ]),
          const SizedBox(height:6),
          if(item['quantity']!=null)Align(alignment:Alignment.centerRight,child:Text('المتاح بالمخزون: ${item['quantity']} $unit',style:TextStyle(color:Colors.teal.shade700,fontSize:12))),
          Row(children:[
            IconButton(tooltip:'زيادة الكمية',onPressed:()=>setState(()=>item['qty']=qty+1),icon:const Icon(Icons.add_circle_outline)),
            IconButton(tooltip:'تقليل الكمية',onPressed:()=>setState(()=>item['qty']=qty>1?qty-1:1),icon:const Icon(Icons.remove_circle_outline)),
            TextButton(onPressed:()=>editPrice(entry.key),child:const Text('تعديل السعر')),
            const Spacer(),
            Text('الإجمالي: ${Money.format(qty*price)}',style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.teal)),
            IconButton(onPressed:()=>setState(()=>cart.remove(entry.key)),icon:const Icon(Icons.delete_outline,color:Colors.red)),
          ])
        ])));
      }).toList())),
      Container(color:Colors.teal.shade900,padding:const EdgeInsets.fromLTRB(16,12,16,10),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('الإجمالي النهائي',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.bold)),Text(Money.format(total),style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.bold))])),
      SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        SegmentedButton<String>(segments:const [ButtonSegment(value:'cash',label:Text('نقد'),icon:Icon(Icons.payments)),ButtonSegment(value:'network',label:Text('شبكة'),icon:Icon(Icons.credit_card))],selected:{payment},onSelectionChanged:(v)=>setState(()=>payment=v.first)),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving||cart.isEmpty?null:reviewInvoice,icon:const Icon(Icons.fact_check_outlined),label:Text(saving?'جار الحفظ':'مراجعة كاملة ثم حفظ الفاتورة'))),
      ]))),
    ])
  );

  Widget _fieldLabel(String label,Widget child)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(label,style:TextStyle(fontSize:12,color:Colors.grey.shade700)),Container(height:44,alignment:Alignment.center,padding:const EdgeInsets.symmetric(horizontal:6),decoration:BoxDecoration(border:Border.all(color:Colors.teal.shade100),borderRadius:BorderRadius.circular(12)),child:child)]);
}
