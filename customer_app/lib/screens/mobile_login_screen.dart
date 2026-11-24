import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import 'customer_dashboard_screen.dart';

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  static const _woodDark = Color(0xFF3B1E0D);
  static const _woodPrimary = Color(0xFF5C2E14);
  static const _brass = Color(0xFFD4A037);
  static const _bg = Color(0xFFFAF5EE);

  final _mobileCtrl = TextEditingController(text: '76039 70435');
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _otpStep = false;
  bool _autoVerifying = false;
  String? _error;
  String? _customerName;

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await CustomerApiService.instance.requestOtp(_mobileCtrl.text);
      setState(() {
        _otpStep = true;
        _customerName = res['customer_name']?.toString();
      });

      if (res['auto_verify'] == true && res['otp_code'] != null) {
        final code = res['otp_code'].toString();
        setState(() {
          _otpCtrl.text = code;
          _autoVerifying = true;
        });
        await Future.delayed(const Duration(milliseconds: 950));
        if (!mounted) return;
        await _verifyOtp(code);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _autoVerifying = false;
        });
      }
    }
  }

  Future<void> _verifyOtp([String? overrideCode]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CustomerApiService.instance.verifyOtp(
        _mobileCtrl.text,
        overrideCode ?? _otpCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _autoVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpDigits = _otpCtrl.text.padRight(6, ' ').split('').take(6).toList();

    return Scaffold(
      backgroundColor: _bg,
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
                        height: 235,
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
                                    colors: [_woodDark, _woodPrimary, Color(0xFFA66E38)],
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
                                    _woodDark.withValues(alpha: 0.65),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -34,
                      child: Container(
                        width: 164,
                        height: 68,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _bg, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 52),

                const Text(
                  'WoodCraft',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _woodDark),
                ),
                const Text(
                  'Customiser',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF7A5A43)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your Dream Door, Our Craft',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF9C816B)),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                        ),

                      if (!_otpStep) ...[
                        const Text(
                          'Enter Mobile Number',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _woodDark),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone_android_rounded, color: _woodPrimary),
                            prefixText: '+91 ',
                            hintText: '76039 70435',
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _woodPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _loading ? null : _requestOtp,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                  )
                                : const Text('Get OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ] else ...[
                        // Verify OTP Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5D8C8)),
                          ),
                          child: Column(
                            children: [
                              const Text('Verify OTP',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _woodDark)),
                              if (_customerName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Welcome, $_customerName',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B8A5A))),
                                ),
                              const SizedBox(height: 6),
                              const Text('Enter 6 Digit OTP', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                              const SizedBox(height: 16),
                              // 6 OTP Digit Boxes
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (idx) {
                                  final ch = otpDigits[idx].trim();
                                  return Container(
                                    width: 44,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: ch.isNotEmpty ? const Color(0xFFFAF5EE) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: ch.isNotEmpty ? _woodPrimary : const Color(0xFFD9CBB8),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      ch,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _woodDark),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 14),
                              if (_autoVerifying)
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 10),
                                    Text('Auto-verifying OTP...',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B8A5A))),
                                  ],
                                )
                              else
                                TextField(
                                  controller: _otpCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: '6-Digit OTP',
                                    counterText: '',
                                  ),
                                ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _woodPrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _loading ? null : () => _verifyOtp(),
                                  child: const Text('Verify', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _otpStep = false;
                                  _otpCtrl.clear();
                                  _error = null;
                                }),
                                child: const Text('Change Mobile Number'),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
