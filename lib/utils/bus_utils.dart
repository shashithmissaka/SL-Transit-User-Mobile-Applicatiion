import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class BusUtils {
  static Future<Map<MarkerId, Marker>> buildMarkers({
    required Map<dynamic, dynamic> buses,
    required Map<dynamic, dynamic> reservations,
    required String? startCity,
    required String? endCity,
    required Function(String busId, int availableSeats) onBusTap,
  }) async {
    Map<MarkerId, Marker> newMarkers = {};

    for (var entry in buses.entries) {
      final busId = entry.key;
      final busData = entry.value;

      double lat = busData["lat"];
      double lng = busData["lng"];

      // destinations
      List<String> busDestinations = [];
      final destData = busData['destinations'];
      if (destData is List) {
        busDestinations = destData.cast<String>();
      } else if (destData is String) {
        busDestinations = destData.split(',').map((s) => s.trim()).toList();
      }

      // available seats
      int availableSeats = 10;
      if (reservations[busId] != null) {
        final seatsMap = reservations[busId] as Map<dynamic, dynamic>;
        availableSeats = seatsMap.values
            .where((seat) => seat["status"] == "available")
            .length;
      }

      // choose icon
      String iconPath;
      if (availableSeats == 0) {
        iconPath = 'assets/images/bus2.png';
      } else if (availableSeats <= 2) {
        iconPath = 'assets/images/bus1.png';
      } else {
        iconPath = 'assets/images/bus3.png';
      }

      final busIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(10, 10)),
        iconPath,
      );

      // filter by route
      if (startCity != null && endCity != null) {
        int startIndex = busDestinations.indexOf(startCity);
        int endIndex = busDestinations.indexOf(endCity);
        if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
          continue;
        }
      }

      final markerId = MarkerId(busId);
      final marker = Marker(
        markerId: markerId,
        position: LatLng(lat, lng),
        icon: busIcon,
        infoWindow: InfoWindow(
          title: "Bus $busId",
          snippet: "Seats Available: $availableSeats/10",
          onTap: () => onBusTap(busId, availableSeats),
        ),
      );

      newMarkers[markerId] = marker;
    }

    return newMarkers;
  }
}
