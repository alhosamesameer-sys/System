import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import '../auth/login_screen.dart';
import '../products/products_screen.dart';
import '../sales/sales_screen.dart';
import '../cash/cash_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../invoices/invoices_screen.dart';
import '../returns/returns_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState()=>_DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String,Object?>> load() async {
    final now=DateTime.now();
    final totals=await LocalDatabase.instance.dashboardTotals(DateTime(now.year,now.month,now.day),DateTime(now.year,now.month,now.day+1));
    return {...totals,'cash_balance':await LocalDatabase.instance.balance('cash_transactions'),'network_balance':await LocalDatabase.instance.balance('network_transactions')};
  }
  void open(Widget page){Navigator.push(context,MaterialPageRoute(builder:(_)=>page)).then((_){if(mounted)setState((){});});}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('أرصد | ARSAD'),actions:[
      IconButton(onPressed:()=>open(const SettingsScreen()),icon:const Icon(Icons.settings)),
      IconButton(tooltip:'تسجيل الخروج',onPressed:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const LoginScreen())),icon:const Icon(Icons.logout)),
    ]),
    body:FutureBuilder<Map<String,Object?>>(future:load(),builder:(context,snapshot){
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final d=snapshot.data!;
      final tiles=<({String title,IconData icon,Widget page})>[
        (title:'مبيعات جديدة',icon:Icons.point_of_sale,page:const SalesScreen()),
        (title:'الأصناف',icon:Icons.inventory_2,page:const ProductsScreen()),
        (title:'الفواتير',icon:Icons.receipt_long,page:const InvoicesScreen()),
        (title:'المردودات',icon:Icons.assignment_return,page:const ReturnsScreen()),
        (title:'الصندوق والشبكة',icon:Icons.account_balance_wallet,page:const CashScreen()),
        (title:'التقارير',icon:Icons.bar_chart,page:const ReportsScreen()),
        (title:'الإعدادات',icon:Icons.settings,page:const SettingsScreen()),
      ];
      return RefreshIndicator(onRefresh:()async{setState((){});await load();},child:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('مرحباً بك في أرصد',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:1.7,crossAxisSpacing:8,mainAxisSpacing:8,children:[
          _metric('مبيعات اليوم',Money.format((d['sales_total'] as num).toInt()),Icons.trending_up,Colors.green),
          _metric('عدد الفواتير','${d['invoice_count']}',Icons.receipt,Colors.blue),
          _metric('الصندوق',Money.format((d['cash_balance'] as num).toInt()),Icons.payments,Colors.green),
          _metric('حساب الشبكة',Money.format((d['network_balance'] as num).toInt()),Icons.credit_card,Colors.blue),
          _metric('المردودات',Money.format((d['returns_total'] as num).toInt()),Icons.assignment_return,Colors.red),
          _metric('المصروفات',Money.format((d['expenses_total'] as num).toInt()),Icons.money_off,Colors.orange),
        ]),
        const SizedBox(height:12),
        GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:tiles.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:1.35,crossAxisSpacing:10,mainAxisSpacing:10),itemBuilder:(context,i){final x=tiles[i];return Card(child:InkWell(borderRadius:BorderRadius.circular(18),onTap:()=>open(x.page),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(x.icon,size:34,color:Theme.of(context).colorScheme.primary),const SizedBox(height:8),Text(x.title,style:const TextStyle(fontWeight:FontWeight.bold))])));}),
      ]));
    }),
  ));
  Widget _metric(String title,String value,IconData icon,Color color)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color),const SizedBox(height:4),Text(title),FittedBox(fit:BoxFit.scaleDown,child:Text(value,style:TextStyle(fontWeight:FontWeight.bold,fontSize:17,color:color)))])));
}
