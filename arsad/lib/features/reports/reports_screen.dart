import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState()=>_ReportsScreenState();
}
class _ReportsScreenState extends State<ReportsScreen> {
  String period='يومي';
  DateTimeRange? customRange;
  DateTimeRange get dates {
    final now=DateTime.now();
    if(customRange!=null)return DateTimeRange(start:customRange!.start,end:DateTime(customRange!.end.year,customRange!.end.month,customRange!.end.day+1));
    if(period=='شهري')return DateTimeRange(start:DateTime(now.year,now.month,1),end:DateTime(now.year,now.month+1,1));
    if(period=='سنوي')return DateTimeRange(start:DateTime(now.year),end:DateTime(now.year+1));
    if(period=='أسبوعي')return DateTimeRange(start:DateTime(now.year,now.month,now.day-(now.weekday-1)),end:DateTime(now.year,now.month,now.day-(now.weekday-1)+7));
    return DateTimeRange(start:DateTime(now.year,now.month,now.day),end:DateTime(now.year,now.month,now.day+1));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('التقارير')),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:6,children:[
        for(final value in ['يومي','أسبوعي','شهري','سنوي'])
          ChoiceChip(label:Text(value),selected:period==value&&customRange==null,onSelected:(_){setState((){period=value;customRange=null;});}),
      ])),
      TextButton.icon(onPressed:()async{
        final now=DateTime.now();
        final picked=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(now.year+2),initialDateRange:dates);
        if(picked!=null&&mounted)setState(()=>customRange=picked);
      },icon:const Icon(Icons.date_range),label:const Text('تحديد فترة مخصصة')),
      Expanded(child:FutureBuilder<Map<String,Object?>>(future:LocalDatabase.instance.dashboardTotals(dates.start,dates.end),builder:(context,snapshot){
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        final d=snapshot.data!;
        return ListView(padding:const EdgeInsets.all(16),children:[
          _row('إجمالي المبيعات',d['sales_total']),
          _row('المبيعات النقدية',d['cash_total']),
          _row('مبيعات الشبكة',d['network_total']),
          _row('إجمالي المردودات',d['returns_total']),
          _row('صافي المبيعات',d['net_sales_total']),
          _row('عدد الفواتير',d['invoice_count'],count:true),
          _row('المصروفات',d['expenses_total']),
          _row('صافي حركة الصندوق',d['cash_net']),
          _row('صافي حركة الشبكة',d['network_net']),
        ]);
      })),
    ]),
  );
  Widget _row(String title,Object? value,{bool count=false})=>Card(child:ListTile(title:Text(title),trailing:Text(count?'$value':Money.format((value as num).toInt()),style:const TextStyle(fontWeight:FontWeight.bold))));
}
