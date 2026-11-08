import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import '../barcode/barcode_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final search = TextEditingController();
  final cart = <int,Map<String,Object?>>{};
  String payment = 'cash';
  bool saving = false;

  Future<List<Map<String,Object?>>> products() async {
    final db = await LocalDatabase.instance.database;
    return db.query('products', where:'is_active=1 AND (name LIKE ? OR barcode LIKE ?)', whereArgs:['%${search.text}%','%${search.text}%'], limit:40);
  }

  int get total => cart.values.fold(0, (sum, item) => sum + (item['sale_price_halalas'] as int) * (item['qty'] as int));

  void add(Map<String,Object?> product) {
    final id = product['id'] as int;
    setState(() {
      if (cart.containsKey(id)) {
        cart[id]!['qty'] = (cart[id]!['qty'] as int) + 1;
      } else {
        cart[id] = {...product, 'qty':1};
      }
    });
  }

  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScreen()));
    if (code != null && mounted) { search.text = code; setState(() {}); }
  }

  Future<void> save() async {
    if (cart.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      await LocalDatabase.instance.createInvoice(
        items: cart.values.map((item) => <String,Object?>{
          'product_id':item['id'],
          'product_name':item['name'],
          'quantity':item['qty'],
          'unit_price_halalas':item['sale_price_halalas'],
        }).toList(),
        paymentMethod: payment,
        stockEnabled: await LocalDatabase.instance.stockEnabled(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة وتسجيل الحركة المالية')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الفاتورة: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مبيعات جديدة'), actions:[IconButton(onPressed:scan, icon:const Icon(Icons.qr_code_scanner))]),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(controller:search, onChanged:(_) => setState(() {}), decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث أو امسح الباركود')),
      ),
      SizedBox(
        height: 160,
        child: FutureBuilder<List<Map<String,Object?>>>(
          future: products(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child:CircularProgressIndicator());
            return ListView(
              children: snapshot.data!.map((product) => ListTile(
                title: Text(product['name'] as String),
                subtitle: Text(Money.format(product['sale_price_halalas'] as int)),
                trailing: IconButton(icon:const Icon(Icons.add_circle,color:Colors.blue),onPressed:()=>add(product)),
              )).toList(),
            );
          },
        ),
      ),
      const Divider(),
      Expanded(
        child: ListView(
          children: cart.entries.map((entry) => ListTile(
            title: Text(entry.value['name'] as String),
            subtitle: Text('الكمية: ${entry.value['qty']}'),
            trailing: Row(mainAxisSize:MainAxisSize.min,children:[
              IconButton(onPressed:()=>setState(()=>entry.value['qty']=(entry.value['qty'] as int)+1),icon:const Icon(Icons.add)),
              IconButton(onPressed:()=>setState(()=>entry.value['qty']=(entry.value['qty'] as int)>1?(entry.value['qty'] as int)-1:1),icon:const Icon(Icons.remove)),
              IconButton(onPressed:()=>setState(()=>cart.remove(entry.key)),icon:const Icon(Icons.delete,color:Colors.red)),
            ]),
          )).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children:[
          Text('الإجمالي: ${Money.format(total)}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          Row(children:[
            Expanded(child:RadioListTile<String>(value:'cash',groupValue:payment,title:const Text('نقد'),onChanged:(value)=>setState(()=>payment=value!))),
            Expanded(child:RadioListTile<String>(value:'network',groupValue:payment,title:const Text('شبكة'),onChanged:(value)=>setState(()=>payment=value!))),
          ]),
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'جار الحفظ':'حفظ الفاتورة'))),
        ]),
      ),
    ]),
  );
}
