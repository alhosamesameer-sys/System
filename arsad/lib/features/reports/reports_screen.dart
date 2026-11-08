import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/statement_exporter.dart';
import '../../data/local_database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String period = 'يومي';
  DateTimeRange? custom;

  DateTimeRange get range {
    final now = DateTime.now();
    if (custom != null) return DateTimeRange(
      start: DateTime(custom!.start.year, custom!.start.month, custom!.start.day),
      end: DateTime(custom!.end.year, custom!.end.month, custom!.end.day + 1),
    );
    if (period == 'شهري') { return DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1)); }
    if (period == 'سنوي') return DateTimeRange(start: DateTime(now.year), end: DateTime(now.year + 1));
    if (period == 'أسبوعي') {
      final start = DateTime(now.year, now.month, now.day - now.weekday + 1);
      return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
    }
    final start = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
  }

  Future<List<Map<String, Object?>>> detail(String kind) async {
    final db = await LocalDatabase.instance.database;
    final args = [range.start.toIso8601String(), range.end.toIso8601String()];
    if (kind == 'sales' || kind == 'cash' || kind == 'network' || kind == 'count') {
      final filter = kind == 'cash' ? "AND payment_method='cash'"
        : kind == 'network' ? "AND payment_method='network'" : '';
      return db.rawQuery(
        'SELECT invoice_no AS ref, created_at AS date, payment_method AS detail, total_halalas AS amount FROM invoices WHERE created_at>=? AND created_at<? $filter ORDER BY created_at DESC',
        args,
      );
    }
    if (kind == 'returns') { return db.rawQuery(
      'SELECT invoices.invoice_no AS ref, returns.created_at AS date, returns.reason AS detail, returns.total_halalas AS amount FROM returns JOIN invoices ON invoices.id=returns.invoice_id WHERE returns.created_at>=? AND returns.created_at<? ORDER BY returns.created_at DESC',
      args,
    ); }
    if (kind == 'net') { return db.rawQuery(
      "SELECT invoice_no AS ref,created_at AS date,'مبيعات' AS detail,total_halalas AS amount FROM invoices WHERE created_at>=? AND created_at<? UNION ALL SELECT CAST(id AS TEXT),created_at,'مرتجع',-total_halalas FROM returns WHERE created_at>=? AND created_at<? ORDER BY date DESC",
      [...args, ...args],
    ); }
    if (kind == 'expenses') { return db.rawQuery(
      'SELECT id AS ref,created_at AS date,title AS detail,amount_halalas AS amount FROM expenses WHERE created_at>=? AND created_at<? ORDER BY created_at DESC',
      args,
    ); }
    final table = kind == 'cashflow' ? 'cash_transactions' : 'network_transactions';
    return db.rawQuery(
      'SELECT id AS ref,created_at AS date,COALESCE(note,type) AS detail,amount_halalas AS amount,type FROM $table WHERE created_at>=? AND created_at<? ORDER BY created_at DESC',
      args,
    );
  }

  Future<void> openStatement(String title, String kind) async {
    final rows = await detail(kind);
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد تفاصيل في هذه الفترة')));
      return;
    }
    final data = rows.map((row) {
      final amount = (row['amount'] as num).toInt();
      return [row['date'].toString(), row['ref'].toString(), row['detail']?.toString() ?? '',
        amount < 0 ? '-${Money.format(-amount)}' : Money.format(amount)];
    }).toList();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('كشف $title'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: Column(children: [
            Text('عدد السجلات: ${rows.length}'),
            const Divider(),
            Expanded(child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final amount = (row['amount'] as num).toInt();
                return ListTile(
                  dense: true,
                  title: Text(row['detail']?.toString() ?? ''),
                  subtitle: Text('${row['date']} • مرجع ${row['ref']}'),
                  trailing: Text(amount < 0 ? '-${Money.format(-amount)}' : Money.format(amount)),
                );
              },
            )),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إغلاق')),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(dialog);
              await StatementExporter.export(title: 'كشف $title', headers: const ['التاريخ', 'المرجع', 'البيان', 'المبلغ'], rows: data, asPdf: true);
            },
            child: const Text('PDF'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialog);
              await StatementExporter.export(title: 'كشف $title', headers: const ['التاريخ', 'المرجع', 'البيان', 'المبلغ'], rows: data, asPdf: false);
            },
            child: const Text('Excel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقارير والتحليلات')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 6, children: [
          for (final value in ['يومي', 'أسبوعي', 'شهري', 'سنوي'])
            ChoiceChip(label: Text(value), selected: period == value && custom == null,
              onSelected: (_) => setState(() { period = value; custom = null; })),
        ]),
      ),
      TextButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final selected = await showDateRangePicker(
            context: context, firstDate: DateTime(2020), lastDate: DateTime(now.year + 2), initialDateRange: range,
          );
          if (selected != null && mounted) setState(() => custom = selected);
        },
        icon: const Icon(Icons.date_range),
        label: const Text('فترة مخصصة'),
      ),
      Expanded(
        child: FutureBuilder<Map<String, Object?>>(
          future: LocalDatabase.instance.dashboardTotals(range.start, range.end),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return const Center(child: Text('تعذر تحميل التقرير'));
            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return ListView(padding: const EdgeInsets.all(14), children: [
              const Text('ملخص الأداء', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              _metric('إجمالي المبيعات', data['sales_total'], Icons.point_of_sale, Colors.blue, 'sales'),
              _metric('المبيعات النقدية', data['cash_total'], Icons.payments, Colors.green, 'cash'),
              _metric('مبيعات الشبكة', data['network_total'], Icons.credit_card, Colors.teal, 'network'),
              _metric('إجمالي المرتجعات', data['returns_total'], Icons.assignment_return, Colors.red, 'returns'),
              _metric('صافي المبيعات', data['net_sales_total'], Icons.trending_up, Colors.indigo, 'net'),
              _metric('المصروفات', data['expenses_total'], Icons.money_off, Colors.orange, 'expenses'),
              _metric('حركة الصندوق', data['cash_net'], Icons.account_balance_wallet, Colors.blueGrey, 'cashflow'),
              _metric('حركة الشبكة والبنك', data['network_net'], Icons.account_balance, Colors.teal, 'networkflow'),
              Card(child: InkWell(
                onTap: () => openStatement('عدد الفواتير', 'count'),
                child: ListTile(
                  title: const Text('عدد الفواتير'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(data['invoice_count'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_left),
                  ]),
                ),
              )),
            ]);
          },
        ),
      ),
    ]),
  );

  Widget _metric(String title, Object? value, IconData icon, Color color, String kind) => Card(
    elevation: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openStatement(title, kind),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: .1), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(Money.format((value as num).toInt()), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const Icon(Icons.chevron_left),
        ]),
      ),
    ),
  );
}
