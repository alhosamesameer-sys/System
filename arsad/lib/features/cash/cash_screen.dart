import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/statement_exporter.dart';
import '../../data/local_database.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 2, vsync: this);
  static const tables = ['cash_transactions', 'network_transactions'];
  static const labels = ['الصندوق', 'الشبكة والبنك'];
  static const incoming = {'opening', 'sale', 'deposit', 'adjustment_in'};

  Future<List<Map<String, Object?>>> movements(int index) async {
    final db = await LocalDatabase.instance.database;
    return db.query(tables[index], orderBy: 'id DESC');
  }

  Future<void> addMovement(String table, String type) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final title = switch (type) {
      'opening' => 'الرصيد الافتتاحي',
      'deposit' => 'إضافة رصيد',
      'withdrawal' => 'سحب رصيد',
      'expense' => 'مصروف',
      'bank_fee' => 'رسوم بنكية',
      _ => 'حركة حساب',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ بالريال')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'البيان')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      amount.dispose();
      note.dispose();
      return;
    }
    try {
      await LocalDatabase.instance.createAccountMovement(
        table: table, type: type, amountHalalas: Money.parseHalalas(amount.text), note: note.text,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Future<void> export(int index, List<Map<String, Object?>> rows, bool pdf) async {
    var running = 0;
    final chronological = rows.reversed.toList();
    final data = <List<String>>[];
    for (final row in chronological) {
      final type = row['type'] as String;
      final amount = (row['amount_halalas'] as num).toInt();
      final isIn = incoming.contains(type);
      running += isIn ? amount : -amount;
      final label = switch (type) {
        'opening' => 'رصيد افتتاحي', 'sale' => 'مبيعات', 'deposit' => 'إيداع',
        'withdrawal' => 'سحب', 'expense' => 'مصروف', 'bank_fee' => 'رسوم بنكية',
        'return' => 'مردود', 'adjustment_in' => 'تسوية إضافة', 'adjustment_out' => 'تسوية خصم',
        _ => type,
      };
      data.add([label, row['created_at'].toString(), '1', Money.format(amount),
        '${isIn ? '+' : '-'}${Money.format(amount)}', '${row['note'] ?? ''} • الرصيد بعد الحركة: ${Money.format(running)}']);
    }
    await StatementExporter.export(
      title: 'كشف حساب ${labels[index]}',
      headers: const ['اسم المنتج / الحركة', 'التاريخ', 'الكمية', 'السعر', 'الإجمالي', 'البيان'],
      rows: data,
      asPdf: pdf,
    );
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('الحسابات المالية'),
      bottom: TabBar(controller: tabs, tabs: const [
        Tab(text: 'الصندوق', icon: Icon(Icons.payments_outlined)),
        Tab(text: 'الشبكة والبنك', icon: Icon(Icons.account_balance_outlined)),
      ]),
    ),
    body: TabBarView(controller: tabs, children: [_account(0), _account(1)]),
  );

  Widget _account(int index) {
    final table = tables[index];
    final isNetwork = index == 1;
    final theme = Theme.of(context);
    final primary = isNetwork ? const Color(0xFF176B75) : const Color(0xFF244A73);
    return FutureBuilder<List<Map<String, Object?>>>(
      future: movements(index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الحركات'));
        final rows = snapshot.data ?? [];
        var balance = 0;
        for (final row in rows.reversed) {
          final amount = (row['amount_halalas'] as num).toInt();
          balance += incoming.contains(row['type']) ? amount : -amount;
        }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(isNetwork ? Icons.account_balance_outlined : Icons.wallet_outlined, color: Colors.white, size: 25)),
                const SizedBox(width: 12),
                Expanded(child: Text(isNetwork ? 'حساب الشبكة والبنك' : 'الصندوق النقدي',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
                const Icon(Icons.verified_user_outlined, color: Colors.white70),
              ]),
              const SizedBox(height: 22),
              const Text('الرصيد الحالي', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 5),
              Text(Money.format(balance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('${rows.length} حركة مسجلة', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('إدارة الحساب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
            children: [
              _action('رصيد افتتاحي', Icons.account_balance_wallet_outlined, () => addMovement(table, 'opening')),
              _action('إضافة رصيد', Icons.add_circle_outline, () => addMovement(table, 'deposit')),
              _action('سحب رصيد', Icons.remove_circle_outline, () => addMovement(table, 'withdrawal')),
              _action('مصروف', Icons.receipt_long, () => addMovement(table, 'expense')),
              if (isNetwork) _action('رسوم بنكية', Icons.account_balance, () => addMovement(table, 'bank_fee')),
            ],
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('كشف الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Text('${rows.length} حركة', style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => export(index, rows, true),
              icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('تصدير PDF'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.tonalIcon(onPressed: () => export(index, rows, false),
              icon: const Icon(Icons.table_view_outlined), label: const Text('تصدير Excel'))),
          ]),
          const SizedBox(height: 18),
          const Text('سجل الحركات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد عمليات مسجلة بعد')))),
          ...rows.map((row) {
            final type = row['type'] as String;
            final positive = incoming.contains(type);
            final amount = (row['amount_halalas'] as num).toInt();
            final label = switch (type) {
              'opening' => 'رصيد افتتاحي', 'sale' => 'مبيعات', 'deposit' => 'إضافة رصيد',
              'withdrawal' => 'سحب', 'expense' => 'مصروف', 'bank_fee' => 'رسوم بنكية',
              'return' => 'مردود', 'adjustment_in' => 'تسوية إضافة', 'adjustment_out' => 'تسوية خصم',
              _ => type,
            };
            final color = positive ? const Color(0xFF237A57) : const Color(0xFFB54747);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.dividerColor.withValues(alpha: .65))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
                  child: Icon(positive ? Icons.south_west : Icons.north_east, color: color)),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('${row['created_at']}${(row['note'] ?? '').toString().isEmpty ? '' : '\n${row['note']}'}')),
                isThreeLine: (row['note'] ?? '').toString().isNotEmpty,
                trailing: Text('${positive ? '+' : '−'}${Money.format(amount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
              ),
            );
          }),
        ]);
      },
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}
