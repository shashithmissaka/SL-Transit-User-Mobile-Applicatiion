import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");
  Map<String, dynamic> _users = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    _usersRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _users = Map<String, dynamic>.from(data);
      });
    });
  }

  void _deleteUser(String userId) {
    _usersRef.child(userId).remove();
  }

  void _updateUser(String userId, Map<String, dynamic> newData) {
    _usersRef.child(userId).update(newData);
  }

  void _addUser(String userId, Map<String, dynamic> userData) {
    _usersRef.child(userId).set(userData);
  }

  void _showUserDialog({String? userId, Map<String, dynamic>? userData}) {
    final nameController = TextEditingController(text: userData?['name'] ?? '');
    final emailController = TextEditingController(text: userData?['email'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(userId == null ? "Add User" : "Edit User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newData = {
                "name": nameController.text,
                "email": emailController.text,
              };
              if (userId == null) {
                // Generate new user id
                final newUserId = _usersRef.push().key!;
                _addUser(newUserId, newData);
              } else {
                _updateUser(userId, newData);
              }
              Navigator.pop(context);
            },
            child: Text(userId == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Users"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showUserDialog(),
          )
        ],
      ),
      body: _users.isEmpty
          ? const Center(child: Text("No users found"))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final userId = _users.keys.elementAt(index);
          final user = _users[userId] as Map<dynamic, dynamic>;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(user['name'] ?? ""),
              subtitle: Text(user['email'] ?? ""),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _showUserDialog(userId: userId, userData: Map<String, dynamic>.from(user)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(userId),
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
