import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  static const _tokenKey = 'wd_staff_token';
  static const _userKey = 'wd_staff_user';
  static const _baseUrlKey = 'wd_staff_base_url';

  String? _token;
  Map<String, dynamic>? _user;
  String _baseOrigin = 'https://ttbilling.in/woodcraft/api';

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String get role => (_user?['role'] ?? '').toString();
  String get baseOrigin => _baseOrigin;
  String get apiBase => _baseOrigin.endsWith('/api') ? _baseOrigin : '$_baseOrigin/api';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final savedUrl = prefs.getString(_baseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseOrigin = savedUrl.replaceAll(RegExp(r'/+$'), '');
    }
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = jsonDecode(userJson) as Map<String, dynamic>;
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

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
      h['X-Auth-Token'] = _token!;
    }
    return h;
  }

  dynamic _handleResponse(http.Response res) {
    final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] != false) {
      return data;
    }
    throw Exception(data['message'] ?? 'Request failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$apiBase/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    final data = _handleResponse(res) as Map<String, dynamic>;
    _token = data['token'] as String;
    _user = Map<String, dynamic>.from(data['user'] as Map);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userKey, jsonEncode(_user));
    return _user!;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final uri = Uri.parse('$apiBase$endpoint');
    final headers = _headers(json: false);
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        return Map<String, dynamic>.from(_handleResponse(res) as Map);
      } catch (e) {
        if (attempt == 0 && e.toString().contains('ClientException')) {
          await Future.delayed(const Duration(milliseconds: 450));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Network error. Please try again.');
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$apiBase$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return Map<String, dynamic>.from(_handleResponse(res) as Map);
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$apiBase$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return Map<String, dynamic>.from(_handleResponse(res) as Map);
  }

  Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$apiBase$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return Map<String, dynamic>.from(_handleResponse(res) as Map);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final res = await http.delete(Uri.parse('$apiBase$endpoint'), headers: _headers());
    return Map<String, dynamic>.from(_handleResponse(res) as Map);
  }

  Future<Map<String, dynamic>> uploadMultipart({
    required String endpoint,
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    Map<String, String> fields = const {},
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase$endpoint'));
    if (_token != null) {
      req.headers['Authorization'] = 'Bearer $_token';
      req.headers['X-Auth-Token'] = _token!;
    }
    req.fields.addAll(fields);
    req.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return Map<String, dynamic>.from(_handleResponse(res) as Map);
  }
}
