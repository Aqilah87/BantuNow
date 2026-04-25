// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import '../main_screen.dart';
import '../location/select_location_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _checkAndNavigate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userArea = prefs.getString('user_area_id');
    if (!mounted) return;
    if (userArea == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success']) {
      await _checkAndNavigate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success']) {
      await _checkAndNavigate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      // ✅ Tiada AppBar — tiada back arrow langsung
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        size: 50, color: AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Welcome Back!',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text('Sign in to continue helping your community',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textGrey)),
                const SizedBox(height: 40),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter your email';
                    if (!value.contains('@'))
                      return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textGrey),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter your password';
                    if (value.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Forgot Password?',
                        style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                    text: 'Login',
                    onPressed: _login,
                    isLoading: _isLoading),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: AppColors.lightGrey)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR',
                          style:
                              TextStyle(color: AppColors.textGrey)),
                    ),
                    Expanded(
                        child: Divider(color: AppColors.lightGrey)),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: BorderSide(color: AppColors.lightGrey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 24,
                          height: 24),
                      const SizedBox(width: 12),
                      Text('Continue with Google',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style:
                            TextStyle(color: AppColors.textGrey)),
                    TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignUpScreen())),
                      child: Text('Sign Up',
                          style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}