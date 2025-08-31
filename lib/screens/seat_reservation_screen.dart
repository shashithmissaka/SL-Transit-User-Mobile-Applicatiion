import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:untitled/screens/PaymentScreen.dart';
import 'package:untitled/screens/my_bookings.dart';

/// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class SeatReservationScreen extends StatefulWidget {
  final String busId; // bus unique ID
  final String userId; // logged in user ID
  final String startCity;
  final String endCity;

  const SeatReservationScreen({
    super.key,
    required this.busId,
    required this.userId,
    required this.startCity,
    required this.endCity,
  });

  @override
  State<SeatReservationScreen> createState() => _SeatReservationScreenState();
}

class _SeatReservationScreenState extends State<SeatReservationScreen> {
  final DatabaseReference _dbReservations =
  FirebaseDatabase.instance.ref("reservations");
  final DatabaseReference _dbFares = FirebaseDatabase.instance.ref("fares");

  Map<String, dynamic> _seats = {}; // seatNo -> seat data
  Set<String> _selectedSeats = {}; // seats user picked before confirm
  int _farePerSeat = 0; // fetched dynamically from DB
  static const int totalSeats = 10; // total seats per bus

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _loadFare();
    _initializeSeats();
  }

  /// 🔔 Setup local + push notifications
  void _setupNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bus_channel',
      'Bus Notifications',
      description: 'Notifications for bus seat booking',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          message.notification!.hashCode,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'bus_channel',
              'Bus Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  /// 🔹 Load fare from DB according to startCity → endCity
  void _loadFare() async {
    final routeKey = "${widget.startCity}-${widget.endCity}";
    print("Fetching fare for route: $routeKey");

    final snapshot = await _dbFares.child(routeKey).get();
    if (snapshot.exists) {
      setState(() {
        _farePerSeat = int.tryParse(snapshot.value.toString()) ?? 0;
      });
      print("Fare fetched: $_farePerSeat");
    } else {
      setState(() {
        _farePerSeat = 0;
      });
      print("! Fare not found in database for route $routeKey");
    }
  }

  /// 🎫 Load or initialize seat data
  void _initializeSeats() async {
    _dbReservations.child(widget.busId).onValue.listen((event) async {
      if (event.snapshot.value != null) {
        final Map<String, dynamic> seatsData = Map<String, dynamic>.from(
            event.snapshot.value as Map? ?? {});

        // Merge paid info if numeric keys exist
        seatsData.forEach((key, value) {
          if (key != "seat1" && int.tryParse(key) != null && value is Map) {
            // numeric keys store payment info
            seatsData.forEach((seatKey, seatInfo) {
              if (seatInfo is Map && seatInfo["userId"] != null) {
                // attach paymentStatus & paidAt
                if (seatInfo["userId"] == value["userId"]) {
                  seatInfo["paymentStatus"] = value["paymentStatus"];
                  seatInfo["paidAt"] = value["paidAt"];
                }
              }
            });
          }
        });

        setState(() {
          _seats = seatsData;
        });
      } else {
        // Initialize seats
        Map<String, dynamic> initSeats = {};
        for (int i = 1; i <= totalSeats; i++) {
          initSeats["seat$i"] = {"status": "available"};
        }
        await _dbReservations.child(widget.busId).set(initSeats);
        setState(() {
          _seats = initSeats;
        });
      }
    });
  }


  /// 🪑 Select/unselect a seat
  void _toggleSeatSelection(String seatKey) {
    final seatData = _seats[seatKey] ?? {"status": "available"};
    final status = (seatData["status"] ?? "available").toString();
    final seatOwnerId = seatData["userId"]?.toString();
    final paymentStatus = seatData["paymentStatus"]?.toString() ?? "unpaid";

    if (status == "available") {
      setState(() {
        if (_selectedSeats.contains(seatKey)) {
          _selectedSeats.remove(seatKey);
        } else {
          _selectedSeats.add(seatKey);
        }
      });
    } else if (seatOwnerId == widget.userId) {
      if (paymentStatus == "paid") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot cancel a seat after payment")),
        );
        return;
      }
      // Cancel booking if unpaid
      _dbReservations.child("${widget.busId}/$seatKey")
          .set({"status": "available"});
      _showLocalNotification("Seat Cancelled", "You cancelled $seatKey");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seat already booked")),
      );
    }
  }

  /// ✅ Confirm booking and navigate to PaymentScreen
  Future<void> _confirmBooking() async {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No seats selected")),
      );
      return;
    }

    List<String> bookedSeats = [];

    for (String seatKey in _selectedSeats) {
      final seatRef = _dbReservations.child("${widget.busId}/$seatKey");
      final seatSnapshot = await seatRef.get();
      final status =
          seatSnapshot.child("status").value?.toString() ?? "available";

      if (status == "available") {
        await seatRef.set({
          "status": "booked",
          "userId": widget.userId,
          "startCity": widget.startCity,
          "endCity": widget.endCity,
          "fare": _farePerSeat,
          "bookedAt": DateTime.now().millisecondsSinceEpoch,
        });
        bookedSeats.add(seatKey.replaceAll("seat", ""));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$seatKey was already booked")),
        );
      }
    }

    _showLocalNotification(
      "Booking Confirmed",
      "You booked ${bookedSeats.join(",")} for LKR ${_farePerSeat * bookedSeats.length}",
    );

    setState(() {
      _selectedSeats.clear();
    });

    // Navigate to PaymentScreen with route info
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          busId: widget.busId,
          userId: widget.userId,
          bookedSeats: bookedSeats,
          totalFare: _farePerSeat * bookedSeats.length,
          startCity: widget.startCity,
          endCity: widget.endCity,
        ),
      ),
    );
  }

  /// 🔔 Local notification
  void _showLocalNotification(String title, String body) {
    flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bus_channel',
          'Bus Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// 🎨 Seat colors
  Color _getSeatColor(String seatKey, Map seatData) {
    final status = (seatData["status"] ?? "").toString();
    final seatOwnerId = seatData["userId"]?.toString() ?? "";
    final paymentStatus = seatData["paymentStatus"]?.toString() ?? "unpaid";

    print("Seat $seatKey, Status: $status, PaymentStatus: $paymentStatus");

    if (_selectedSeats.contains(seatKey)) return Colors.yellow;
    if (status == "available") return Colors.green;
    if (seatOwnerId == widget.userId && paymentStatus == "paid") return Colors.purple; // paid by user
    if (seatOwnerId == widget.userId) return Colors.blue; // booked but unpaid
    return Colors.red; // booked by someone else
  }



  /// ✅ Get seats booked by this user
  /// ✅ Get seats booked by this user (including paid)
  String _getBookedSeats() {
    List<String> bookedSeats = [];
    _seats.forEach((key, value) {
      if (value is Map) {
        final userId = value["userId"]?.toString();
        final status = value["status"]?.toString() ?? "";
        final paymentStatus = value["paymentStatus"]?.toString() ?? "unpaid";

        if (userId == widget.userId && (status == "booked" || paymentStatus == "paid")) {
          bookedSeats.add(key.replaceAll("seat", ""));
        }
      }
    });
    return bookedSeats.isEmpty ? "-" : bookedSeats.join(",");
  }

  /// 💰 Calculate total fare for seats already booked by this user
  int _calculateTotalFare() {
    int total = 0;
    _seats.forEach((key, value) {
      if (value is Map) {
        final userId = value["userId"]?.toString();
        final status = value["status"]?.toString() ?? "";
        final paymentStatus = value["paymentStatus"]?.toString() ?? "unpaidvoi";
        final fare = int.tryParse(value["fare"]?.toString() ?? "0") ?? 0;

        if (userId == widget.userId && (status == "booked" || paymentStatus == "paid")) {
          total += fare;
        }
      }
    });
    return total;
  }

  /// 🖼 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Bus ${widget.busId} | Seats: ${_getBookedSeats()} | Fare: LKR ${_calculateTotalFare()}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: "My Bookings",
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MyBookingsScreen(userId: widget.userId)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _seats.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
              children: [
                // Seat grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: totalSeats,
                    itemBuilder: (context, index) {
                      String seatNo = "seat${index + 1}";
                      Map seatData =
                          _seats[seatNo] ?? {"status": "available"};

                      return GestureDetector(
                        onTap: () => _toggleSeatSelection(seatNo),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getSeatColor(seatNo, seatData),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Legend row
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      LegendBox(color: Colors.green, label: "Available"),
                      LegendBox(color: Colors.yellow, label: "Selected"),
                      LegendBox(color: Colors.blue, label: "Booked"),
                      LegendBox(color: Colors.purple, label: "Paid"),
                      LegendBox(color: Colors.red, label: "Other User"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Confirm booking button
          if (_selectedSeats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: _confirmBooking,
                icon: const Icon(Icons.check),
                label: Text(
                  "Confirm Booking (${_selectedSeats.length} seats | Total: LKR ${_farePerSeat * _selectedSeats.length})",
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// LegendBox widget
class LegendBox extends StatelessWidget {
  final Color color;
  final String label;
  const LegendBox({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 20, height: 20, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
