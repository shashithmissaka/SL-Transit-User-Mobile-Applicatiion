import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("reservations");
  Map reservations = {};

  @override
  void initState() {
    super.initState();
    fetchReservations();
  }

  Future<void> fetchReservations() async {
    final snap = await dbRef.get();
    if (snap.exists) {
      setState(() {
        reservations = snap.value as Map;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reservations"),
        backgroundColor: Colors.orange,
      ),
      body: reservations.isEmpty
          ? const Center(child: Text("No Reservations Found"))
          : ListView(
        children: reservations.entries.map((busEntry) {
          String busId = busEntry.key;
          Map seats = busEntry.value;

          return Card(
            margin: const EdgeInsets.all(12),
            child: ExpansionTile(
              title: Text("Bus: $busId"),
              children: seats.entries.map((seatEntry) {
                String seatId = seatEntry.key;
                Map seatData = seatEntry.value;

                return ListTile(
                  title: Text("Seat: $seatId"),
                  subtitle: Text(
                    "Status: ${seatData["status"]}, Payment: ${seatData["paymentStatus"]}",
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
