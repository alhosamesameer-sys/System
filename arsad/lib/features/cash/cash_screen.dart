import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override State<CashScreen> createState() => _CashScreenState();
}
class _CashScreenState extends State<CashScreen> {
  Future<void> addMovement(String table,String type) async {
    final amount=TextEditingController();
    final note=TextEditingController();
    final title=switch(type){'opening'=>'الرصيد الافتتاحي','deposit'=>'إيداع','withdrawal'=>'سحب نقدي','expense'=>'مصروف','bank_fee'=>'رسوم بنكية',_=>'حركة حساب'};
    final ok=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:Text(title),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ بالريال')),
        TextField(controller:note,decoration:const InputDecoration(labelText:'البيان')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('حفظ'))],
    ));
    if(ok!=true||!mounted)return;
    try {
      final halalas=Money.parseHalalas(amount.text);
      await LocalDatabase.instance.createAccountMovement(table:table,type:type,amountHalalas:halalas,note:note.text);
      if(mounted)setState((){});
    } catch(e) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'))); }
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('الصندوق وحساب الشبكة')),
    body:FutureBuilder<List<int>>(future:Future.wait([LocalDatabase.instance.balance('cash_transactions'),LocalDatabase.instance.balance('network_transactions')]),builder:(context,snapshot){
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      return ListView(padding:const EdgeInsets.all(16),children:[
        _account('الصندوق النقدي',snapshot.data![0],'cash_transactions',false),
        _account('حساب الشبكة',snapshot.data![1],'network_transactions',true),
      ]);
    }),
  );

  Widget _account(String title,int amount,String table,bool network)=>Card(
    child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
      Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      Text(Money.format(amount),style:TextStyle(fontSize:26,fontWeight:FontWeight.bold,color:amount<0?Colors.red:Colors.green)),
      Wrap(alignment:WrapAlignment.center,spacing:8,children:[
        OutlinedButton(onPressed:()=>addMovement(table,'opening'),child:const Text('رصيد افتتاحي')),
        OutlinedButton(onPressed:()=>addMovement(table,'deposit'),child:const Text('إيداع')),
        OutlinedButton(onPressed:()=>addMovement(table,'withdrawal'),child:const Text('سحب')),
        OutlinedButton(onPressed:()=>addMovement(table,'expense'),child:const Text('مصروف')),
        if(network)OutlinedButton(onPressed:()=>addMovement(table,'bank_fee'),child:const Text('رسوم بنكية')),
      ]),
      const Divider(),
      const Align(alignment:Alignment.centerRight,child:Text('آخر الحركات',style:TextStyle(fontWeight:FontWeight.bold))),
      FutureBuilder<List<Map<String,Object?>>>(future:LocalDatabase.instance.database.then((db)=>db.query(table,orderBy:'id DESC',limit:30)),builder:(context,snapshot){
        if(!snapshot.hasData)return const Padding(padding:EdgeInsets.all(12),child:LinearProgressIndicator());
        if(snapshot.data!.isEmpty)return const Padding(padding:EdgeInsets.all(12),child:Text('لا توجد حركات مسجلة'));
        return Column(children:snapshot.data!.map((row){
          final type=row['type'] as String;
          final positive={'opening','sale','deposit','adjustment_in'}.contains(type);
          final label=switch(type){'opening'=>'رصيد افتتاحي','sale'=>'مبيعات','deposit'=>'إيداع','withdrawal'=>'سحب','expense'=>'مصروف','bank_fee'=>'رسوم بنكية','return'=>'مردود','adjustment_in'=>'تسوية إضافة','adjustment_out'=>'تسوية خصم',_=>type};
          final amount=(row['amount_halalas'] as num).toInt();
          return ListTile(dense:true,leading:Icon(positive?Icons.arrow_downward:Icons.arrow_upward,color:positive?Colors.green:Colors.red),title:Text(label),subtitle:Text('${row['created_at']}${(row['note'] as String? ?? '').isEmpty?'':' • ${row['note']}'}'),trailing:Text('${positive?'+':'−'}${Money.format(amount)}',style:TextStyle(color:positive?Colors.green:Colors.red,fontWeight:FontWeight.bold)));
        }).toList());
      }),
    ])),
  );
}
