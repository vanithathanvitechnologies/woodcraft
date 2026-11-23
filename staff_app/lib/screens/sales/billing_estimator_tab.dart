import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';

class BillingEstimatorTab extends StatefulWidget {
  const BillingEstimatorTab({super.key});

  @override
  State<BillingEstimatorTab> createState() => _BillingEstimatorTabState();
}

class _BillingEstimatorTabState extends State<BillingEstimatorTab> {
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _baseCtrl = TextEditingController(text: '30000');
  final _widthCtrl = TextEditingController(text: '36');
  final _heightCtrl = TextEditingController(text: '84');
  final _hardwareCtrl = TextEditingController(text: '4500');
  final _polishCtrl = TextEditingController(text: '3500');
  final _carvingCtrl = TextEditingController(text: '4000');
  final _qtyCtrl = TextEditingController(text: '1');
  final _discountCtrl = TextEditingController(text: '0');
  final _advanceCtrl = TextEditingController(text: '15000');

  String _wood = AppConstants.woodSpecies.first;
  String _leaf = 'Single Leaf';
  Map<String, dynamic>? _estimate;
  bool _loading = false;

  Future<void> _calculate() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.post('/orders/estimate', {
        'base_price': double.tryParse(_baseCtrl.text) ?? 30000,
        'width_inches': double.tryParse(_widthCtrl.text) ?? 36,
        'height_inches': double.tryParse(_heightCtrl.text) ?? 84,
        'wood_species': _wood,
        'leaf_type': _leaf,
        'hardware_cost': double.tryParse(_hardwareCtrl.text) ?? 0,
        'polish_cost': double.tryParse(_polishCtrl.text) ?? 0,
        'carving_cost': double.tryParse(_carvingCtrl.text) ?? 0,
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        'discount': double.tryParse(_discountCtrl.text) ?? 0,
        'advance_amount': double.tryParse(_advanceCtrl.text) ?? 0,
      });
      setState(() => _estimate = Map<String, dynamic>.from(res['estimate'] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing & Cost Estimation Calculator',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.woodDark)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _wood,
                        decoration: const InputDecoration(labelText: 'Wood Species'),
                        items: AppConstants.woodSpecies.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                        onChanged: (v) => setState(() => _wood = v ?? _wood),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _leaf,
                        decoration: const InputDecoration(labelText: 'Leaf Type'),
                        items: const [
                          DropdownMenuItem(value: 'Single Leaf', child: Text('Single Leaf')),
                          DropdownMenuItem(value: 'Double Leaf', child: Text('Double Leaf')),
                        ],
                        onChanged: (v) => setState(() => _leaf = v ?? _leaf),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _widthCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width (in)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (in)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _baseCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base Price (₹)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _carvingCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carving (₹)'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _hardwareCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hardware (₹)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _polishCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Polish (₹)'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount (₹)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _advanceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advance (₹)'))),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _calculate,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculate Estimate'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_estimate != null) ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFFBF4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cost Breakdown Summary',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark)),
                  const Divider(),
                  _row('Door Area', '${_estimate!['area_sqft']} sq.ft'),
                  _row('Woodwork Unit Cost', _inr.format(_estimate!['woodwork_unit_cost'] ?? 0)),
                  _row('Total Per Unit', _inr.format(_estimate!['unit_total'] ?? 0)),
                  _row('Subtotal', _inr.format(_estimate!['subtotal'] ?? 0)),
                  _row('Discount', '- ${_inr.format(_estimate!['discount'] ?? 0)}'),
                  const Divider(),
                  _row('Grand Total', _inr.format(_estimate!['total_cost'] ?? 0), bold: true),
                  _row('Advance Paid', _inr.format(_estimate!['advance_amount'] ?? 0)),
                  _row('Balance Due', _inr.format(_estimate!['balance_amount'] ?? 0), bold: true, color: AppTheme.danger),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String k, String v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 14, color: color)),
        ],
      ),
    );
  }
}
