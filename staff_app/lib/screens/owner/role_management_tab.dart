import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class RoleManagementTab extends StatefulWidget {
  const RoleManagementTab({super.key});

  @override
  State<RoleManagementTab> createState() => _RoleManagementTabState();
}

class _RoleManagementTabState extends State<RoleManagementTab> {
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.get('/users');
      final allUsers = (res['users'] as List?) ?? [];
      setState(() {
        _users = allUsers.where((raw) {
          final role = ((raw as Map)['role'] ?? '').toString().toLowerCase();
          return role != 'owner';
        }).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'sales';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Create Staff Login Access'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 10),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    DropdownMenuItem(value: 'sales', child: Text('Sales Team')),
                    DropdownMenuItem(value: 'production', child: Text('Production Team')),
                  ],
                  onChanged: (v) => setModalState(() => role = v ?? 'sales'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.instance.post('/users', {
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'phone': phoneCtrl.text,
                    'password': passCtrl.text,
                    'role': role,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> u) async {
    try {
      await ApiService.instance.put('/users/${u['id']}', {'is_active': u['is_active'] != 1});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.woodPrimary,
        foregroundColor: Colors.white,
        onPressed: _showAddStaffDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = Map<String, dynamic>.from(_users[i] as Map);
                  final active = u['is_active'] == 1;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.woodDark,
                        child: Text(
                          '${u['role']}'.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: AppTheme.brass, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${u['email']} • Role: ${u['role'].toString().toUpperCase()}'),
                      trailing: Switch(
                        value: active,
                        activeThumbColor: AppTheme.success,
                        onChanged: (_) => _toggleStatus(u),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
