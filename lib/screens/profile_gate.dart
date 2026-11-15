import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'board_screen.dart';

/// Verifies user profile before showing the Twitter-style feed.
class ProfileGate extends StatefulWidget {
  final User user;

  const ProfileGate({super.key, required this.user});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _profileFuture = _userService.getUserProfile(widget.user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F1419)),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Profile Check',
                style: TextStyle(
                  fontFamily: 'Aktiv Grotesk',
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              actions: [
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.signOut,
                    color: const Color(0xFF0F1419),
                  ),
                  onPressed: () => _authService.signOut(),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.warningCircle,
                      color: const Color(0xFFF4212E),
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load user record: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        fontSize: 14,
                        color: Color(0xFF536471),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F1419),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile != null && profile.isComplete) {
          return BoardScreen(user: widget.user, profile: profile);
        }

        return _CompleteProfileView(
          user: widget.user,
          onCompleted: _loadProfile,
          onSignOut: () => _authService.signOut(),
        );
      },
    );
  }
}

class _CompleteProfileView extends StatefulWidget {
  final User user;
  final VoidCallback onCompleted;
  final VoidCallback onSignOut;

  const _CompleteProfileView({
    required this.user,
    required this.onCompleted,
    required this.onSignOut,
  });

  @override
  State<_CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<_CompleteProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  String _selectedRole = 'Student';
  bool _busy = false;

  final UserService _userService = UserService();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await _userService.saveUserRecord(
        widget.user,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        role: _selectedRole,
      );
      if (mounted) {
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: const Color(0xFF0F1419),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            fontFamily: 'Aktiv Grotesk',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFF0F1419),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: PhosphorIcon(
              PhosphorIconsRegular.signOut,
              color: const Color(0xFF0F1419),
            ),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PhosphorIcon(
                  PhosphorIconsRegular.userCircle,
                  size: 56,
                  color: const Color(0xFF0F1419),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Set Up Your Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Aktiv Grotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F1419),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.user.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Aktiv Grotesk',
                  fontSize: 13,
                  color: Color(0xFF536471),
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _firstNameCtrl,
                style: const TextStyle(
                  fontFamily: 'Aktiv Grotesk',
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  labelText: 'First Name',
                  filled: true,
                  fillColor: const Color(0xFFF7F9F9),
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.user,
                    color: const Color(0xFF536471),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFEFF3F4)),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Enter first name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameCtrl,
                style: const TextStyle(
                  fontFamily: 'Aktiv Grotesk',
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  filled: true,
                  fillColor: const Color(0xFFF7F9F9),
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.userCheck,
                    color: const Color(0xFF536471),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFEFF3F4)),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Enter last name' : null,
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
                decoration: InputDecoration(
                  labelText: 'Role',
                  filled: true,
                  fillColor: const Color(0xFFF7F9F9),
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.identificationCard,
                    color: const Color(0xFF536471),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFEFF3F4)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Student', child: Text('Student')),
                  DropdownMenuItem(value: 'Developer', child: Text('Developer')),
                  DropdownMenuItem(value: 'Instructor', child: Text('Instructor')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRole = val);
                },
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF0F1419),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy ? 'Saving...' : 'Enter Message Board',
                  style: const TextStyle(
                    fontFamily: 'Aktiv Grotesk',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
