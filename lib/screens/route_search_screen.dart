import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:untitled/services/firebase_service.dart';
import 'package:untitled/screens/seat_reservation_screen.dart';
import 'package:untitled/screens/login_screen.dart';

class RouteSearchScreen extends StatefulWidget {
  final LatLng currentPosition;
  final String userName;

  const RouteSearchScreen({
    super.key,
    required this.currentPosition,
    required this.userName,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  Map<MarkerId, Marker> _markers = {};
  List<Map<String, dynamic>> _availableBuses = [];
  bool _loading = false;
  bool _noBuses = false;

  final List<String> towns = [
    "Kurunegala",
    "Narammala",
    "Mawathagama",
    "Kuliyapitiya",
    "Giriulla"
  ];

  final Map<String, String> townNameMap = {
    "kurunegala": "Kurunegala",
    "narammala": "Narammala",
    "mawathgama": "Mawathagama",
    "kuliyapitiya": "Kuliyapitiya",
    "giriulla": "Giriulla",
  };

  List<String> recentSearches = [];
  StreamSubscription<DatabaseEvent>? _busSubscription;

  @override
  void initState() {
    super.initState();
    fromController.text = ""; // no auto “Current Location”
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "$from → $to";
    if (!recentSearches.contains(key)) {
      recentSearches.insert(0, key);
      if (recentSearches.length > 10) recentSearches.removeLast();
      await prefs.setStringList('recent_searches', recentSearches);
      setState(() {});
    }
  }

  Future<void> _goToSeatReservation(
      String busKey, String from, String to, int availableSeats) async {
    String startCity = townNameMap[from.toLowerCase()] ?? from;
    String endCity = townNameMap[to.toLowerCase()] ?? to;

    int fare = 0;
    try {
      final fareSnapshot =
      await FirebaseDatabase.instance.ref("fares/$startCity-$endCity").get();
      if (fareSnapshot.exists) fare = fareSnapshot.value as int;
    } catch (e) {
      debugPrint("⚠️ Could not fetch fare: $e");
    }

    if (availableSeats > 0) {
      await _saveRecentSearch(startCity, endCity);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeatReservationScreen(
            busId: busKey,
            userId: widget.userName,
            startCity: startCity,
            endCity: endCity,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No seats available on this bus.")),
      );
    }
  }

  Future<void> _searchBuses() async {
    if (fromController.text.isEmpty || toController.text.isEmpty) return;

    String from = fromController.text.trim().toLowerCase();
    String to = toController.text.trim().toLowerCase();

    setState(() {
      _loading = true;
      _availableBuses.clear();
      _markers.clear();
      _noBuses = false;
    });

    try {
      final buses = await FirebaseService.getBuses();
      final reservationsSnapshot =
      await FirebaseDatabase.instance.ref("reservations").get();
      Map reservations =
      reservationsSnapshot.exists ? reservationsSnapshot.value as Map : {};

      List<Map<String, dynamic>> matchedBuses = [];

      for (var entry in buses.entries) {
        final busKey = entry.key;
        final bus = Map<String, dynamic>.from(entry.value);

        if (bus["routes"] != null) {
          bool hasRoute = (bus["routes"] as List).any((r) =>
          r["from"].toString().toLowerCase() == from &&
              r["to"].toString().toLowerCase() == to);

          if (hasRoute) {
            int totalSeats = bus["totalSeats"] ?? 0;
            int bookedSeats = 0;

            if (reservations[busKey] != null) {
              final seatsMap = reservations[busKey] as Map;
              seatsMap.forEach((_, value) {
                if (value["status"] == "booked") bookedSeats++;
              });
            }

            int availableSeats = totalSeats - bookedSeats;

            if (bus["lat"] != null && bus["lng"] != null) {
              final markerId = MarkerId(busKey);
              _markers[markerId] = Marker(
                markerId: markerId,
                position: LatLng(bus["lat"], bus["lng"]),
                onTap: () =>
                    _goToSeatReservation(busKey, from, to, availableSeats),
                infoWindow: InfoWindow(
                  title: bus["busNumber"] ?? busKey,
                  snippet: "Available Seats: $availableSeats",
                  onTap: () =>
                      _goToSeatReservation(busKey, from, to, availableSeats),
                ),
              );
            }

            matchedBuses.add(bus);
          }
        }
      }

      _listenToBusUpdates(from, to, reservations);

      setState(() {
        _loading = false;
        _availableBuses = matchedBuses;
        _noBuses = _availableBuses.isEmpty;
      });
    } catch (e) {
      debugPrint("❌ Error searching buses: $e");
      setState(() {
        _loading = false;
        _noBuses = true;
      });
    }
  }

  void _listenToBusUpdates(String from, String to, Map reservations) {
    _busSubscription?.cancel();
    _busSubscription =
        FirebaseDatabase.instance.ref("buses").onValue.listen((event) {
          if (!event.snapshot.exists) return;

          final buses = Map<String, dynamic>.from(event.snapshot.value as Map);
          Map<MarkerId, Marker> updatedMarkers = {};

          for (var entry in buses.entries) {
            final busKey = entry.key;
            final bus = Map<String, dynamic>.from(entry.value);

            if (bus["routes"] != null) {
              bool hasRoute = (bus["routes"] as List).any((r) =>
              r["from"].toString().toLowerCase() == from &&
                  r["to"].toString().toLowerCase() == to);

              if (hasRoute && bus["lat"] != null && bus["lng"] != null) {
                int totalSeats = bus["totalSeats"] ?? 0;
                int bookedSeats = 0;

                if (reservations[busKey] != null) {
                  final seatsMap = reservations[busKey] as Map;
                  seatsMap.forEach((_, value) {
                    if (value["status"] == "booked") bookedSeats++;
                  });
                }

                int availableSeats = totalSeats - bookedSeats;

                final markerId = MarkerId(busKey);
                updatedMarkers[markerId] = Marker(
                  markerId: markerId,
                  position: LatLng(bus["lat"], bus["lng"]),
                  onTap: () =>
                      _goToSeatReservation(busKey, from, to, availableSeats),
                  infoWindow: InfoWindow(
                    title: bus["busNumber"] ?? busKey,
                    snippet: "Available Seats: $availableSeats",
                    onTap: () =>
                        _goToSeatReservation(busKey, from, to, availableSeats),
                  ),
                );
              }
            }
          }

          setState(() {
            _markers = updatedMarkers;
          });
        });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userEmail');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header row
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Welcome, ${widget.userName}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Search card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top row with back button
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context); // goes back to HomeScreen
                              },
                              icon: const Icon(Icons.arrow_back, color: Colors.black87),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Search Route",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text("From",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: fromController,
                          decoration: const InputDecoration(
                            hintText: "Enter starting location",
                            prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (fromController.text.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView(
                              children: towns
                                  .where((town) => town
                                  .toLowerCase()
                                  .contains(fromController.text.toLowerCase()))
                                  .map((town) => ListTile(
                                title: Text(town),
                                onTap: () {
                                  fromController.text = town;
                                  setState(() {});
                                },
                              ))
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (fromController.text.isNotEmpty) ...[
                          const Text("To",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: toController,
                            decoration: const InputDecoration(
                              hintText: "Enter destination",
                              prefixIcon: Icon(Icons.flag, color: Colors.green),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (toController.text.isNotEmpty)
                            SizedBox(
                              height: 100,
                              child: ListView(
                                children: towns
                                    .where((town) => town
                                    .toLowerCase()
                                    .contains(toController.text.toLowerCase()))
                                    .map((town) => ListTile(
                                  title: Text(town),
                                  onTap: () {
                                    toController.text = town;
                                    setState(() {});
                                  },
                                ))
                                    .toList(),
                              ),
                            ),
                        ],
                        const SizedBox(height: 20),
                        if (fromController.text.isNotEmpty &&
                            toController.text.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _searchBuses,
                            icon: const Icon(Icons.search),
                            label: const Text("Search Buses",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_loading) const LinearProgressIndicator(),

              if (_noBuses)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "No buses available for this route.",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),

              if (_availableBuses.isNotEmpty)
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: widget.currentPosition, zoom: 12),
                    markers: Set<Marker>.of(_markers.values),
                    myLocationEnabled: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
