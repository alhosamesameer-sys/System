import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
class BarcodeScreen extends StatefulWidget {const BarcodeScreen({super.key});@override State<BarcodeScreen> createState()=>_BarcodeScreenState();}
class _BarcodeScreenState extends State<BarcodeScreen>{bool done=false;@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('مسح الباركود')),body:MobileScanner(onDetect:(capture){if(done)return;final code=capture.barcodes.firstOrNull?.rawValue;if(code!=null&&code.isNotEmpty){done=true;Navigator.pop(c,code);}},errorBuilder:(c,e,child)=>Center(child:Text('تعذر تشغيل الكاميرا: $e'))));}
