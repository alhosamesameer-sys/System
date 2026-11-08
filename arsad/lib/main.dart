import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'data/local_database.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.database;
  runApp(const ArsadApp());
}

class ArsadApp extends StatelessWidget {
  const ArsadApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'أرصد | ARSAD',
    debugShowCheckedModeBanner: false,
    theme: ArsadTheme.light,
    locale: const Locale('ar'),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const LoginScreen(),
  );
}
