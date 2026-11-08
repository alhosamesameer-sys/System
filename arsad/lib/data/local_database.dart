import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(p.join(root, 'arsad_local.db'), version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE users(id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, created_at TEXT NOT NULL)');
        await db.execute("CREATE TABLE store_settings(id INTEGER PRIMARY KEY CHECK(id=1), store_name TEXT NOT NULL DEFAULT 'متجري', phone TEXT, address TEXT, currency TEXT NOT NULL DEFAULT 'ر.س', stock_enabled INTEGER NOT NULL DEFAULT 0)");
        await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, barcode TEXT UNIQUE, sale_price_halalas INTEGER NOT NULL CHECK(sale_price_halalas>=0), quantity REAL, unit TEXT NOT NULL DEFAULT 'حبة', low_stock_limit REAL NOT NULL DEFAULT 5, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)');
        await db.execute('CREATE INDEX idx_products_name ON products(name)');
        await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
        await db.execute("CREATE TABLE invoices(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_no TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL, payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','network')), total_halalas INTEGER NOT NULL CHECK(total_halalas>=0), status TEXT NOT NULL DEFAULT 'completed', note TEXT)");
        await db.execute('CREATE TABLE invoice_items(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL REFERENCES invoices(id), product_id INTEGER REFERENCES products(id), product_name TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity>0), unit TEXT NOT NULL DEFAULT 'حبة', unit_price_halalas INTEGER NOT NULL, line_total_halalas INTEGER NOT NULL, returned_quantity REAL NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE returns(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL REFERENCES invoices(id), created_at TEXT NOT NULL, payment_method TEXT NOT NULL, total_halalas INTEGER NOT NULL, reason TEXT)');
        await db.execute('CREATE TABLE return_items(id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER NOT NULL REFERENCES returns(id), invoice_item_id INTEGER NOT NULL REFERENCES invoice_items(id), quantity REAL NOT NULL, amount_halalas INTEGER NOT NULL)');
        await db.execute('CREATE TABLE cash_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, type TEXT NOT NULL, amount_halalas INTEGER NOT NULL, reference_type TEXT, reference_id INTEGER, note TEXT)');
        await db.execute('CREATE TABLE network_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, type TEXT NOT NULL, amount_halalas INTEGER NOT NULL, reference_type TEXT, reference_id INTEGER, note TEXT)');
        await db.execute("CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, title TEXT NOT NULL, amount_halalas INTEGER NOT NULL, account TEXT NOT NULL CHECK(account IN ('cash','network')), note TEXT, transaction_id INTEGER)");
        await db.execute('CREATE TABLE stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL REFERENCES products(id), created_at TEXT NOT NULL, type TEXT NOT NULL, quantity REAL NOT NULL, reference_type TEXT, reference_id INTEGER)');
        await db.execute('CREATE TABLE app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('store_settings', {'id':1,'store_name':'متجري'});
        await db.insert('app_settings', {'key':'stock_enabled','value':'false'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if(oldVersion<2) await db.execute('ALTER TABLE expenses ADD COLUMN transaction_id INTEGER');
        if(oldVersion<3) {
          await db.execute("ALTER TABLE products ADD COLUMN unit TEXT NOT NULL DEFAULT 'حبة'");
          await db.execute("ALTER TABLE invoice_items ADD COLUMN unit TEXT NOT NULL DEFAULT 'حبة'");
        }
      });
    await ensureDefaultUser();
    return _db!;
  }

  String passwordHash(String password) {
    List<int> bytes = utf8.encode('ARSAD-local-v1-7c9d:$password');
    for (var i=0;i<12000;i++) { bytes = sha256.convert(bytes).bytes; }
    return base64UrlEncode(bytes);
  }

  Future<void> ensureDefaultUser() async {
    final db = _db!;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
    if (count == 0) {
      await db.insert('users', {'username':'sameer','password_hash':passwordHash('123456'),'created_at':DateTime.now().toIso8601String()});
      await db.insert('app_settings', {'key':'must_change_password','value':'true'}, conflictAlgorithm:ConflictAlgorithm.replace);
    }
  }

  Future<bool> verifyLogin(String username,String password) async {
    final rows = await (await database).query('users',where:'username=? AND password_hash=?',whereArgs:[username.trim(),passwordHash(password)],limit:1);
    return rows.isNotEmpty;
  }

  Future<void> changePassword(String password) async {
    if(password.length<6) throw Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
    final db=await database;
    await db.update('users',{'password_hash':passwordHash(password)},where:'id=1');
    await db.insert('app_settings',{'key':'must_change_password','value':'false'},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<bool> hasUser() async => (Sqflite.firstIntValue(await (await database).rawQuery('SELECT COUNT(*) FROM users'))??0)>0;

  Future<bool> stockEnabled() async {
    final rows=await (await database).query('app_settings',where:'key=?',whereArgs:['stock_enabled']);
    return rows.isNotEmpty && rows.first['value']=='true';
  }

  Future<int> balance(String table) async {
    if(!{'cash_transactions','network_transactions'}.contains(table)) throw ArgumentError('Unsupported account');
    final rows=await (await database).rawQuery("SELECT COALESCE(SUM(CASE WHEN type IN ('opening','sale','deposit','adjustment_in') THEN amount_halalas ELSE -amount_halalas END),0) AS balance FROM $table");
    return (rows.first['balance'] as num).toInt();
  }

  Future<int> createInvoice({required List<Map<String,Object?>> items,required String paymentMethod,required bool stockEnabled}) async {
    if(items.isEmpty) throw Exception('الفاتورة فارغة');
    if(!{'cash','network'}.contains(paymentMethod)) throw Exception('طريقة الدفع غير صحيحة');
    final db=await database;
    return db.transaction((txn) async {
      final now=DateTime.now().toIso8601String();
      var total=0;
      for(final item in items) {
        final qty=(item['quantity'] as num).toDouble();
        final price=item['unit_price_halalas'] as int;
        if(qty<=0||price<0) throw Exception('كمية أو سعر غير صحيح');
        total+=(qty*price).round();
        if(stockEnabled) {
          final found=await txn.query('products',where:'id=?',whereArgs:[item['product_id']],limit:1);
          if(found.isEmpty) throw Exception('الصنف غير موجود');
          final available=(found.first['quantity'] as num?)?.toDouble()??0;
          if(available<qty) throw Exception('المخزون غير كافٍ للصنف ${item['product_name']}');
        }
      }
      final invoiceId=await txn.insert('invoices',{'invoice_no':'AR-${DateTime.now().microsecondsSinceEpoch}','created_at':now,'payment_method':paymentMethod,'total_halalas':total,'status':'completed'});
      for(final item in items) {
        final qty=(item['quantity'] as num).toDouble();
        final productId=item['product_id'] as int;
        final line=(qty*(item['unit_price_halalas'] as int)).round();
        final itemId=await txn.insert('invoice_items',{'invoice_id':invoiceId,'product_id':productId,'product_name':item['product_name'],'quantity':qty,'unit':item['unit']??'حبة','unit_price_halalas':item['unit_price_halalas'],'line_total_halalas':line});
        if(stockEnabled) {
          await txn.rawUpdate('UPDATE products SET quantity=quantity-? WHERE id=?',[qty,productId]);
          await txn.insert('stock_movements',{'product_id':productId,'created_at':now,'type':'sale','quantity':-qty,'reference_type':'invoice_item','reference_id':itemId});
        }
      }
      await txn.insert(paymentMethod=='cash'?'cash_transactions':'network_transactions',{'created_at':now,'type':'sale','amount_halalas':total,'reference_type':'invoice','reference_id':invoiceId,'note':'مبيعات'});
      return invoiceId;
    });
  }

  Future<int> createReturn({required int invoiceId,required Map<int,double> quantities,required String reason}) async {
    if(quantities.isEmpty) throw Exception('حدد كمية واحدة على الأقل');
    final db=await database;
    return db.transaction((txn) async {
      final invoices=await txn.query('invoices',where:'id=? AND status=?',whereArgs:[invoiceId,'completed']);
      if(invoices.isEmpty) throw Exception('الفاتورة غير متاحة للمردود');
      final invoice=invoices.first;
      final now=DateTime.now().toIso8601String();
      var total=0;
      final selected=<Map<String,Object?>>[];
      for(final entry in quantities.entries) {
        if(entry.value<=0) continue;
        final found=await txn.query('invoice_items',where:'id=? AND invoice_id=?',whereArgs:[entry.key,invoiceId]);
        if(found.isEmpty) throw Exception('الصنف لا يتبع الفاتورة');
        final item=found.first;
        final remaining=(item['quantity'] as num).toDouble()-(item['returned_quantity'] as num).toDouble();
        if(entry.value>remaining) throw Exception('تجاوزت الكمية القابلة للإرجاع');
        final unitPrice=item['unit_price_halalas'] as int;
        final alreadyReturned=(item['returned_quantity'] as num).toDouble();
        final amount=((alreadyReturned+entry.value)*unitPrice).round()-(alreadyReturned*unitPrice).round();
        total+=amount;
        selected.add({'item':item,'qty':entry.value,'amount':amount});
      }
      if(total<=0) throw Exception('قيمة المردود غير صحيحة');
      final returnId=await txn.insert('returns',{'invoice_id':invoiceId,'created_at':now,'payment_method':invoice['payment_method'],'total_halalas':total,'reason':reason});
      for(final row in selected) {
        final item=row['item'] as Map<String,Object?>;
        final qty=row['qty'] as double;
        await txn.insert('return_items',{'return_id':returnId,'invoice_item_id':item['id'],'quantity':qty,'amount_halalas':row['amount']});
        await txn.rawUpdate('UPDATE invoice_items SET returned_quantity=returned_quantity+? WHERE id=?',[qty,item['id']]);
        final originalStockMovements=await txn.query('stock_movements',where:'type=? AND reference_type=? AND reference_id=?',whereArgs:['sale','invoice_item',item['id']],limit:1);
        if(originalStockMovements.isNotEmpty && item['product_id']!=null) {
          await txn.rawUpdate('UPDATE products SET quantity=COALESCE(quantity,0)+? WHERE id=?',[qty,item['product_id']]);
          await txn.insert('stock_movements',{'product_id':item['product_id'],'created_at':now,'type':'return','quantity':qty,'reference_type':'return','reference_id':returnId});
        }
      }
      final account=invoice['payment_method']=='cash'?'cash_transactions':'network_transactions';
      await txn.insert(account,{'created_at':now,'type':'return','amount_halalas':total,'reference_type':'return','reference_id':returnId,'note':'مردود'});
      final sums=await txn.rawQuery('SELECT COALESCE(SUM(total_halalas),0) AS returned FROM returns WHERE invoice_id=?',[invoiceId]);
      if((sums.first['returned'] as num).toInt()>=(invoice['total_halalas'] as int)) {
        await txn.update('invoices',{'status':'fully_returned'},where:'id=?',whereArgs:[invoiceId]);
      }
      return returnId;
    });
  }

  Future<void> createAccountMovement({required String table,required String type,required int amountHalalas,required String note}) async {
    if(!{'cash_transactions','network_transactions'}.contains(table)) throw ArgumentError('Unsupported account');
    if(!{'opening','deposit','withdrawal','expense','bank_fee','adjustment_in','adjustment_out'}.contains(type)) throw ArgumentError('Unsupported movement');
    if(amountHalalas<=0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    final db=await database;
    await db.transaction((txn) async {
      final currentRows=await txn.rawQuery("SELECT COALESCE(SUM(CASE WHEN type IN ('opening','sale','deposit','adjustment_in') THEN amount_halalas ELSE -amount_halalas END),0) AS balance FROM $table");
      final current=(currentRows.first['balance'] as num).toInt();
      if(type=='opening') {
        final count=Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM $table'))??0;
        if(count>0) throw Exception('تم تسجيل رصيد افتتاحي لهذا الحساب مسبقاً');
      } else if({'withdrawal','expense','bank_fee','adjustment_out'}.contains(type) && amountHalalas>current) {
        throw Exception('الرصيد غير كافٍ');
      }
      final now=DateTime.now().toIso8601String();
      final movementId=await txn.insert(table,{'created_at':now,'type':type,'amount_halalas':amountHalalas,'note':note});
      if(type=='expense'||type=='bank_fee') {
        await txn.insert('expenses',{'created_at':now,'title':note.trim().isEmpty?(type=='bank_fee'?'رسوم بنكية':'مصروف'):note,'amount_halalas':amountHalalas,'account':table=='cash_transactions'?'cash':'network','note':note,'transaction_id':movementId});
      }
    });
  }

  Future<Map<String,Object?>> dashboardTotals(DateTime start,DateTime end) async {
    final db=await database;
    final args=[start.toIso8601String(),end.toIso8601String()];
    final sales=await db.rawQuery("SELECT COUNT(*) AS invoice_count,COALESCE(SUM(total_halalas),0) AS sales_total,COALESCE(SUM(CASE WHEN payment_method='cash' THEN total_halalas ELSE 0 END),0) AS cash_total,COALESCE(SUM(CASE WHEN payment_method='network' THEN total_halalas ELSE 0 END),0) AS network_total FROM invoices WHERE created_at>=? AND created_at<?",args);
    final returned=await db.rawQuery('SELECT COALESCE(SUM(total_halalas),0) AS returns_total FROM returns WHERE created_at>=? AND created_at<?',args);
    final expenses=await db.rawQuery('SELECT COALESCE(SUM(amount_halalas),0) AS expenses_total FROM expenses WHERE created_at>=? AND created_at<?',args);
    final cash=await db.rawQuery("SELECT COALESCE(SUM(CASE WHEN type IN ('opening','sale','deposit','adjustment_in') THEN amount_halalas ELSE -amount_halalas END),0) AS net FROM cash_transactions WHERE created_at>=? AND created_at<?",args);
    final network=await db.rawQuery("SELECT COALESCE(SUM(CASE WHEN type IN ('opening','sale','deposit','adjustment_in') THEN amount_halalas ELSE -amount_halalas END),0) AS net FROM network_transactions WHERE created_at>=? AND created_at<?",args);
    final gross=(sales.first['sales_total'] as num).toInt();
    final ret=(returned.first['returns_total'] as num).toInt();
    return {
      ...sales.first,
      'returns_total':ret,
      'net_sales_total':gross-ret,
      'expenses_total':(expenses.first['expenses_total'] as num).toInt(),
      'cash_net':(cash.first['net'] as num).toInt(),
      'network_net':(network.first['net'] as num).toInt(),
    };
  }
}
