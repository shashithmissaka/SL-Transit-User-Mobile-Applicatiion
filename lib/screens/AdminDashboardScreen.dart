import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'adminUsers.dart';
import 'adminBuses.dart';
import 'adminReservations.dart';
import 'adminPayments.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _usersCount = 0;
  int _busesCount = 0;
  int _reservationsCount = 0;
  int _paymentsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    // 🔹 Users
    final usersSnap = await FirebaseDatabase.instance.ref("users").get();
    final usersCount = (usersSnap.value as Map?)?.length ?? 0;

    // 🔹 Buses
    final busesSnap = await FirebaseDatabase.instance.ref("buses").get();
    final busesCount = (busesSnap.value as Map?)?.length ?? 0;

    // 🔹 Reservations & Payments
    final reservationsSnap = await FirebaseDatabase.instance.ref("reservations").get();
    final reservationsData = reservationsSnap.value as Map? ?? {};
    int reservationsCount = 0;
    int paymentsCount = 0;

    reservationsData.forEach((busId, seatsData) {
      if (seatsData is Map) {
        seatsData.forEach((seatKey, seatInfo) {
          if (seatInfo is Map) {
            reservationsCount++;
            if ((seatInfo['paymentStatus'] ?? '') == 'paid') {
              paymentsCount++;
            }
          }
        });
      }
    });

    setState(() {
      _usersCount = usersCount;
      _busesCount = busesCount;
      _reservationsCount = reservationsCount;
      _paymentsCount = paymentsCount;
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Widget _buildStatCard(String title, int count, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          color: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatCard("Users", _usersCount, Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
                }),
                const SizedBox(width: 8),
                _buildStatCard("Buses", _busesCount, Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBusesScreen()));

                }),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatCard("Reservations", _reservationsCount, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReservationsScreen()));

                }),
                const SizedBox(width: 8),
                _buildStatCard("Payments", _paymentsCount, Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()));

                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
