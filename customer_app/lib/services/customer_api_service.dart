import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CustomerApiService {
  static final CustomerApiService instance = CustomerApiService._();
  CustomerApiService._();

  static const _tokenKey = 'wd_customer_token';
  static const _customerKey = 'wd_customer_profile';
  static const _baseUrlKey = 'wd_customer_base_url';

  String? _token;
  Map<String, dynamic>? _customer;
  String _baseOrigin = 'https://ttbilling.in/woodcraft/api';

  String? get token => _token;
  Map<String, dynamic>? get customer => _customer;
  String get baseOrigin => _baseOrigin;
  String get apiBase => _baseOrigin.endsWith('/api') ? _baseOrigin : '$_baseOrigin/api';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final savedUrl = prefs.getString(_baseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseOrigin = savedUrl.replaceAll(RegExp(r'/+$'), '');
    }
    final custJson = prefs.getString(_customerKey);
    if (custJson != null) {
      _customer = jsonDecode(custJson) as Map<String, dynamic>;
    }
  }

  Future<void> setBaseOrigin(String origin) async {
    _baseOrigin = origin.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseOrigin);
  }

  String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$_baseOrigin${path.startsWith('/') ? '' : '/'}$path';
  }

  Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
      h['X-Auth-Token'] = _token!;
    }
    return h;
  }

  Map<String, dynamic> _parse(http.Response res) {
    final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] != false) {
      return Map<String, dynamic>.from(data as Map);
    }
    throw Exception(data['message'] ?? 'Request failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> requestOtp(String mobile) async {
    final res = await http.post(
      Uri.parse('$apiBase/auth/customer/request-otp'),
      headers: _headers(),
      body: jsonEncode({'mobile': mobile.trim()}),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> verifyOtp(String mobile, String otp) async {
    final res = await http.post(
      Uri.parse('$apiBase/auth/customer/verify-otp'),
      headers: _headers(),
      body: jsonEncode({'mobile': mobile.trim(), 'otp': otp.trim()}),
    );
    final data = _parse(res);
    _token = data['token'] as String;
    _customer = Map<String, dynamic>.from(data['customer'] as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_customerKey, jsonEncode(_customer));
    return _customer!;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await http.get(Uri.parse('$apiBase/customer/dashboard'), headers: _headers());
    return _parse(res);
  }

  Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final res = await http.get(Uri.parse('$apiBase/customer/orders/$orderId'), headers: _headers());
    return _parse(res);
  }

  Future<void> logout() async {
    _token = null;
    _customer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_customerKey);
  }
}
