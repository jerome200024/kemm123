import 'package:flutter/material.dart';

class SignupForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String? errorText;
  final VoidCallback onSignup;
  final VoidCallback onLoginRedirect;
  final Function(String) onPasswordChanged;

  const SignupForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.errorText,
    required this.onSignup,
    required this.onLoginRedirect,
    required this.onPasswordChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        TextFormField(
          controller: emailController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person),
            hintText: 'Email',
            fillColor: Colors.grey[200],
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          onChanged: onPasswordChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock),
            hintText: 'Password',
            fillColor: Colors.grey[200],
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock),
            hintText: 'Confirm Password',
            fillColor: Colors.grey[200],
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            errorText: errorText,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onSignup,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1EE875),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
          ),
          child: const Text(
            "SIGN UP",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Already have an account?"),
            TextButton(
              onPressed: onLoginRedirect,
              child: const Text(
                "Login",
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
            ),
          ],
        )
      ],
    );
  }
}
