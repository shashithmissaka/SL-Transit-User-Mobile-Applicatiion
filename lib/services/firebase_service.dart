import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final DatabaseReference _busesRef =
  FirebaseDatabase.instance.ref("buses");
  static final DatabaseReference _resRef =
  FirebaseDatabase.instance.ref("reservations");
  static final DatabaseReference _faresRef =
  FirebaseDatabase.instance.ref("fares");

  // 🔹 Get route stops between two cities
  static Future<List<Map<String, dynamic>>> getRouteStops(
      String from, String to) async {
    final busesSnapshot = await _busesRef.get();
    if (!busesSnapshot.exists) return [];

    final buses = Map<String, dynamic>.from(busesSnapshot.value as Map);

    // Find a bus that contains the route
    for (var busEntry in buses.entries) {
      final busData = Map<String, dynamic>.from(busEntry.value);

      if (busData.containsKey("routes") && busData.containsKey("stops")) {
        final routes = List<Map<String, dynamic>>.from(busData["routes"]);
        final stops = List<Map<String, dynamic>>.from(busData["stops"]);

        // Check if this bus has the requested route
        bool routeExists = routes.any((r) =>
        r["from"].toString().toLowerCase() == from.toLowerCase() &&
            r["to"].toString().toLowerCase() == to.toLowerCase());

        if (routeExists) {
          // Return only the stops between 'from' and 'to'
          int fromIndex = stops.indexWhere((s) =>
          s["name"].toString().toLowerCase() == from.toLowerCase());
          int toIndex = stops.indexWhere(
                  (s) => s["name"].toString().toLowerCase() == to.toLowerCase());

          if (fromIndex != -1 && toIndex != -1 && fromIndex < toIndex) {
            return stops.sublist(fromIndex, toIndex + 1);
          } else if (fromIndex != -1 && toIndex != -1 && fromIndex > toIndex) {
            // If the route is reverse direction
            return stops.sublist(toIndex, fromIndex + 1).reversed.toList();
          }
        }
      }
    }

    return [];
  }

  // 🔹 Attach realtime listener for marker updates (reservations + buses)
  static void attachRealtimeListeners(Function callback) {
    _busesRef.onValue.listen((_) => callback());
    _resRef.onValue.listen((_) => callback());
  }

  // 🔹 Get all buses (one-time)
  static Future<Map<String, dynamic>> getBuses() async {
    final snapshot = await _busesRef.get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  // 🔹 Get all reservations (one-time)
  static Future<Map<String, dynamic>> getReservations() async {
    final snapshot = await _resRef.get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  // 🔹 Get fare for a route (one-time)
  static Future<int> getFare(String start, String end) async {
    final snapshot = await _faresRef.child(start).child(end).get();
    if (snapshot.exists) {
      return snapshot.value as int;
    }
    return 0;
  }

  // ✅ NEW: Realtime stream for moving buses
  static Stream<DatabaseEvent> getBusStream() {
    return _busesRef.onValue;
  }
}
