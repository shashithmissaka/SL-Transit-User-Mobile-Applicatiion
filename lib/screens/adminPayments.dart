import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final DatabaseReference _paymentsRef = FirebaseDatabase.instance.ref("payments");

  Map<String, dynamic> _payments = {};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    _paymentsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _payments = Map<String, dynamic>.from(data);
      });
    });
  }

  void _deletePayment(String paymentId) {
    _paymentsRef.child(paymentId).remove();
  }

  void _updatePayment(String paymentId, Map<String, dynamic> newData) {
    _paymentsRef.child(paymentId).update(newData);
  }

  void _showPaymentDialog(String paymentId, Map<dynamic, dynamic> paymentData) {
    final busIdController = TextEditingController(text: paymentData['busId'] ?? '');
    final startCityController = TextEditingController(text: paymentData['startCity'] ?? '');
    final endCityController = TextEditingController(text: paymentData['endCity'] ?? '');
    final totalFareController = TextEditingController(text: paymentData['totalFare']?.toString() ?? '0');
    final paymentStatusController = TextEditingController(text: paymentData['paymentStatus'] ?? 'unpaid');
    final userIdController = TextEditingController(text: paymentData['userId'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Payment"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: busIdController, decoration: const InputDecoration(labelText: "Bus ID")),
              TextField(controller: startCityController, decoration: const InputDecoration(labelText: "Start City")),
              TextField(controller: endCityController, decoration: const InputDecoration(labelText: "End City")),
              TextField(controller: totalFareController, decoration: const InputDecoration(labelText: "Total Fare"), keyboardType: TextInputType.number),
              TextField(controller: paymentStatusController, decoration: const InputDecoration(labelText: "Payment Status")),
              TextField(controller: userIdController, decoration: const InputDecoration(labelText: "User ID")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final updatedData = {
                "busId": busIdController.text,
                "startCity": startCityController.text,
                "endCity": endCityController.text,
                "totalFare": int.tryParse(totalFareController.text) ?? 0,
                "paymentStatus": paymentStatusController.text,
                "userId": userIdController.text,
              };
              _updatePayment(paymentId, updatedData);
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Payments")),
      body: _payments.isEmpty
          ? const Center(child: Text("No payments found"))
          : ListView(
        children: _payments.keys.map((paymentId) {
          final payment = Map<String, dynamic>.from(_payments[paymentId]);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text("Bus: ${payment['busId']} | User: ${payment['userId']}"),
              subtitle: Text(
                "Route: ${payment['startCity']} → ${payment['endCity']} | Fare: LKR ${payment['totalFare']} | Status: ${payment['paymentStatus']}",
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _showPaymentDialog(paymentId, payment),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePayment(paymentId),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
