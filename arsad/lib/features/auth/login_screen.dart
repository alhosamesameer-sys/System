import 'package:flutter/material.dart';
import '../../data/local_database.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
 const LoginScreen({super.key});
 @override State<LoginScreen> createState()=>_LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
 final username=TextEditingController(text:'sameer');
 final password=TextEditingController();
 String? error; bool busy=false; bool remember=true; bool obscure=true;
 Future<void> submit() async {
  if(busy)return;
  setState(()=>busy=true);
  try {
   final ok=await LocalDatabase.instance.verifyLogin(username.text,password.text);
   if(!ok) {setState(()=>error='اسم المستخدم أو كلمة المرور غير صحيحة');return;}
   if(!mounted)return;
   Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const DashboardScreen()));
  } catch(e) {setState(()=>error='تعذر تسجيل الدخول: $e');}
  finally {if(mounted)setState(()=>busy=false);}
 }
 @override void dispose(){username.dispose();password.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(children:[
 const Icon(Icons.shopping_cart_rounded,size:76,color:Color(0xFF0866D5)),
 const Text('أرصد',style:TextStyle(fontSize:38,fontWeight:FontWeight.bold,color:Color(0xFF073B78))),
 const Text('ARSAD • نظام محاسبة ومبيعات'),
 const SizedBox(height:32),
 TextField(controller:username,decoration:const InputDecoration(labelText:'اسم المستخدم',prefixIcon:Icon(Icons.person))),
 const SizedBox(height:12),
 TextField(controller:password,obscureText:obscure,onSubmitted:(_)=>submit(),decoration:InputDecoration(labelText:'كلمة المرور',prefixIcon:const Icon(Icons.lock),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)))),
 CheckboxListTile(value:remember,onChanged:(v)=>setState(()=>remember=v??true),title:const Text('تذكرني'),contentPadding:EdgeInsets.zero),
 if(error!=null) Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),
 SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:submit,child:Text(busy?'جارٍ الدخول...':'دخول'))),
 const SizedBox(height:16),const Text('يعمل محلياً دون اتصال بالإنترنت',style:TextStyle(color:Colors.grey))
])))))));
}
