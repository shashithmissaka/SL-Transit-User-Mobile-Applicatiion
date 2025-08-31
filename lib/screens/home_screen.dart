import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:untitled/services/firebase_service.dart';
import 'package:untitled/utils/bus_utils.dart';
import 'route_search_screen.dart';
import 'bus_details_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  Map<MarkerId, Marker> _markers = {};
  Set<Polyline> _polylines = {};

  String? startCity;
  String? endCity;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    FirebaseService.attachRealtimeListeners(_refreshMarkers);
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _refreshMarkers({String? from, String? to}) async {
    final buses = await FirebaseService.getBuses();
    final reservations = await FirebaseService.getReservations();

    final newMarkers = await BusUtils.buildMarkers(
      buses: buses,
      reservations: reservations,
      startCity: from,
      endCity: to,
      onBusTap: (busId, availableSeats) async {
        if (from == null || to == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Tap 'Where to?' and select your route.")),
          );
          return;
        }

        if (availableSeats > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusDetailsScreen(busId: busId),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No seats available on this bus.")),
          );
        }
      },
    );

    Set<Polyline> polylines = {};
    if (from != null && to != null) {
      final routeStops = await FirebaseService.getRouteStops(from, to);
      if (routeStops.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            color: Colors.white,
            width: 5,
            points: routeStops.map((s) => LatLng(s["lat"], s["lng"])).toList(),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
      _polylines = polylines;
      startCity = from;
      endCity = to;
    });
  }

  void _onSearchTap() async {
    if (_currentPosition == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSearchScreen(
          currentPosition: _currentPosition!,
          userName: widget.userName, // ✅ pass it down
        ),
      ),
    );

    if (result != null && result is Map<String, String>) {
      String from = result["from"]!;
      String to = result["to"]!;
      _refreshMarkers(from: from, to: to);
    }
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
      // Gradient background
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
              // Top AppBar area
              // This is a comment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        icon: const Icon(Icons.logout, color: Colors.white))
                  ],
                ),
              ),
              // Modern "Where to?" search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: _onSearchTap,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.grey),
                        SizedBox(width: 12),
                        Text(
                          "Where to?",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Google Map container
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _currentPosition == null
                      ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ))
                      : GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: _currentPosition!, zoom: 12),
                    myLocationEnabled: true,
                    markers: Set<Marker>.of(_markers.values),
                    polylines: _polylines,
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
