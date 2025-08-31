import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:untitled/screens/my_payments.dart';

class PaymentScreen extends StatefulWidget {
  final String busId;
  final String userId;
  final List<String> bookedSeats;
  final int totalFare;
  final String startCity;
  final String endCity;

  const PaymentScreen({
    super.key,
    required this.busId,
    required this.userId,
    required this.bookedSeats,
    required this.totalFare,
    required this.startCity,
    required this.endCity,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final DatabaseReference _dbReservations = FirebaseDatabase.instance.ref("reservations");
  final DatabaseReference _dbPayments = FirebaseDatabase.instance.ref("payments");
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _listenToSeatUpdates();  // Listen for updates to seats
  }

  // Listen to real-time updates to seat payment status
  void _listenToSeatUpdates() {
    _dbReservations.child(widget.busId).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final Map<String, dynamic> seatsData = Map<String, dynamic>.from(
            event.snapshot.value as Map? ?? {});

        print("Updated seats data: $seatsData");

        // After data changes, force UI update
        setState(() {
          widget.bookedSeats.clear(); // Clear and refresh the bookedSeats
          seatsData.forEach((key, value) {
            if (value["paymentStatus"] == "paid") {
              widget.bookedSeats.add(key.replaceAll("seat", ""));
            }
          });
        });
      }
    });
  }




  // In the _processPayment function
  Future<void> _processPayment() async {
    setState(() => _isPaying = true);

    await Future.delayed(const Duration(seconds: 2)); // simulate payment delay

    // ✅ Update Firebase: mark seats as paid
    for (String seatKey in widget.bookedSeats) {
      final seatRef = _dbReservations.child("${widget.busId}/$seatKey");
      final seatSnapshot = await seatRef.get();

      if (seatSnapshot.exists && seatSnapshot.child("status").value == "booked") {
        print("Seat $seatKey is booked. Updating payment status...");

        // Update the payment status and paidAt timestamp for each booked seat
        await seatRef.update({
          "paymentStatus": "paid", // Update payment status to paid
          "paidAt": DateTime.now().millisecondsSinceEpoch, // Store the payment timestamp
        });

        print("Updated seat $seatKey as paid");
      } else {
        print("Seat $seatKey is not booked or does not exist.");
      }
    }

    // ✅ Save payment details under /payments
    final paymentId = _dbPayments.push().key;
    if (paymentId != null) {
      await _dbPayments.child(paymentId).set({
        "userId": widget.userId,
        "busId": widget.busId,
        "startCity": widget.startCity,
        "endCity": widget.endCity,
        "bookedSeats": widget.bookedSeats,
        "totalFare": widget.totalFare,
        "paidAt": DateTime.now().millisecondsSinceEpoch,
      });
      print("Payment saved under payments/$paymentId");
    }

    setState(() => _isPaying = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Successful!")),
    );

    Navigator.pop(context, true); // return to SeatReservationScreen
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        actions: [
          IconButton(
            icon: const Icon(Icons.payment),
            tooltip: "My Payments",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MyPaymentsScreen(userId: widget.userId)));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bus: ${widget.busId}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              "Route: ${widget.startCity} → ${widget.endCity}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text("Seats: ${widget.bookedSeats.join(", ")}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Total Fare: LKR ${widget.totalFare}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            _isPaying
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _processPayment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Pay Now"),
            ),
          ],
        ),
      ),
    );
  }
}
