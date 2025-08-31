import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusUtils {
  // 🔹 Build markers for buses
  static Future<Map<MarkerId, Marker>> buildMarkers({
    required Map<String, dynamic> buses,
    required Map<String, dynamic>? reservations,
    String? startCity,
    String? endCity,
    required Function(String busId, int availableSeats) onBusTap,
  }) async {
    Map<MarkerId, Marker> markers = {};

    for (var entry in buses.entries) {
      final busId = entry.key;
      final busData = entry.value;

      // 🔹 Filter by route if start and end city provided
      if (startCity != null && endCity != null) {
        final routes = busData['routes'] as List<dynamic>;
        bool match = routes.any((r) =>
        r['from'].toString().toLowerCase() ==
            startCity.toLowerCase() &&
            r['to'].toString().toLowerCase() ==
                endCity.toLowerCase());
        if (!match) continue;
      }

      // 🔹 Count available seats
      int availableSeats = busData['totalSeats'] ?? 10;
      if (reservations != null && reservations[busId] != null) {
        final seatsMap = reservations[busId] as Map<dynamic, dynamic>;
        availableSeats = seatsMap.values
            .where((seat) => seat["status"] == "available")
            .length;
      }

      // 🔹 Choose marker icon based on seats
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

      final markerId = MarkerId(busId);
      markers[markerId] = Marker(
        markerId: markerId,
        position: LatLng(busData['lat'], busData['lng']),
        icon: busIcon,
        infoWindow: InfoWindow(
          title: "Bus $busId",
          snippet: "Seats: $availableSeats/${busData['totalSeats']}",
          onTap: () => onBusTap(busId, availableSeats),
        ),
      );
    }

    return markers;
  }
}
