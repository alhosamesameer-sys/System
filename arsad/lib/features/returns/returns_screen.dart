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
  bool reviewed=false;

  Future<List<Map<String,Object?>>> loadInvoices() async {
    final db=await LocalDatabase.instance.database;
    final q=invoiceNo.text.trim();
    if(q.isEmpty) {
      return db.query('invoices',orderBy:'id DESC');
    }
    return db.rawQuery(
      'SELECT DISTINCT invoices.* FROM invoices LEFT JOIN invoice_items ON invoice_items.invoice_id=invoices.id WHERE invoices.invoice_no LIKE ? OR invoice_items.product_name LIKE ? ORDER BY invoices.id DESC',
      ['%$q%','%$q%'],
    );
  }

  double get selectedQuantity => qty.values.fold<double>(0,(sum,c)=>sum+(double.tryParse(c.text)??0));
  int get selectedTotal {
    var total=0;
    for(final item in items) {
      final id=item['id'] as int;
      final count=double.tryParse(qty[id]?.text??'0')??0;
      final price=item['unit_price_halalas'] as int;
      total+=(count*price).round();
    }
    return total;
  }

  void _disposeQty() {
    for(final controller in qty.values){controller.dispose();}
    qty.clear();
  }

  Future<void> selectInvoice(Map<String,Object?> selected) async {
    setState(()=>loading=true);
    try {
      final db=await LocalDatabase.instance.database;
      final found=await db.query('invoices',where:'id=?',whereArgs:[selected['id']],limit:1);
      if(found.isEmpty)throw Exception('لم يتم العثور على الفاتورة');
      final lines=await db.query('invoice_items',where:'invoice_id=?',whereArgs:[selected['id']]);
      _disposeQty();
      if(!mounted)return;
      setState((){
        invoice=found.first;items=lines;reviewed=false;
        for(final item in lines){qty[item['id'] as int]=TextEditingController(text:'0')..addListener(_refresh);}
      });
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  void _refresh(){if(mounted)setState(()=>reviewed=false);}

  void selectAllRemaining() {
    setState((){
      for(final item in items) {
        final remaining=(item['quantity'] as num).toDouble()-(item['returned_quantity'] as num).toDouble();
        qty[item['id'] as int]?.text=remaining.toString();
      }
      reviewed=false;
    });
  }

  Future<void> reviewReturn() async {
    if(invoice==null||selectedQuantity<=0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('حدد كمية واحدة على الأقل للمراجعة')));
      return;
    }
    for(final item in items) {
      final id=item['id'] as int;
      final entered=double.tryParse(qty[id]?.text??'0')??0;
      final remaining=(item['quantity'] as num).toDouble()-(item['returned_quantity'] as num).toDouble();
      if(entered<0||entered>remaining) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('الكمية المحددة للصنف ${item['product_name']} غير صحيحة')));
        return;
      }
    }
    final ok=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:const Text('مراجعة المرتجع بالكامل'),
      content:SizedBox(width:double.maxFinite,child:Column(mainAxisSize:MainAxisSize.min,children:[
        Align(alignment:Alignment.centerRight,child:Text('الفاتورة ${invoice!['invoice_no']}',style:const TextStyle(fontWeight:FontWeight.bold))),
        const SizedBox(height:10),
        Flexible(child:SingleChildScrollView(child:Column(children:[
          ...items.where((x)=>(double.tryParse(qty[x['id'] as int]?.text??'0')??0)>0).map((x){
            final q=double.tryParse(qty[x['id'] as int]!.text)??0;
            final price=x['unit_price_halalas'] as int;
            return ListTile(contentPadding:EdgeInsets.zero,title:Text(x['product_name'] as String),subtitle:Text('الكمية المرتجعة: $q • سعر القطعة: ${Money.format(price)}'),trailing:Text(Money.format((q*price).round()),style:const TextStyle(fontWeight:FontWeight.bold)));
          })
        ]))),
        const Divider(),
        ListTile(title:const Text('إجمالي قيمة المرتجع',style:TextStyle(fontWeight:FontWeight.bold)),trailing:Text(Money.format(selectedTotal),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('رجوع للتعديل')),
        FilledButton.icon(onPressed:()=>Navigator.pop(dialog,true),icon:const Icon(Icons.check),label:const Text('تأكيد المرتجع')),
      ],
    ));
    if(ok==true) await save();
  }

  Future<void> save() async {
    if(invoice==null||saving)return;
    setState(()=>saving=true);
    try{
      final selected=<int,double>{};
      for(final entry in qty.entries){final value=double.tryParse(entry.value.text)??0;if(value>0)selected[entry.key]=value;}
      await LocalDatabase.instance.createReturn(invoiceId:invoice!['id'] as int,quantities:selected,reason:reason.text);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل المرتجع وتحديث الحساب')));setState(()=>invoice=null);_disposeQty();}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل المرتجع: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  @override void dispose(){invoiceNo.dispose();reason.dispose();_disposeQty();super.dispose();}

  @override Widget build(BuildContext context) {
    final theme=Theme.of(context);
    return Scaffold(
      appBar:AppBar(title:const Text('إدارة المرتجعات')),
      body:Column(children:[
        if(invoice==null) Padding(padding:const EdgeInsets.fromLTRB(16,14,16,8),child:TextField(
          controller:invoiceNo,onChanged:(_)=>setState((){}),
          decoration:InputDecoration(
            hintText:'ابحث برقم الفاتورة أو اسم الصنف',
            prefixIcon:const Icon(Icons.search),
            suffixIcon:invoiceNo.text.isEmpty?null:IconButton(onPressed:()=>setState(invoiceNo.clear),icon:const Icon(Icons.close)),
            filled:true,fillColor:theme.colorScheme.surface,
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)),
          ),
        )),
        if(invoice==null) Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:loadInvoices(),builder:(context,snapshot){
          if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
          if(!snapshot.hasData)return const Center(child:Text('تعذر تحميل الفواتير'));
          final invoices=snapshot.data!;
          if(invoices.isEmpty)return const Center(child:Text('لا توجد فواتير مطابقة'));
          return ListView.separated(
            padding:const EdgeInsets.fromLTRB(12,4,12,16),
            itemCount:invoices.length,
            separatorBuilder:(_,__)=>const SizedBox(height:6),
            itemBuilder:(context,index){
              final row=invoices[index];
              final returned=row['status']=='fully_returned';
              return Card(
                elevation:0,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:BorderSide(color:theme.dividerColor)),
                child:ListTile(
                  contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
                  leading:CircleAvatar(backgroundColor:theme.colorScheme.primaryContainer,child:Icon(Icons.receipt_long,color:theme.colorScheme.primary)),
                  title:Text('فاتورة ${row['invoice_no']}',style:const TextStyle(fontWeight:FontWeight.bold)),
                  subtitle:Text('${row['created_at']} • ${row['payment_method']=='cash'?'نقد':'شبكة'} • ${returned?'مرتجعة بالكامل':'متاحة للمردود'}'),
                  trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
                    Text(Money.format(row['total_halalas'] as int),style:const TextStyle(fontWeight:FontWeight.bold)),
                    const SizedBox(height:3),
                    Text(returned?'مكتملة':'اختيار',style:TextStyle(fontSize:11,color:returned?theme.colorScheme.error:theme.colorScheme.primary)),
                  ]),
                  onTap:returned?null:()=>selectInvoice(row),
                ),
              );
            },
          );
        })),
        if(invoice!=null) Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
          Row(children:[
            Expanded(child:Text('فاتورة ${invoice!['invoice_no']}',style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),
            TextButton.icon(onPressed:()=>setState(()=>invoice=null),icon:const Icon(Icons.arrow_back),label:const Text('الفواتير')),
          ]),
          Card(elevation:0,color:theme.colorScheme.primaryContainer,child:Padding(padding:const EdgeInsets.all(14),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            const Text('إجمالي الفاتورة'),
            Text(Money.format(invoice!['total_halalas'] as int),style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
          ]))),
          const SizedBox(height:10),
          Row(children:[
            const Expanded(child:Text('أصناف الفاتورة',style:TextStyle(fontWeight:FontWeight.bold))),
            TextButton.icon(onPressed:selectAllRemaining,icon:const Icon(Icons.done_all),label:const Text('تحديد المرتجع كامل')),
          ]),
          ...items.map((item){
            final id=item['id'] as int;
            final remaining=(item['quantity'] as num).toDouble()-(item['returned_quantity'] as num).toDouble();
            final price=item['unit_price_halalas'] as int;
            return Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14),side:BorderSide(color:theme.dividerColor)),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(item['product_name'] as String,style:const TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:4),
              Text('سعر القطعة: ${Money.format(price)} • الكمية المتبقية للإرجاع: $remaining',style:theme.textTheme.bodySmall),
              const SizedBox(height:8),
              TextField(controller:qty[id],enabled:remaining>0,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'الكمية المراد إرجاعها',isDense:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))),),
            ])));
          }),
          TextField(controller:reason,decoration:const InputDecoration(labelText:'سبب الإرجاع')),
          const SizedBox(height:12),
          Card(color:theme.colorScheme.secondaryContainer,child:ListTile(title:const Text('إجمالي المرتجع المحدد'),trailing:Text(Money.format(selectedTotal),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)))),
          const SizedBox(height:8),
          FilledButton.icon(onPressed:saving?null:reviewReturn,icon:const Icon(Icons.fact_check_outlined),label:Text(saving?'جارٍ التسجيل...':'مراجعة المرتجع بالكامل')),
        ])),
      ]),
    );
  }
}
