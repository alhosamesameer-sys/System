import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../data/local_database.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();
  String? error;
  bool loading = false;
  String hash(String value) => sha256.convert(utf8.encode(value)).toString();

  Future<void> submit() async {
    if (user.text.trim().isEmpty || pass.text.length < 6) {
      setState(() => error = 'أدخل اسم المستخدم وكلمة مرور من 6 أحرف على الأقل');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final db = LocalDatabase.instance;
      if (!await db.hasUser()) {
        await db.createFirstUser(user.text.trim(), hash(pass.text));
      } else {
        final rows = await (await db.database).query('users', where: 'username=? AND password_hash=?', whereArgs: [user.text.trim(), hash(pass.text)]);
        if (rows.isEmpty) throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() { user.dispose(); pass.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(children: [
      const Icon(Icons.shopping_cart_rounded, size: 76, color: Color(0xFF0866D5)),
      const Text('أرصد', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFF073B78))),
      const Text('ARSAD • نظام محاسبة ومبيعات متكامل'),
      const SizedBox(height: 36),
      TextField(controller: user, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person))),
      const SizedBox(height: 14),
      TextField(controller: pass, obscureText: true, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock))),
      if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'يرجى الانتظار...' : 'دخول'))),
      const SizedBox(height: 12), const Text('بياناتك محفوظة على هذا الجهاز فقط', style: TextStyle(color: Colors.grey)),
    ])),
  ))));
}
