import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(p.join(root, 'arsad_local.db'), version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE users(id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, created_at TEXT NOT NULL)');
        await db.execute("CREATE TABLE store_settings(id INTEGER PRIMARY KEY CHECK(id=1), store_name TEXT NOT NULL DEFAULT 'متجري', phone TEXT, address TEXT, currency TEXT NOT NULL DEFAULT 'ر.س', stock_enabled INTEGER NOT NULL DEFAULT 0)");
        await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, barcode TEXT UNIQUE, sale_price_halalas INTEGER NOT NULL CHECK(sale_price_halalas>=0), quantity REAL, low_stock_limit REAL NOT NULL DEFAULT 5, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)');
        await db.execute('CREATE INDEX idx_products_name ON products(name)');
        await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
        await db.execute("CREATE TABLE invoices(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_no TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL, payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','network')), total_halalas INTEGER NOT NULL CHECK(total_halalas>=0), status TEXT NOT NULL DEFAULT 'completed', note TEXT)");
        await db.execute('CREATE TABLE invoice_items(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL REFERENCES invoices(id), product_id INTEGER REFERENCES products(id), product_name TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity>0), unit_price_halalas INTEGER NOT NULL, line_total_halalas INTEGER NOT NULL, returned_quantity REAL NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE returns(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL REFERENCES invoices(id), created_at TEXT NOT NULL, payment_method TEXT NOT NULL, total_halalas INTEGER NOT NULL, reason TEXT)');
        await db.execute('CREATE TABLE return_items(id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER NOT NULL REFERENCES returns(id), invoice_item_id INTEGER NOT NULL REFERENCES invoice_items(id), quantity REAL NOT NULL, amount_halalas INTEGER NOT NULL)');
        await db.execute('CREATE TABLE cash_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, type TEXT NOT NULL, amount_halalas INTEGER NOT NULL, reference_type TEXT, reference_id INTEGER, note TEXT)');
        await db.execute('CREATE TABLE network_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, type TEXT NOT NULL, amount_halalas INTEGER NOT NULL, reference_type TEXT, reference_id INTEGER, note TEXT)');
        await db.execute("CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, title TEXT NOT NULL, amount_halalas INTEGER NOT NULL, account TEXT NOT NULL CHECK(account IN ('cash','network')), note TEXT)");
        await db.execute('CREATE TABLE stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL REFERENCES products(id), created_at TEXT NOT NULL, type TEXT NOT NULL, quantity REAL NOT NULL, reference_type TEXT, reference_id INTEGER)');
        await db.execute('CREATE TABLE app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('store_settings', {'id': 1, 'store_name': 'متجري'});
        await db.insert('app_settings', {'key': 'stock_enabled', 'value': 'false'});
      });
    return _db!;
  }

  Future<bool> hasUser() async => (Sqflite.firstIntValue(await (await database).rawQuery('SELECT COUNT(*) FROM users')) ?? 0) > 0;

  Future<void> createFirstUser(String username, String passwordHash) async {
    await (await database).insert('users', {'username': username, 'password_hash': passwordHash, 'created_at': DateTime.now().toIso8601String()});
  }

  Future<int> balance(String table) async {
    if (!{'cash_transactions', 'network_transactions'}.contains(table)) throw ArgumentError('Unsupported account');
    final rows = await (await database).rawQuery("SELECT COALESCE(SUM(CASE WHEN type IN ('opening','sale','deposit','adjustment_in') THEN amount_halalas ELSE -amount_halalas END),0) balance FROM $table");
    return (rows.first['balance'] as num).toInt();
  }

  Future<Map<String, Object?>> dashboardTotals(DateTime start, DateTime end) async {
    final rows = await (await database).rawQuery("""SELECT COUNT(*) invoice_count, COALESCE(SUM(total_halalas),0) sales_total, COALESCE(SUM(CASE WHEN payment_method='cash' THEN total_halalas ELSE 0 END),0) cash_total, COALESCE(SUM(CASE WHEN payment_method='network' THEN total_halalas ELSE 0 END),0) network_total FROM invoices WHERE status='completed' AND created_at BETWEEN ? AND ?""", [start.toIso8601String(), end.toIso8601String()]);
    return rows.first;
  }
}
