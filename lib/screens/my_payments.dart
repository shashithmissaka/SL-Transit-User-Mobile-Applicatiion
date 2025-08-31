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
  int _totalPaid = 0; // ✅ total paid amount

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    _dbReservations.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      List<Map<String, dynamic>> payments = [];
      int total = 0; // temporary total

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
                total += int.tryParse(seatInfo["fare"]?.toString() ?? "0") ?? 0; // sum fare
              }
            }
          });
        }
      });

      // ✅ sort payments by paidAt (newest first)
      payments.sort((a, b) => (b['paidAt'] ?? 0).compareTo(a['paidAt'] ?? 0));

      setState(() {
        _payments = payments;
        _totalPaid = total; // update total paid
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Payments")),
      body: _payments.isEmpty
          ? const Center(child: Text("No payments found"))
          : Column(
        children: [
          // ✅ Total paid amount
          Container(
            width: double.infinity,
            color: Colors.blueGrey[50],
            padding: const EdgeInsets.all(12),
            child: Text(
              "Total Paid: LKR $_totalPaid",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _payments.length,
              itemBuilder: (context, index) {
                final payment = _payments[index];
                final date = DateTime.fromMillisecondsSinceEpoch(payment['paidAt']);

                // ✅ Highlight the latest payment (first item in list)
                final bool isLatest = index == 0;

                return Card(
                  color: isLatest ? Colors.deepPurple[100] : null, // highlight latest
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      "Bus: ${payment['busId']} | Seat: ${payment['seatKey']}",
                      style: TextStyle(
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                        color: isLatest ? Colors.deepPurple[900] : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      "Route: ${payment['startCity']} → ${payment['endCity']} | Fare: LKR ${payment['fare']}",
                      style: TextStyle(
                        color: isLatest ? Colors.deepPurple[700] : Colors.black87,
                      ),
                    ),
                    trailing: Text(
                      "${date.day}/${date.month}/${date.year} "
                          "${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                        color: isLatest ? Colors.deepPurple : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
