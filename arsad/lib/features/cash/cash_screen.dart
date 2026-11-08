import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/statement_exporter.dart';
import '../../data/local_database.dart';
class CashScreen extends StatefulWidget { const CashScreen({super.key}); @override State<CashScreen> createState()=>_CashScreenState(); }
class _CashScreenState extends State<CashScreen> with SingleTickerProviderStateMixin {
 late final TabController tabs=TabController(length:2,vsync:this);
 static const tables=['cash_transactions','network_transactions']; static const labels=['الصندوق','الشبكة والبنك'];
 Future<List<Map<String,Object?>>> movements(int i) async {final db=await LocalDatabase.instance.database;return db.query(tables[i],orderBy:'id DESC');}
 Future<void> addMovement(String table,String type) async {
  final amount=TextEditingController(),note=TextEditingController();
  final title=switch(type){'opening'=>'الرصيد الافتتاحي','deposit'=>'إضافة رصيد','withdrawal'=>'سحب رصيد','expense'=>'مصروف','bank_fee'=>'رسوم بنكية',_=>'حركة حساب'};
  final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(title),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ بالريال')),TextField(controller:note,decoration:const InputDecoration(labelText:'البيان'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ'))]));
  if(ok!=true||!mounted){amount.dispose();note.dispose();return;}
  try{await LocalDatabase.instance.createAccountMovement(table:table,type:type,amountHalalas:Money.parseHalalas(amount.text),note:note.text);if(mounted)setState((){});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));} amount.dispose();note.dispose();
 }
 Future<void> export(int i,List<Map<String,Object?>> rows,bool pdf) async {
  final data=rows.map((r){final t=r['type'] as String;final pos={'opening','sale','deposit','adjustment_in'}.contains(t);final label=switch(t){'opening'=>'رصيد افتتاحي','sale'=>'مبيعات','deposit'=>'إيداع','withdrawal'=>'سحب','expense'=>'مصروف','bank_fee'=>'رسوم بنكية','return'=>'مردود','adjustment_in'=>'تسوية إضافة','adjustment_out'=>'تسوية خصم',_=>t};final a=(r['amount_halalas'] as num).toInt();return [r['created_at'].toString(),label,(r['note']??'').toString(),'${pos?'+':'-'}${Money.format(a)}'];}).toList();
  await StatementExporter.export(title:'كشف حساب ${labels[i]}',headers:['التاريخ والوقت','نوع الحركة','البيان','المبلغ'],rows:data,asPdf:pdf);
 }
 @override void dispose(){tabs.dispose();super.dispose();}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('الحسابات المالية'),bottom:TabBar(controller:tabs,tabs:const [Tab(text:'الصندوق',icon:Icon(Icons.payments_outlined)),Tab(text:'الشبكة والبنك',icon:Icon(Icons.account_balance_outlined))])),body:TabBarView(controller:tabs,children:[_account(0),_account(1)]));
 Widget _account(int i){
  final table=tables[i],network=i==1,theme=Theme.of(context);
  return FutureBuilder<List<Map<String,Object?>>>(future:movements(i),builder:(c,s){
   if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const Center(child:Text('تعذر تحميل الحركات'));
   final rows=s.data??[];var balance=0;for(final r in rows.reversed){final a=(r['amount_halalas'] as num).toInt();balance+=({'opening','sale','deposit','adjustment_in'}.contains(r['type'])?a:-a);}
   return ListView(padding:const EdgeInsets.all(16),children:[
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:LinearGradient(colors:network?[const Color(0xFF0B477B),const Color(0xFF087E8B)]:[const Color(0xFF073B78),const Color(0xFF1266B5)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(network?'رصيد الشبكة والبنك الحالي':'رصيد الصندوق الحالي',style:const TextStyle(color:Colors.white70)),const SizedBox(height:8),Text(Money.format(balance),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.bold)),const SizedBox(height:16),
     Wrap(spacing:8,runSpacing:8,children:[_action('رصيد افتتاحي',Icons.account_balance_wallet_outlined,()=>addMovement(table,'opening')),_action('إضافة رصيد',Icons.add_circle_outline,()=>addMovement(table,'deposit')),_action('سحب رصيد',Icons.remove_circle_outline,()=>addMovement(table,'withdrawal')),_action('مصروف',Icons.receipt_long,()=>addMovement(table,'expense')),if(network)_action('رسوم بنكية',Icons.account_balance,()=>addMovement(table,'bank_fee'))])
    ]),
    const SizedBox(height:16),Row(children:[const Expanded(child:Text('كشف الحساب',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),Text('${rows.length} حركة',style:theme.textTheme.bodySmall)]),const SizedBox(height:8),
    Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>export(i,rows,true),icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('تصدير PDF'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>export(i,rows,false),icon:const Icon(Icons.table_view_outlined),label:const Text('تصدير Excel')))]),
    const SizedBox(height:12),const Text('جميع العمليات',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    if(rows.isEmpty)const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('لا توجد عمليات مسجلة بعد'))),
    ...rows.map((r){final t=r['type'] as String;final pos={'opening','sale','deposit','adjustment_in'}.contains(t);final a=(r['amount_halalas'] as num).toInt();final label=switch(t){'opening'=>'رصيد افتتاحي','sale'=>'مبيعات','deposit'=>'إضافة رصيد','withdrawal'=>'سحب','expense'=>'مصروف','bank_fee'=>'رسوم بنكية','return'=>'مردود','adjustment_in'=>'تسوية إضافة','adjustment_out'=>'تسوية خصم',_=>t};return Card(elevation:0,child:ListTile(leading:CircleAvatar(backgroundColor:(pos?Colors.green:Colors.red).withValues(alpha:.1),child:Icon(pos?Icons.south_west:Icons.north_east,color:pos?Colors.green:Colors.red)),title:Text(label,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text('${r['created_at']}\n${r['note']??''}'),isThreeLine:(r['note']??'').toString().isNotEmpty,trailing:Text('${pos?'+':'−'}${Money.format(a)}',style:TextStyle(fontWeight:FontWeight.bold,color:pos?Colors.green:Colors.red))));})
   ]);
  });
 }
 Widget _action(String label,IconData icon,VoidCallback tap)=>ActionChip(avatar:Icon(icon,size:18,color:Colors.white),label:Text(label,style:const TextStyle(color:Colors.white)),backgroundColor:Colors.white24,side:BorderSide.none,onPressed:tap);
}