import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/statement_exporter.dart';
import '../../data/local_database.dart';
class ReportsScreen extends StatefulWidget {const ReportsScreen({super.key});@override State<ReportsScreen> createState()=>_ReportsScreenState();}
class _ReportsScreenState extends State<ReportsScreen>{
 String period='يومي';DateTimeRange? custom;
 DateTimeRange get range{final n=DateTime.now();if(custom!=null)return DateTimeRange(start:custom!.start,end:DateTime(custom!.end.year,custom!.end.month,custom!.end.day+1));if(period=='شهري')return DateTimeRange(start:DateTime(n.year,n.month,1),end:DateTime(n.year,n.month+1,1));if(period=='سنوي')return DateTimeRange(start:DateTime(n.year),end:DateTime(n.year+1));if(period=='أسبوعي')return DateTimeRange(start:DateTime(n.year,n.month,n.day-n.weekday+1),end:DateTime(n.year,n.month,n.day-n.weekday+8));return DateTimeRange(start:DateTime(n.year,n.month,n.day),end:DateTime(n.year,n.month,n.day+1));}
 Future<List<Map<String,Object?>>> detail(String kind)async{final db=await LocalDatabase.instance.database;final a=[range.start.toIso8601String(),range.end.toIso8601String()];
 if(kind=='sales'||kind=='cash'||kind=='network'){final filter=kind=='cash'?"AND payment_method='cash'":kind=='network'?"AND payment_method='network'":'';return db.rawQuery("SELECT invoice_no ref,created_at date,payment_method detail,total_halalas amount FROM invoices WHERE created_at>=? AND created_at<? $filter ORDER BY created_at DESC",a);}
 if(kind=='returns')return db.rawQuery('SELECT invoices.invoice_no ref,returns.created_at date,returns.reason detail,returns.total_halalas amount FROM returns JOIN invoices ON invoices.id=returns.invoice_id WHERE returns.created_at>=? AND returns.created_at<? ORDER BY returns.created_at DESC',a);
 if(kind=='net')return db.rawQuery("SELECT invoice_no ref,created_at date,'مبيعات' detail,total_halalas amount FROM invoices WHERE created_at>=? AND created_at<? UNION ALL SELECT CAST(id AS TEXT),created_at,'مرتجع',-total_halalas FROM returns WHERE created_at>=? AND created_at<? ORDER BY date DESC",[...a,...a]);
 if(kind=='expenses')return db.rawQuery('SELECT id ref,created_at date,title detail,amount_halalas amount FROM expenses WHERE created_at>=? AND created_at<? ORDER BY created_at DESC',a);
 final table=kind=='cashflow'?'cash_transactions':'network_transactions';return db.rawQuery('SELECT id ref,created_at date,COALESCE(note,type) detail,amount_halalas amount,type FROM '+table+' WHERE created_at>=? AND created_at<? ORDER BY created_at DESC',a);
 }
 Future<void> openStatement(String title,String kind)async{final rows=await detail(kind);if(!mounted)return;if(rows.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد تفاصيل في هذه الفترة')));return;}
 final data=rows.map((r){final amount=(r['amount'] as num).toInt();return [r['date'].toString(),r['ref'].toString(),r['detail']?.toString()??'',amount<0?'-${Money.format(-amount)}':Money.format(amount)];}).toList();
 await showDialog<void>(context:context,builder:(d)=>AlertDialog(title:Text('كشف $title'),content:SizedBox(width:double.maxFinite,height:420,child:Column(children:[Text('عدد السجلات: ${rows.length}'),const Divider(),Expanded(child:ListView.builder(itemCount:rows.length,itemBuilder:(c,i)=>ListTile(dense:true,title:Text(rows[i]['detail']?.toString()??''),subtitle:Text(rows[i]['date'].toString()),trailing:Text(Money.format((rows[i]['amount'] as num).toInt())))))])),actions:[
 TextButton(onPressed:()=>Navigator.pop(d),child:const Text('إغلاق')),
 OutlinedButton(onPressed:()async{Navigator.pop(d);await StatementExporter.export(title:'كشف $title',headers:['التاريخ','المرجع','البيان','المبلغ'],rows:data,asPdf:true);},child:const Text('PDF')),
 FilledButton(onPressed:()async{Navigator.pop(d);await StatementExporter.export(title:'كشف '+title,headers:['التاريخ','المرجع','البيان','المبلغ'],rows:data,asPdf:false);},child:const Text('Excel'))]));}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('التقارير والتحليلات')),body:Column(children:[
 Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:6,children:[for(final v in ['يومي','أسبوعي','شهري','سنوي'])ChoiceChip(label:Text(v),selected:period==v&&custom==null,onSelected:(_)=>setState((){period=v;custom=null;}))])),
 TextButton.icon(onPressed:()async{final n=DateTime.now();final x=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(n.year+2),initialDateRange:range);if(x!=null&&mounted)setState(()=>custom=x);},icon:const Icon(Icons.date_range),label:const Text('فترة مخصصة')),
 Expanded(child:FutureBuilder<Map<String,Object?>>(future:LocalDatabase.instance.dashboardTotals(range.start,range.end),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final d=s.data!;return ListView(padding:const EdgeInsets.all(14),children:[
 const Text('ملخص الأداء',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
 _metric('إجمالي المبيعات',d['sales_total'],Icons.point_of_sale,Colors.blue,'sales'),
 _metric('المبيعات النقدية',d['cash_total'],Icons.payments,Colors.green,'cash'),
 _metric('مبيعات الشبكة',d['network_total'],Icons.credit_card,Colors.teal,'network'),
 _metric('إجمالي المرتجعات',d['returns_total'],Icons.assignment_return,Colors.red,'returns'),
 _metric('صافي المبيعات',d['net_sales_total'],Icons.trending_up,Colors.indigo,'net'),
 _metric('المصروفات',d['expenses_total'],Icons.money_off,Colors.orange,'expenses'),
 _metric('حركة الصندوق',d['cash_net'],Icons.account_balance_wallet,Colors.blueGrey,'cashflow'),
 _metric('حركة الشبكة والبنك',d['network_net'],Icons.account_balance,Colors.teal,'networkflow'),
 Card(child:ListTile(title:const Text('عدد الفواتير'),trailing:Text(d['invoice_count'].toString(),style:const TextStyle(fontWeight:FontWeight.bold)))),
 ];})),
 ]));
 Widget _metric(String title,Object? value,IconData icon,Color color,String kind)=>Card(elevation:0,child:InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>openStatement(title,kind),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[CircleAvatar(backgroundColor:color.withValues(alpha:.1),child:Icon(icon,color:color)),const SizedBox(width:12),Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.w600))),Text(Money.format((value as num).toInt()),style:TextStyle(fontWeight:FontWeight.bold,color:color)),const Icon(Icons.chevron_left)]))));
}