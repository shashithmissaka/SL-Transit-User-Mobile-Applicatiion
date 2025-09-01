import 'dart:ui'; // for ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final int style; // 1 = Background Image, 2 = Glassmorphism, 3 = Side Panel
  const LoginScreen({super.key, this.style = 1});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String username =
          userCredential.user?.displayName ?? _emailController.text.trim();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: username)),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.message}")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // 🔹 Template 1: Background Image Style
  Widget _buildBackgroundImageStyle() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/bg_login.jpg"), // your image
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.4)),
        Center(
          child: _formCard(),
        ),
      ],
    );
  }

  // 🔹 Template 2: Glassmorphism Style
  Widget _buildGlassmorphismStyle() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              width: 330,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: _formFields(textColor: Colors.white, isGlass: true),
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Template 3: Side Panel Illustration Style
  Widget _buildSidePanelStyle() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            color: const Color(0xFF2575FC),
            child: Center(
              child: Image.asset(
                "assets/login_illustration.png", // your illustration
                fit: BoxFit.contain,
                width: 250,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: _formFields(),
          ),
        ),
      ],
    );
  }

  // 🔹 Shared form fields
  Widget _formFields({Color textColor = Colors.black, bool isGlass = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "Email",
            labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
            prefixIcon: Icon(Icons.email, color: textColor.withOpacity(0.8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textColor.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textColor),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "Password",
            labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
            prefixIcon: Icon(Icons.lock, color: textColor.withOpacity(0.8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textColor.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textColor),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: isGlass ? Colors.white : const Color(0xFF2575FC),
              foregroundColor: isGlass ? Colors.blue : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? CircularProgressIndicator(
              color: isGlass ? Colors.blue : Colors.white,
            )
                : const Text("Login", style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: Text(
            "Don't have an account? Register",
            style: TextStyle(color: isGlass ? Colors.white70 : Colors.blue),
          ),
        ),
      ],
    );
  }

  // 🔹 Shared card wrapper for background style
  Widget _formCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _formFields(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (widget.style) {
      case 2:
        content = _buildGlassmorphismStyle();
        break;
      case 3:
        content = _buildSidePanelStyle();
        break;
      default:
        content = _buildBackgroundImageStyle();
    }

    return Scaffold(body: content);
  }
}
