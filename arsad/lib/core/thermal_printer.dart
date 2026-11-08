import 'package:flutter/services.dart';

class ThermalPrinterService {
  ThermalPrinterService._();
  static const _channel=MethodChannel('arsad/local_bluetooth');

  static Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestConnectPermission') ?? false;

  static Future<List<Map<String,String>>> bondedDevices() async {
    final allowed=await requestPermission();
    if(!allowed)throw Exception('لم يتم منح إذن Bluetooth');
    final result=await _channel.invokeMethod<List<dynamic>>('bondedDevices');
    return (result??[]).map((entry)=>Map<String,String>.from(entry as Map)).toList();
  }

  static Future<void> printBytes({required String address,required List<int> bytes}) async {
    final allowed=await requestPermission();
    if(!allowed)throw Exception('إذن Bluetooth مطلوب للطباعة');
    await _channel.invokeMethod<bool>('printBytes',{'address':address,'bytes':Uint8List.fromList(bytes)});
  }
}
