import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminBusesScreen extends StatefulWidget {
  const AdminBusesScreen({super.key});

  @override
  State<AdminBusesScreen> createState() => _AdminBusesScreenState();
}

class _AdminBusesScreenState extends State<AdminBusesScreen> {
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref("buses");
  Map<String, dynamic> _buses = {};

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  void _loadBuses() {
    _busesRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _buses = Map<String, dynamic>.from(data);
      });
    });
  }

  void _deleteBus(String busId) {
    _busesRef.child(busId).remove();
  }

  void _updateBus(String busId, Map<String, dynamic> newData) {
    _busesRef.child(busId).update(newData);
  }

  void _addBus(Map<String, dynamic> busData) {
    final newBusId = _busesRef.push().key!;
    _busesRef.child(newBusId).set(busData);
  }

  void _showBusDialog({String? busId, Map<String, dynamic>? busData}) {
    final busNumberController = TextEditingController(text: busData?['busNumber'] ?? '');
    final totalSeatsController = TextEditingController(text: busData?['totalSeats']?.toString() ?? '');
    final latController = TextEditingController(text: busData?['lat']?.toString() ?? '');
    final lngController = TextEditingController(text: busData?['lng']?.toString() ?? '');

    // Routes as a simple comma-separated "from-to" string
    final routesController = TextEditingController(
      text: busData?['routes'] != null
          ? (busData!['routes'] as List)
          .map((r) => "${r['from']}-${r['to']}")
          .join(", ")
          : '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(busId == null ? "Add Bus" : "Edit Bus"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: busNumberController, decoration: const InputDecoration(labelText: "Bus Number")),
              TextField(controller: totalSeatsController, decoration: const InputDecoration(labelText: "Total Seats"), keyboardType: TextInputType.number),
              TextField(controller: latController, decoration: const InputDecoration(labelText: "Latitude"), keyboardType: TextInputType.number),
              TextField(controller: lngController, decoration: const InputDecoration(labelText: "Longitude"), keyboardType: TextInputType.number),
              TextField(controller: routesController, decoration: const InputDecoration(labelText: "Routes (from-to, comma separated)")),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final routesList = routesController.text.split(",").map((e) {
                final parts = e.split("-");
                return {"from": parts[0].trim(), "to": parts[1].trim()};
              }).toList();

              final newData = {
                "busNumber": busNumberController.text,
                "totalSeats": int.tryParse(totalSeatsController.text) ?? 10,
                "lat": double.tryParse(latController.text) ?? 0.0,
                "lng": double.tryParse(lngController.text) ?? 0.0,
                "routes": routesList,
              };

              if (busId == null) {
                _addBus(newData);
              } else {
                _updateBus(busId, newData);
              }
              Navigator.pop(context);
            },
            child: Text(busId == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Buses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showBusDialog(),
          )
        ],
      ),
      body: _buses.isEmpty
          ? const Center(child: Text("No buses found"))
          : ListView.builder(
        itemCount: _buses.length,
        itemBuilder: (context, index) {
          final busId = _buses.keys.elementAt(index);
          final bus = _buses[busId] as Map<dynamic, dynamic>;
          final routes = bus['routes'] as List<dynamic>? ?? [];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(bus['busNumber'] ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Seats: ${bus['totalSeats'] ?? 0}"),
                  Text("Routes: ${routes.map((r) => "${r['from']}→${r['to']}").join(", ")}"),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _showBusDialog(busId: busId, busData: Map<String, dynamic>.from(bus)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBus(busId),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
