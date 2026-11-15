import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Minimalist, Twitter-inspired Auth Screen with clean typography and monochrome styling.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  String _selectedRole = 'Student';
  bool _isRegistering = false;
  bool _busy = false;

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      if (_isRegistering) {
        final cred = await _authService.register(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );

        final user = cred.user;
        if (user != null) {
          await _userService.saveUserRecord(
            user,
            firstName: _firstNameCtrl.text,
            lastName: _lastNameCtrl.text,
            role: _selectedRole,
          );
        }
      } else {
        await _authService.signIn(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      }
    } catch (e) {
      if (mounted) {
        final message = AuthService.getFriendlyErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Aktiv Grotesk',
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            backgroundColor: const Color(0xFF0F1419),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Twitter-style centered header
                  Center(
                    child: PhosphorIcon(
                      PhosphorIconsRegular.chatTeardropDots,
                      size: 40,
                      color: const Color(0xFF0F1419),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isRegistering
                        ? 'Create Vault Account'
                        : 'Sign in to Message Board Vault',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Aktiv Grotesk',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Color(0xFF0F1419),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegistering
                        ? 'Register to post and view board messages'
                        : 'Sign in to post and view board messages',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Aktiv Grotesk',
                      fontSize: 14,
                      color: Color(0xFF536471),
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_isRegistering) ...[
                    TextFormField(
                      controller: _firstNameCtrl,
                      style: const TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        fontSize: 15,
                        color: Color(0xFF0F1419),
                      ),
                      decoration: _inputDecoration(
                        label: 'First Name',
                        icon: PhosphorIconsRegular.user,
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty)
                              ? 'Enter your first name'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameCtrl,
                      style: const TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        fontSize: 15,
                        color: Color(0xFF0F1419),
                      ),
                      decoration: _inputDecoration(
                        label: 'Last Name',
                        icon: PhosphorIconsRegular.userCheck,
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty)
                              ? 'Enter your last name'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        fontSize: 15,
                        color: Color(0xFF0F1419),
                      ),
                      decoration: _inputDecoration(
                        label: 'Role',
                        icon: PhosphorIconsRegular.identificationCard,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Student', child: Text('Student')),
                        DropdownMenuItem(
                            value: 'Developer', child: Text('Developer')),
                        DropdownMenuItem(
                            value: 'Instructor', child: Text('Instructor')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontFamily: 'Aktiv Grotesk',
                      fontSize: 15,
                      color: Color(0xFF0F1419),
                    ),
                    decoration: _inputDecoration(
                      label: 'Email Address',
                      icon: PhosphorIconsRegular.envelopeSimple,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter an email address';
                      }
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(val.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(
                      fontFamily: 'Aktiv Grotesk',
                      fontSize: 15,
                      color: Color(0xFF0F1419),
                    ),
                    decoration: _inputDecoration(
                      label: 'Password',
                      icon: PhosphorIconsRegular.lockKey,
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Enter a password';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Black pill button like Twitter / X
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F1419),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isRegistering ? 'Sign up' : 'Sign in',
                            style: const TextStyle(
                              fontFamily: 'Aktiv Grotesk',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Minimalist switch link
                  Center(
                    child: GestureDetector(
                      onTap: _busy
                          ? null
                          : () {
                              setState(() {
                                _isRegistering = !_isRegistering;
                                _formKey.currentState?.reset();
                              });
                            },
                      child: Text.rich(
                        TextSpan(
                          text: _isRegistering
                              ? 'Have an account already? '
                              : "Don't have an account? ",
                          style: const TextStyle(
                            fontFamily: 'Aktiv Grotesk',
                            fontSize: 14,
                            color: Color(0xFF536471),
                          ),
                          children: [
                            TextSpan(
                              text: _isRegistering ? 'Log in' : 'Sign up',
                              style: const TextStyle(
                                fontFamily: 'Aktiv Grotesk',
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D9BF0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontFamily: 'Aktiv Grotesk',
        color: Color(0xFF536471),
        fontSize: 14,
      ),
      prefixIcon: PhosphorIcon(
        icon,
        size: 20,
        color: const Color(0xFF536471),
      ),
      filled: true,
      fillColor: const Color(0xFFF7F9F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEFF3F4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0F1419), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF4212E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF4212E), width: 1.5),
      ),
    );
  }
}
