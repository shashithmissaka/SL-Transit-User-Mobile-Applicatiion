import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

class BusDetailsScreen extends StatefulWidget {
  final String busId;   // passed from HomeScreen

  const BusDetailsScreen({super.key, required this.busId});

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _stops = [];

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadBusStops();
  }

  /// 1. Load bus stops from Firebase
  Future<void> _loadBusStops() async {
    DataSnapshot snapshot = await _dbRef.child("buses/${widget.busId}/stops").get();

    if (snapshot.exists) {
      List stops = snapshot.value as List;
      _stops = stops.map((s) => Map<String, dynamic>.from(s)).toList();

      _addStopMarkers();
      _drawRoute();
    }
  }

  /// 2. Add markers for each stop
  void _addStopMarkers() {
    Set<Marker> markers = {};

    for (var stop in _stops) {
      markers.add(
        Marker(
          markerId: MarkerId(stop["name"]),
          position: LatLng(stop["lat"], stop["lng"]),
          infoWindow: InfoWindow(title: stop["name"]),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  /// 3. Fetch route using Google Directions API
  Future<void> _drawRoute() async {
    if (_stops.length < 2) return;

    String origin = "${_stops.first['lat']},${_stops.first['lng']}";
    String destination = "${_stops.last['lat']},${_stops.last['lng']}";

    String waypoints = _stops.sublist(1, _stops.length - 1)
        .map((s) => "${s['lat']},${s['lng']}")
        .join('|');

    String url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=$origin&destination=$destination&waypoints=$waypoints&key=AIzaSyCmOeWDA-aESTO8GyFpa1cEgXSB9o96aSA";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);

      if (data["routes"].isNotEmpty) {
        var points = data["routes"][0]["overview_polyline"]["points"];
        List<LatLng> polylineCoords = _decodePolyline(points);

        setState(() {
          _polylines = {
            Polyline(
              polylineId: PolylineId("route"),
              points: polylineCoords,
              color: Colors.blue,
              width: 5,
            )
          };
        });

        // Move camera to first stop
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_stops.first["lat"], _stops.first["lng"]),
            10,
          ),
        );
      }
    }
  }

  /// Polyline decode helper
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bus Route - ${widget.busId}")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(7.8731, 80.7718),
          zoom: 7,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _markers,
        polylines: _polylines,
      ),
    );
  }
}
