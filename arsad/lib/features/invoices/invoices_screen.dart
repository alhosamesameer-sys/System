import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final query = TextEditingController();
  Future<List<Map<String,Object?>>> load() async {
    final db = await LocalDatabase.instance.database;
    return db.query('invoices', where:'invoice_no LIKE ?', whereArgs:['%${query.text}%'], orderBy:'id DESC');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الفواتير')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(controller: query, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث برقم الفاتورة')),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String,Object?>>>(
          future: load(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Center(child: Text('لا توجد فواتير'));
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final invoice = snapshot.data![index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text('فاتورة ${invoice['invoice_no']}'),
                    subtitle: Text('${invoice['created_at']} • ${invoice['payment_method']=='cash'?'نقد':'شبكة'}'),
                    trailing: Text(Money.format(invoice['total_halalas'] as int)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoice['id'] as int))).then((_) { if (mounted) setState(() {}); }),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]),
  );
}
