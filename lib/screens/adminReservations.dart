import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  final DatabaseReference _reservationsRef = FirebaseDatabase.instance.ref("reservations");
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref("buses");

  Map<String, dynamic> _reservations = {};
  Map<String, dynamic> _buses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Load reservations
    _reservationsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _reservations = Map<String, dynamic>.from(data);
      });
    });

    // Load buses to get bus numbers
    _busesRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _buses = Map<String, dynamic>.from(data);
      });
    });
  }

  void _deleteReservation(String busId, String seatKey) {
    _reservationsRef.child(busId).child(seatKey).remove();
  }

  void _updateReservation(String busId, String seatKey, Map<String, dynamic> newData) {
    _reservationsRef.child(busId).child(seatKey).update(newData);
  }

  void _showReservationDialog(String busId, String seatKey, Map<dynamic, dynamic> seatData) {
    final startCityController = TextEditingController(text: seatData['startCity'] ?? '');
    final endCityController = TextEditingController(text: seatData['endCity'] ?? '');
    final fareController = TextEditingController(text: seatData['fare']?.toString() ?? '0');
    final statusController = TextEditingController(text: seatData['status'] ?? 'booked');
    final paymentStatusController = TextEditingController(text: seatData['paymentStatus'] ?? 'unpaid');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Reservation - Bus ${_buses[busId]?['busNumber'] ?? busId} | Seat $seatKey"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: startCityController, decoration: const InputDecoration(labelText: "Start City")),
              TextField(controller: endCityController, decoration: const InputDecoration(labelText: "End City")),
              TextField(controller: fareController, decoration: const InputDecoration(labelText: "Fare"), keyboardType: TextInputType.number),
              TextField(controller: statusController, decoration: const InputDecoration(labelText: "Status")),
              TextField(controller: paymentStatusController, decoration: const InputDecoration(labelText: "Payment Status")),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = {
                "startCity": startCityController.text,
                "endCity": endCityController.text,
                "fare": int.tryParse(fareController.text) ?? 0,
                "status": statusController.text,
                "paymentStatus": paymentStatusController.text,
              };

              _updateReservation(busId, seatKey, updatedData);
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
      appBar: AppBar(title: const Text("Admin Reservations")),
      body: _reservations.isEmpty
          ? const Center(child: Text("No reservations found"))
          : ListView(
        children: _reservations.keys.map((busId) {
          final busSeats = _reservations[busId] as Map<dynamic, dynamic>? ?? {};
          final busNumber = _buses[busId]?['busNumber'] ?? busId;

          return ExpansionTile(
            title: Text("Bus: $busNumber"),
            children: busSeats.keys.map((seatKey) {
              final seatData = Map<String, dynamic>.from(busSeats[seatKey]);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text("Seat: $seatKey | ${seatData['status'] ?? 'booked'}"),
                  subtitle: Text(
                    "Route: ${seatData['startCity'] ?? ''} → ${seatData['endCity'] ?? ''} | Fare: LKR ${seatData['fare'] ?? 0} | Payment: ${seatData['paymentStatus'] ?? 'unpaid'}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showReservationDialog(busId, seatKey, seatData),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteReservation(busId, seatKey),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
