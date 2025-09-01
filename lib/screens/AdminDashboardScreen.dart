import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'ReservationsScreen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalBuses = 0;
  int totalReservations = 0;
  int totalPayments = 0;

  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    // 🔹 Buses
    final busesSnap = await dbRef.child("buses").get();
    if (busesSnap.exists) {
      setState(() {
        totalBuses = (busesSnap.value as Map).length;
      });
    }

    // 🔹 Reservations
    final reservationsSnap = await dbRef.child("reservations").get();
    if (reservationsSnap.exists) {
      int resCount = 0;
      (reservationsSnap.value as Map).forEach((busId, seats) {
        resCount += (seats as Map).length;
      });
      setState(() {
        totalReservations = resCount;
      });
    }

    // 🔹 Payments
    final paymentsSnap = await dbRef.child("payments").get();
    if (paymentsSnap.exists) {
      int paidCount = 0;
      (paymentsSnap.value as Map).forEach((key, value) {
        if (value["paymentStatus"] == "paid") {
          paidCount++;
        }
      });
      setState(() {
        totalPayments = paidCount;
      });
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blue,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard("Buses", totalBuses.toString(), Colors.blue),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReservationsScreen()),
                );
              },
              child: _buildStatCard("Reservations", totalReservations.toString(), Colors.orange),
            ),
            _buildStatCard("Payments", totalPayments.toString(), Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
