import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MyPaymentsScreen extends StatefulWidget {
  final String userId;
  const MyPaymentsScreen({super.key, required this.userId});

  @override
  State<MyPaymentsScreen> createState() => _MyPaymentsScreenState();
}

class _MyPaymentsScreenState extends State<MyPaymentsScreen> {
  final DatabaseReference _dbReservations =
  FirebaseDatabase.instance.ref("reservations");

  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    _dbReservations.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      List<Map<String, dynamic>> payments = [];

      data.forEach((busId, seatsData) {
        if (seatsData is Map) {
          seatsData.forEach((seatKey, seatInfo) {
            if (seatInfo is Map) {
              final userId = seatInfo["userId"]?.toString() ?? "";
              final paymentStatus = seatInfo["paymentStatus"]?.toString() ?? "unpaid";
              if (userId == widget.userId && paymentStatus == "paid") {
                payments.add({
                  "busId": busId,
                  "seatKey": seatKey,
                  "startCity": seatInfo["startCity"],
                  "endCity": seatInfo["endCity"],
                  "fare": seatInfo["fare"],
                  "paidAt": seatInfo["paidAt"],
                });
              }
            }
          });
        }
      });

      setState(() {
        _payments = payments;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Payments")),
      body: _payments.isEmpty
          ? const Center(child: Text("No payments found"))
          : ListView.builder(
        itemCount: _payments.length,
        itemBuilder: (context, index) {
          final payment = _payments[index];
          final date = DateTime.fromMillisecondsSinceEpoch(payment['paidAt']);
          return ListTile(
            title: Text(
                "Bus: ${payment['busId']} | Seat: ${payment['seatKey']}"),
            subtitle: Text(
                "Route: ${payment['startCity']} → ${payment['endCity']} | Fare: LKR ${payment['fare']}"),
            trailing: Text(
                "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}"),
          );
        },
      ),
    );
  }
}
