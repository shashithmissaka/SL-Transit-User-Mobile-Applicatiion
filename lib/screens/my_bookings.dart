import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MyBookingsScreen extends StatefulWidget {
  final String userId;
  const MyBookingsScreen({super.key, required this.userId});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final DatabaseReference _dbReservations =
  FirebaseDatabase.instance.ref("reservations");

  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    _dbReservations.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      List<Map<String, dynamic>> bookings = [];

      data.forEach((busId, seatsData) {
        if (seatsData is Map) {
          seatsData.forEach((seatKey, seatInfo) {
            if (seatInfo is Map) {
              final status = seatInfo["status"]?.toString() ?? "";
              final userId = seatInfo["userId"]?.toString() ?? "";
              final paymentStatus = seatInfo["paymentStatus"]?.toString() ?? "unpaid"; // ✅ read directly

              if (userId == widget.userId && status == "booked") {
                bookings.add({
                  "busId": busId,
                  "seatKey": seatKey,
                  "startCity": seatInfo["startCity"],
                  "endCity": seatInfo["endCity"],
                  "fare": seatInfo["fare"],
                  "bookedAt": seatInfo["bookedAt"],
                  "paymentStatus": paymentStatus, // ✅ fixed
                });
              }
            }
          });
        }
      });

      setState(() {
        _bookings = bookings;
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: _bookings.isEmpty
          ? const Center(child: Text("No bookings found"))
          : ListView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return ListTile(
            title: Text(
                "Bus: ${booking['busId']} | Seat: ${booking['seatKey']}"),
            subtitle: Text(
                "Route: ${booking['startCity']} → ${booking['endCity']} | Fare: LKR ${booking['fare']}"),
            trailing: Text(
              booking['paymentStatus'] == "paid" ? "Paid" : "Unpaid",
              style: TextStyle(
                  color: booking['paymentStatus'] == "paid"
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
