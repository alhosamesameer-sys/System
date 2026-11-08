import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/local_database.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  Future<void> addMovement(String table, String type) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'deposit' ? 'إيداع' : 'سحب'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ بالريال')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'البيان')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final halalas = Money.parseHalalas(amount.text);
      if (halalas <= 0) throw Exception('أدخل مبلغاً أكبر من صفر');
      final balance = await LocalDatabase.instance.balance(table);
      if (type != 'deposit' && halalas > balance) throw Exception('الرصيد غير كافٍ');
      await (await LocalDatabase.instance.database).insert(table, {
        'created_at': DateTime.now().toIso8601String(),
        'type': type,
        'amount_halalas': halalas,
        'note': note.text,
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الصندوق والشبكة')),
    body: FutureBuilder<List<int>>(
      future: Future.wait([
        LocalDatabase.instance.balance('cash_transactions'),
        LocalDatabase.instance.balance('network_transactions'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.all(16), children: [
          _account('الصندوق النقدي', snapshot.data![0], 'cash_transactions'),
          _account('حساب الشبكة', snapshot.data![1], 'network_transactions'),
        ]);
      },
    ),
  );

  Widget _account(String title, int amount, String table) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(title),
        Text(Money.format(amount), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: () => addMovement(table, 'deposit'), child: const Text('إيداع')),
          TextButton(onPressed: () => addMovement(table, 'withdrawal'), child: const Text('سحب')),
        ]),
      ]),
    ),
  );
}
