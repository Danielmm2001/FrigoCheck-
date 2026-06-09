import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _resetEmailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges?.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        _showPasswordResetDialog();
        return;
      }

      if (state.session?.user != null) {
        _goHomeAfterRealSession();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _friendlyAuthError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('invalid email') || message.contains('email address')) {
      return 'Introduce un correo electronico valido.';
    }

    if (message.contains('rate limit') ||
        message.contains('too many') ||
        message.contains('security purposes')) {
      return 'Espera unos minutos antes de pedir otro enlace.';
    }

    if (message.contains('redirect') || message.contains('not allowed')) {
      return 'El enlace de recuperacion no esta configurado correctamente.';
    }

    if (message.contains('email not confirmed') || message.contains('confirm')) {
      return 'Revisa tu correo y confirma la cuenta antes de entrar.';
    }

    if (message.contains('password')) {
      return 'No se pudo actualizar la contrasena. Revisa los datos e intentalo de nuevo.';
    }

    if (message.contains('invalid login credentials') || message.contains('invalid_credentials')) {
      return 'Correo o contrasena incorrectos.';
    }

    if (message.contains('already registered') || message.contains('user already')) {
      return 'Ya existe una cuenta con ese correo. Prueba a iniciar sesion.';
    }

    if (message.contains('provider is not enabled') || message.contains('provider not enabled')) {
      return 'El acceso con Google aun no esta disponible.';
    }

    if (message.contains('network') || message.contains('socket') || message.contains('timeout')) {
      return 'No se pudo conectar. Revisa tu conexion e intentalo de nuevo.';
    }

    return 'No se pudo completar la accion. Intentalo de nuevo.';
  }

  Future<void> _goHomeAfterRealSession({
    String? pendingMessage,
    bool allowDemo = false,
  }) async {
    if (!mounted) return;

    if (_isPasswordRecovery) {
      return;
    }

    if (_authService.hasActiveSession || allowDemo) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    _showMessage(pendingMessage ?? 'No hay una sesion activa. Revisa el login e intentalo de nuevo.');
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    String? pendingMessage,
    bool allowDemo = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      await action();
      await _goHomeAfterRealSession(
        pendingMessage: pendingMessage,
        allowDemo: allowDemo,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_authService.isConfigured) {
      await _runAuthAction(() async {}, allowDemo: true);
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Introduce correo y contrasena');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Introduce un correo electronico valido.');
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
      _showMessage('La contrasena debe tener al menos 6 caracteres');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Introduce un correo electronico valido.');
      return;
    }

    await _runAuthAction(
      () => _authService.signUpWithEmail(email: email, password: password),
      pendingMessage: 'Cuenta creada. Revisa tu correo para confirmarla antes de entrar.',
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _resetEmailController.text.trim();

    if (!_authService.isConfigured) {
      _showMessage('La recuperacion de contrasena no esta disponible en modo demo.');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Introduce tu correo electronico.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Introduce un correo electronico valido.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage('Te hemos enviado un enlace para cambiar la contrasena.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPasswordResetRequestDialog() async {
    _resetEmailController.text = _emailController.text.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recuperar contrasena'),
          content: TextField(
            controller: _resetEmailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'Correo electronico',
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _sendPasswordResetEmail,
              child: const Text('Enviar enlace'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateRecoveredPassword() async {
    final password = _newPasswordController.text;

    if (password.length < 6) {
      _showMessage('La contrasena debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(password);
      if (!mounted) return;
      _isPasswordRecovery = false;
      Navigator.of(context).pop();
      _showMessage('Contrasena actualizada correctamente.');
      await _goHomeAfterRealSession();
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPasswordResetDialog() async {
    _newPasswordController.clear();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nueva contrasena'),
          content: TextField(
            controller: _newPasswordController,
            enabled: !_isLoading,
            obscureText: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
              hintText: 'Nueva contrasena',
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _updateRecoveredPassword,
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    if (!_authService.isConfigured) {
      await _signIn();
      return;
    }
    await _runAuthAction(
      _authService.signInWithGoogle,
      pendingMessage: 'Completa Google en el navegador y vuelve a FrigoCheck.',
    );
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
                  onPressed: _showPasswordResetRequestDialog,
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
