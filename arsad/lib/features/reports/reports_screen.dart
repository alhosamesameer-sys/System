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
    if (custom != null) {
      return DateTimeRange(
        start: DateTime(custom!.start.year, custom!.start.month, custom!.start.day),
        end: DateTime(custom!.end.year, custom!.end.month, custom!.end.day + 1),
      );
    }
    if (period == 'شهري') { return DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1)); }
    if (period == 'سنوي') {
      return DateTimeRange(start: DateTime(now.year), end: DateTime(now.year + 1));
    }
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
    if (kind == 'count') {
      return db.rawQuery(
        'SELECT invoice_no AS ref, created_at AS date, payment_method AS detail, total_halalas AS amount, \'فاتورة\' AS item, 1 AS quantity, total_halalas AS unit_price FROM invoices WHERE datetime(created_at)>=datetime(?) AND datetime(created_at)<datetime(?) ORDER BY created_at DESC',
        args,
      );
    }
    if (kind == 'sales' || kind == 'cash' || kind == 'network') {
      final filter = kind == 'cash' ? "AND invoices.payment_method='cash'"
        : kind == 'network' ? "AND invoices.payment_method='network'" : '';
      return db.rawQuery(
        'SELECT invoices.invoice_no AS ref, invoices.created_at AS date, invoice_items.product_name AS item, invoice_items.quantity AS quantity, invoice_items.unit_price_halalas AS unit_price, invoice_items.line_total_halalas AS amount, invoices.payment_method AS detail FROM invoice_items JOIN invoices ON invoices.id=invoice_items.invoice_id WHERE datetime(invoices.created_at)>=datetime(?) AND datetime(invoices.created_at)<datetime(?) $filter ORDER BY invoices.created_at DESC, invoice_items.id',
        args,
      );
    }
    if (kind == 'returns') {
      return db.rawQuery(
        'SELECT invoices.invoice_no AS ref, returns.created_at AS date, invoice_items.product_name AS item, return_items.quantity AS quantity, invoice_items.unit_price_halalas AS unit_price, return_items.amount_halalas AS amount, COALESCE(returns.reason, \'مردود\') AS detail FROM return_items JOIN returns ON returns.id=return_items.return_id JOIN invoice_items ON invoice_items.id=return_items.invoice_item_id JOIN invoices ON invoices.id=returns.invoice_id WHERE datetime(returns.created_at)>=datetime(?) AND datetime(returns.created_at)<datetime(?) ORDER BY returns.created_at DESC',
        args,
      );
    }
    if (kind == 'net') {
      return db.rawQuery(
        "SELECT invoices.invoice_no AS ref,invoices.created_at AS date,invoice_items.product_name AS item,invoice_items.quantity AS quantity,invoice_items.unit_price_halalas AS unit_price,invoice_items.line_total_halalas AS amount,'مبيعات' AS detail FROM invoice_items JOIN invoices ON invoices.id=invoice_items.invoice_id WHERE datetime(invoices.created_at)>=datetime(?) AND datetime(invoices.created_at)<datetime(?) UNION ALL SELECT invoices.invoice_no,returns.created_at,invoice_items.product_name,return_items.quantity,invoice_items.unit_price_halalas,-return_items.amount_halalas,'مرتجع' FROM return_items JOIN returns ON returns.id=return_items.return_id JOIN invoice_items ON invoice_items.id=return_items.invoice_item_id JOIN invoices ON invoices.id=returns.invoice_id WHERE datetime(returns.created_at)>=datetime(?) AND datetime(returns.created_at)<datetime(?) ORDER BY date DESC",
        [...args, ...args],
      );
    }
    if (kind == 'expenses') {
      return db.rawQuery(
        "SELECT CAST(id AS TEXT) AS ref,created_at AS date,title AS item,1 AS quantity,amount_halalas AS unit_price,amount_halalas AS amount,COALESCE(note,'مصروف') AS detail FROM expenses WHERE datetime(created_at)>=datetime(?) AND datetime(created_at)<datetime(?) ORDER BY created_at DESC",
        args,
      );
    }
    final table = kind == 'cashflow' ? 'cash_transactions' : 'network_transactions';
    return db.rawQuery(
      "SELECT CAST(id AS TEXT) AS ref,created_at AS date,CASE type WHEN 'opening' THEN 'رصيد افتتاحي' WHEN 'sale' THEN 'مبيعات' WHEN 'deposit' THEN 'إيداع' WHEN 'withdrawal' THEN 'سحب' WHEN 'expense' THEN 'مصروف' WHEN 'bank_fee' THEN 'رسوم بنكية' WHEN 'return' THEN 'مردود' WHEN 'adjustment_in' THEN 'تسوية إضافة' WHEN 'adjustment_out' THEN 'تسوية خصم' ELSE type END AS item,1 AS quantity,amount_halalas AS unit_price,CASE WHEN type IN ('opening','sale','deposit','adjustment_in') THEN amount_halalas ELSE -amount_halalas END AS amount,COALESCE(note,type) AS detail FROM $table WHERE datetime(created_at)>=datetime(?) AND datetime(created_at)<datetime(?) ORDER BY created_at DESC",
      args,
    );
  }

  Future<void> openStatement(String title, String kind) async {
    final rows = await detail(kind);
    if (!mounted) {
      return;
    }
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد تفاصيل في هذه الفترة')));
      return;
    }
    final data = rows.map((row) {
      final amount = (row['amount'] as num).toInt();
      final qty = (row['quantity'] as num?)?.toString() ?? '—';
      final unit = (row['unit_price'] as num?)?.toInt() ?? amount.abs();
      final item = (row['item'] ?? row['detail'] ?? '').toString();
      return [item, row['date'].toString(), qty, Money.format(unit), amount < 0 ? '-${Money.format(-amount)}' : Money.format(amount), (row['detail'] ?? '').toString()];
    }).toList();
    final headers = const ['اسم المنتج / الحركة', 'التاريخ', 'الكمية', 'السعر', 'الإجمالي', 'البيان'];
    final total = rows.fold<int>(0, (sum, row) => sum + (row['amount'] as num).toInt());

    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('كشف $title'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: Column(children: [
            Text('عدد السجلات: ${rows.length}  •  الإجمالي: ${Money.format(total)}'),
            const Divider(),
            Expanded(child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final amount = (row['amount'] as num).toInt();
                return ListTile(
                  dense: true,
                  title: Text(row['item']?.toString().trim().isNotEmpty == true ? row['item'].toString() : 'حركة مالية'),
                  subtitle: Text('${row['date']} • ${row['detail'] ?? '—'} • الكمية: ${row['quantity'] ?? 1} • مرجع ${row['ref']}'),
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
              await StatementExporter.export(title: 'كشف $title', headers: headers, rows: data, asPdf: true, periodLabel: '${range.start.toString().split(' ').first} — ${range.end.subtract(const Duration(days: 1)).toString().split(' ').first}');
            },
            child: const Text('PDF'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialog);
              await StatementExporter.export(title: 'كشف $title', headers: headers, rows: data, asPdf: false, periodLabel: '${range.start.toString().split(' ').first} — ${range.end.subtract(const Duration(days: 1)).toString().split(' ').first}');
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
          if (selected != null && mounted) {
            setState(() => custom = selected);
          }
        },
        icon: const Icon(Icons.date_range),
        label: const Text('فترة مخصصة'),
      ),
      Expanded(
        child: FutureBuilder<Map<String, Object?>>(
          future: LocalDatabase.instance.dashboardTotals(range.start, range.end),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('تعذر تحميل التقرير'));
            }
            final data = snapshot.data;
            if (data == null) {
              return const SizedBox.shrink();
            }
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
