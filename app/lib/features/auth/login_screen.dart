import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/services/auth_service.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = const AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_authService.isConfigured) {
      await _runAuthAction(() async {});
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce correo y contrasena')),
      );
      return;
    }

    await _runAuthAction(() => _authService.signInWithEmail(email: email, password: password));
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_authService.isConfigured) {
      await _signIn();
      return;
    }

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contrasena debe tener al menos 6 caracteres')),
      );
      return;
    }

    await _runAuthAction(() => _authService.signUpWithEmail(email: email, password: password));
  }

  Future<void> _signInWithGoogle() async {
    if (!_authService.isConfigured) {
      await _signIn();
      return;
    }
    await _runAuthAction(_authService.signInWithGoogle);
  }

  @override
  Widget build(BuildContext context) {
    final authConfigured = _authService.isConfigured;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'FrigoCheck',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 52),
              const Text(
                'Iniciar sesion',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authConfigured ? 'Accede para guardar y controlar tu nevera.' : 'Modo demo activo: configura Supabase para usar login real.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'Correo electronico',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  hintText: 'Contrasena',
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isLoading ? 'Entrando...' : 'Entrar',
                icon: Icons.login_rounded,
                onPressed: _isLoading ? () {} : _signIn,
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900)),
                  label: const Text('Continuar con Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: const Text('Crear cuenta'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: null,
                  child: const Text('Recuperar contrasena'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
