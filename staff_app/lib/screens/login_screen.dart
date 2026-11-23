import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';
import 'owner/owner_home_screen.dart';
import 'sales/sales_home_screen.dart';
import 'production/production_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = 'owner';
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _error = null;
    });
  }

  void _routeByRole(String role) {
    Widget target;
    switch (role) {
      case 'owner':
      case 'admin':
        target = const OwnerHomeScreen();
        break;
      case 'sales':
        target = const SalesHomeScreen();
        break;
      case 'production':
        target = const ProductionHomeScreen();
        break;
      default:
        setState(() => _error = 'Unknown role: $role');
        return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ApiService.instance.login(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      _routeByRole(user['role'].toString());
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EE),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hero Banner
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      child: SizedBox(
                        height: 225,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/login_hero.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF3B1E0D), Color(0xFF6B3E1D), Color(0xFFA66E38)],
                                  ),
                                ),
                                child: Center(
                                  child: Image.asset('assets/images/app_logo.png', width: 96, height: 96),
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.15),
                                    const Color(0xFF3B1E0D).withValues(alpha: 0.65),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Floating App Logo Crest
                    Positioned(
                      bottom: -40,
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFAF5EE), width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // Brand Title
                const Text(
                  'WoodCraft',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3B1E0D),
                    letterSpacing: 0.3,
                  ),
                ),
                const Text(
                  'Customiser • Business Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF7A5A43)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Design • Manage • Grow',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF9C816B)),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Role Selector Buttons (Owner / Sales Team / Production Team)
                      _roleButton(
                        role: 'owner',
                        label: 'Owner',
                        icon: Icons.workspace_premium_rounded,
                      ),
                      const SizedBox(height: 10),
                      _roleButton(
                        role: 'sales',
                        label: 'Sales Team',
                        icon: Icons.groups_rounded,
                      ),
                      const SizedBox(height: 10),
                      _roleButton(
                        role: 'production',
                        label: 'Production Team',
                        icon: Icons.settings_suggest_rounded,
                      ),

                      const SizedBox(height: 18),

                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),

                      // Email & Password Fields
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email / Staff ID',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B3E1D)),
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B3E1D)),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          ),
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Rich Espresso Login Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C2E14),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: _loading ? null : _handleLogin,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton({
    required String role,
    required String label,
    required IconData icon,
  }) {
    final active = _selectedRole == role;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _selectRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF5C2E14) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF5C2E14) : const Color(0xFFE5D8C8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A2611).withValues(alpha: active ? 0.16 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: active ? AppTheme.brass.withValues(alpha: 0.22) : const Color(0xFFF6EFE6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: active ? AppTheme.brass : const Color(0xFF5C2E14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : const Color(0xFF3B1E0D),
                ),
              ),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded, color: AppTheme.brass, size: 20)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBBBA9), size: 20),
          ],
        ),
      ),
    );
  }
}
