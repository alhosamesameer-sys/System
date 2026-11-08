import 'package:flutter/material.dart';
import '../../data/local_database.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أرصد')),
    body: FutureBuilder<List<int>>(
      future: Future.wait([
        LocalDatabase.instance.balance('cash_transactions'),
        LocalDatabase.instance.balance('network_transactions'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(title: const Text('رصيد الصندوق'), trailing: Text('$${snapshot.data![0]} هللة')),
          ListTile(title: const Text('رصيد الشبكة'), trailing: Text('$${snapshot.data![1]} هللة')),
        ]);
      },
    ),
  );
}
