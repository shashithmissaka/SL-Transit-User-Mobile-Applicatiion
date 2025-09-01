import 'dart:ui'; // for ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final int style; // 1 = Background Image, 2 = Glassmorphism, 3 = Side Panel
  const RegisterScreen({super.key, this.style = 1});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await userCredential.user
          ?.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful!...")),
      );

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
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
              image: AssetImage("assets/bg_register.jpg"), // 👈 your background
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.4)),
        Center(child: _formCard()),
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
                "assets/register_illustration.png", // 👈 your illustration
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
          controller: _nameController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "Name",
            labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
            prefixIcon: Icon(Icons.person, color: textColor.withOpacity(0.8)),
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
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
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
            onPressed: _loading ? null : _register,
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
                : const Text("Register", style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: Text(
            "Already have an account? Login",
            style: TextStyle(color: isGlass ? Colors.white70 : Colors.blue),
          ),
        ),
      ],
    );
  }

  // 🔹 Card wrapper for background style
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
