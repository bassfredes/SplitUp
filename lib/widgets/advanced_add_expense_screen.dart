import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart'; // Added Provider
import '../providers/expense_provider.dart'; // Added ExpenseProvider
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../utils/formatters.dart';

class AdvancedAddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<UserModel> participants;
  final String currentUserId;
  final String groupCurrency;
  final ExpenseModel? expenseToEdit;
  final String? groupName;
  const AdvancedAddExpenseScreen({
    required this.groupId,
    required this.participants,
    required this.currentUserId,
    this.groupCurrency = 'CLP',
    this.expenseToEdit,
    this.groupName,
    super.key,
  });

  @override
  State<AdvancedAddExpenseScreen> createState() => _AdvancedAddExpenseScreenState();
}

class _AdvancedAddExpenseScreenState extends State<AdvancedAddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _currency = 'CLP';
  // Usar la constante centralizada de monedas
  final List<Map<String, String>> _currencies = kCurrencies;
  String? _selectedCategory;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  String _splitType = 'equal';
  final Map<String, double> _payerAmounts = {};
  final Map<String, double> _customSplits = {};
  List<String> _selectedParticipants = [];
  bool _loading = false;
  String? _selectedPayer;
  final Map<String, TextEditingController> _splitControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.participants.isEmpty) {
      // Error crítico: no hay participantes
      print('[ERROR] La lista de participantes está vacía al crear AdvancedAddExpenseScreen');
    }
    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _descController.text = e.description;
      _amountController.text = e.amount.toStringAsFixed(e.currency == 'CLP' ? 0 : 2);
      _categoryController.text = e.category ?? '';
      _selectedDate = e.date;
      _currency = e.currency;
      // Validar categoría
      final catKey = e.category;
      final catList = kExpenseCategories.map((c) => c['key']).toList();
      if (catKey != null && catList.contains(catKey)) {
        _selectedCategory = catKey;
      } else if (catKey != null && catKey.isNotEmpty) {
        _selectedCategory = 'otra';
        _categoryController.text = catKey;
      } else {
        _selectedCategory = null;
      }
      _selectedParticipants = List<String>.from(e.participantIds);
      _splitType = e.splitType;
      if (e.payers.isNotEmpty) {
        _payerAmounts.clear();
        for (final p in e.payers) {
          _payerAmounts[p['userId']] = (p['amount'] as num).toDouble();
        }
        _selectedPayer = e.payers.first['userId'];
      }
      if (e.customSplits != null) {
        _customSplits.clear();
        for (final s in e.customSplits!) {
          _customSplits[s['userId']] = (s['amount'] as num).toDouble();
        }
      }
      if (e.attachments != null && e.attachments!.isNotEmpty) {
        _imagePath = e.attachments!.first;
      }
    } else {
      // Asegura que el usuario actual esté en la lista de participantes
      final ids = widget.participants.map((u) => u.id).toSet();
      ids.add(widget.currentUserId);
      _selectedParticipants = ids.toList();
      // Por defecto, el usuario actual paga todo
      _payerAmounts[widget.currentUserId] = 0.0;
      for (final u in widget.participants) {
        _customSplits[u.id] = 0.0;
      }
      // Si el usuario actual no está en la lista de participantes, agregarlo
      if (!widget.participants.any((u) => u.id == widget.currentUserId)) {
        _customSplits[widget.currentUserId] = 0.0;
      }
      _currency = widget.groupCurrency;
      _selectedPayer = widget.currentUserId;
    }
    // Inicializar controladores para los splits
    for (final id in _selectedParticipants) {
      _splitControllers[id] = TextEditingController(
        text: _customSplits[id]?.toStringAsFixed(_splitType == 'percent' ? 2 : (_currency == 'CLP' ? 0 : 2)) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateSplitControllers() {
    for (final id in _selectedParticipants) {
      _splitControllers.putIfAbsent(id, () => TextEditingController());
      _splitControllers[id]!.text = _customSplits[id]?.toStringAsFixed(_splitType == 'percent' ? 2 : (_currency == 'CLP' ? 0 : 2)) ?? '';
    }
    // Eliminar controladores de participantes que ya no están
    final toRemove = _splitControllers.keys.where((id) => !_selectedParticipants.contains(id)).toList();
    for (final id in toRemove) {
      _splitControllers[id]?.dispose();
      _splitControllers.remove(id);
    }
  }

  void _setEqualSplit() {
    final count = _selectedParticipants.length;
    if (count == 0) return;
    final total = double.tryParse(_amountController.text) ?? 0.0;
    final share = total / count;
    setState(() {
      for (final id in _selectedParticipants) {
        _customSplits[id] = share;
      }
      _updateSplitControllers();
    });
  }

  void _setPercentSplit() {
    final count = _selectedParticipants.length;
    if (count == 0) return;
    final percent = 100.0 / count;
    setState(() {
      for (final id in _selectedParticipants) {
        _customSplits[id] = percent;
      }
      _updateSplitControllers();
    });
  }

  Widget _buildParticipantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('New Expense', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: widget.participants.map((u) {
            final selected = _selectedParticipants.contains(u.id);
            return FilterChip(
              label: Text(u.id == widget.currentUserId ? '${u.name} (Tú)' : u.name),
              avatar: u.photoUrl != null && u.photoUrl!.isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(u.photoUrl!))
                  : CircleAvatar(child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?')),
              selected: selected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedParticipants.add(u.id);
                    if (_splitType == 'shares') _customSplits[u.id] = 1;
                  } else {
                    _selectedParticipants.remove(u.id);
                    _customSplits.remove(u.id);
                  }
                  _updateSplitControllers();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPayers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who paid?', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          value: _selectedPayer,
          items: [
            DropdownMenuItem<String>(
              value: widget.currentUserId,
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 8),
                  Text('${_getUserName(widget.currentUserId)} (Tú)'),
                ],
              ),
            ),
            ...widget.participants.where((u) => u.id != widget.currentUserId).map((u) => DropdownMenuItem<String>(
              value: u.id,
              child: Row(
                children: [
                  if (u.photoUrl != null && u.photoUrl!.isNotEmpty)
                    CircleAvatar(backgroundImage: NetworkImage(u.photoUrl!), radius: 12)
                  else
                    CircleAvatar(radius: 12, child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?')),
                  const SizedBox(width: 8),
                  Text(u.name),
                ],
              ),
            )),
          ],
          onChanged: (val) {
            setState(() {
              _selectedPayer = val;
              _payerAmounts.clear();
              if (val != null) _payerAmounts[val] = double.tryParse(_amountController.text) ?? 0.0;
            });
          },
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
        ),
      ],
    );
  }

  String _getUserName(String id) {
    final user = widget.participants.firstWhere(
      (u) => u.id == id,
      orElse: () => UserModel(id: id, name: '', email: '', photoUrl: null),
    );
    return user.name;
  }

  Widget _buildSplitInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Split:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _splitType,
              items: const [
                DropdownMenuItem(value: 'equal', child: Text('Equal')),
                DropdownMenuItem(value: 'custom', child: Text('Amounts')),
                DropdownMenuItem(value: 'percent', child: Text('Percent')),
                DropdownMenuItem(value: 'shares', child: Text('Shares')),
              ],
              onChanged: (v) {
                setState(() {
                  _splitType = v ?? 'equal';
                  _updateSplitControllers();
                });
              },
            ),
            if (_splitType == 'equal' || _splitType == 'percent')
              TextButton(
                onPressed: _splitType == 'equal' ? _setEqualSplit : _setPercentSplit,
                child: const Text('Split equally'),
              ),
          ],
        ),
        if (_splitType == 'shares')
          Column(
            children: _selectedParticipants.map((id) {
              final user = widget.participants.firstWhere(
                (u) => u.id == id,
                orElse: () => UserModel(id: id, name: 'Tú', email: '', photoUrl: null),
              );
              return Row(
                children: [
                  if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                    CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!), radius: 14)
                  else
                    CircleAvatar(radius: 14, child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                  const SizedBox(width: 6),
                  Text(user.id == widget.currentUserId ? '${user.name} (Tú)' : user.name),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      controller: _splitControllers[id],
                      decoration: const InputDecoration(labelText: 'Shares'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        setState(() {
                          final val = int.tryParse(v) ?? 1;
                          _customSplits[id] = val > 0 ? val.toDouble() : 1.0;
                        });
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          )
        else
          ..._selectedParticipants.map((id) {
            final user = widget.participants.firstWhere(
              (u) => u.id == id,
              orElse: () => UserModel(id: id, name: 'Tú', email: '', photoUrl: null),
            );
            return Row(
              children: [
                if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                  CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!), radius: 14)
                else
                  CircleAvatar(radius: 14, child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                const SizedBox(width: 6),
                Text(user.id == widget.currentUserId ? '${user.name} (Tú)' : user.name, style: TextStyle(fontWeight: user.id == widget.currentUserId ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _splitControllers[id],
                    decoration: InputDecoration(
                      labelText: _splitType == 'percent' ? '%' : 'Monto',
                      hintText: _splitType == 'percent' ? '0' : _amountPlaceholder,
                    ),
                    keyboardType: _splitType == 'percent' || _currency != 'CLP'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    onChanged: (v) {
                      setState(() {
                        final formatted = _splitType == 'percent' ? v.replaceAll(RegExp(r'[^0-9.]'), '') : _formatAmountInput(v);
                        _customSplits[id] = double.tryParse(formatted) ?? 0.0;
                      });
                    },
                  ),
                ),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildSummary() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Participants summary', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._selectedParticipants.map((id) {
              final user = widget.participants.firstWhere(
                (u) => u.id == id,
                orElse: () => UserModel(id: id, name: 'Tú', email: '', photoUrl: null),
              );
              double value;
              if (_splitType == 'percent') {
                value = ((amount * ((_customSplits[id] ?? 0) / 100.0)));
              } else {
                value = _customSplits[id] ?? 0.0;
              }
              return Row(
                children: [
                  if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                    CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!), radius: 12)
                  else
                    CircleAvatar(radius: 12, child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                  const SizedBox(width: 6),
                  Expanded(child: Text(user.id == widget.currentUserId ? '${user.name} (Tú)' : user.name)),
                  // Usar la función formatCurrency
                  Text(formatCurrency(value, _currency)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    print('[DEBUG] Iniciando submit de gasto');
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (_splitType == 'percent') {
      final totalPercent = _selectedParticipants.fold<double>(0, (sum, id) => sum + (_customSplits[id] ?? 0));
      if ((totalPercent - 100.0).abs() > 0.01) {
        print('[DEBUG] Error: sum of percentages != 100');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The sum of percentages must be 100%')));
        return;
      }
    } else if (_splitType == 'equal' || _splitType == 'custom') {
      final totalSplit = _selectedParticipants.fold<double>(0, (sum, id) => sum + (_customSplits[id] ?? 0));
      if ((totalSplit - amount).abs() > 0.01) {
        print('[DEBUG] Error: sum of amounts != total');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The sum of the amounts must be equal to the total')));
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final payers = _payerAmounts.entries.map((e) => {'userId': e.key, 'amount': e.value}).toList();
      final customSplits = _splitType == 'equal'
          ? null
          : _customSplits.entries.map((e) => {'userId': e.key, 'amount': e.value}).toList();
      // final firestoreService = FirestoreService(); // No longer needed directly for update
      print('[DEBUG] Datos para Firestore:');
      print('payers: $payers');
      print('customSplits: ${customSplits?.toString() ?? 'null'}');
      print('amount: $amount, currency: $_currency, participantes: $_selectedParticipants');
      if (widget.expenseToEdit != null) {
        final updatedExpense = ExpenseModel(
          id: widget.expenseToEdit!.id,
          groupId: widget.groupId,
          description: _descController.text.trim(),
          amount: amount,
          date: _selectedDate,
          participantIds: _selectedParticipants,
          payers: payers,
          createdBy: widget.currentUserId,
          category: _selectedCategory ?? _categoryController.text.trim(),
          attachments: _imagePath != null ? [_imagePath!] : null,
          splitType: _splitType,
          customSplits: customSplits,
          isRecurring: false,
          isLocked: false,
          currency: _currency,
        );
        print('[DEBUG] updatedExpense.toMap(): ${updatedExpense.toMap()}');
        // await firestoreService.updateExpense(updatedExpense); // Replaced
        await Provider.of<ExpenseProvider>(context, listen: false).updateExpense(updatedExpense);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.pop(context, updatedExpense); // Pop with the updated expense
      } else {
        // Logic for adding a new expense remains the same, using FirestoreService directly or via provider if preferred
        final firestoreService = FirestoreService(); // Keep for addExpense if not using provider for it
        final expense = ExpenseModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // Firestore generates ID, this might be temp
          groupId: widget.groupId,
          description: _descController.text.trim(),
          amount: amount,
          date: _selectedDate,
          participantIds: _selectedParticipants,
          payers: payers,
          createdBy: widget.currentUserId,
          category: _selectedCategory ?? _categoryController.text.trim(),
          attachments: _imagePath != null ? [_imagePath!] : null,
          splitType: _splitType,
          customSplits: customSplits,
          isRecurring: false,
          isLocked: false,
          currency: _currency,
        );
        print('[DEBUG] expense.toMap(): ${expense.toMap()}');
        // If addExpense is also moved to provider, this would change too. For now, it's direct.
        await firestoreService.addExpense(expense);
        await FirebaseAnalytics.instance.logEvent(
          name: 'add_payment',
          parameters: {
            'group_id': widget.groupId,
            'amount': _amountController.text,
            'currency': _currency,
          },
        );
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.pop(context, expense);
      }
    } catch (e, stack) {
      setState(() => _loading = false);
      print('Error saving expense:');
      print(e);
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving expense: \n${e.toString()}')),
      );
    }
  }

  String get _amountPlaceholder {
    switch (_currency) {
      case 'USD':
      case 'EUR':
        return '0.00';
      default:
        return '0';
    }
  }

  String _formatAmountInput(String value) {
    if (_currency == 'CLP') {
      // Solo números enteros
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? '0' : digits;
    } else {
      // Permitir decimales con punto
      final formatted = value.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
      final parts = formatted.split('.');
      if (parts.length > 2) {
        return '${parts[0]}.${parts.sublist(1).join('')}';
      }
      return formatted;
    }
  }

  InputDecoration _inputDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF22223B)),
      hintStyle: const TextStyle(color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) {
      // Only error message, no double card
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('Could not load the list of participants for the group.', style: TextStyle(color: Colors.red, fontSize: 18)),
        ),
      );
    }
    // NO usar Container principal aquí, solo el contenido
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Breadcrumb(
            items: [
              BreadcrumbItem('Home', route: '/dashboard'),
              BreadcrumbItem(widget.groupName != null ? 'Group: ${widget.groupName}' : 'Group', route: '/group/${widget.groupId}'),
              BreadcrumbItem(widget.expenseToEdit != null ? 'Editing Expense: ${widget.expenseToEdit!.description}' : 'New Expense'),
            ],
            onTap: (i) {
              if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
              if (i == 1) Navigator.pushReplacementNamed(context, '/group/${widget.groupId}');
            },
          ),
          const SizedBox(height: 32),
          Text(
            widget.expenseToEdit != null ? 'Editing Expense' : 'New Expense',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 16),
          _buildParticipantSelector(),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 500;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      decoration: _inputDecoration(label: 'Total value', hint: _amountPlaceholder),
                      keyboardType: _currency == 'CLP'
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || double.tryParse(_formatAmountInput(v)) == null ? 'Invalid value' : null,
                      onChanged: (v) {
                        final formatted = _formatAmountInput(v);
                        if (v != formatted) {
                          _amountController.text = formatted;
                          _amountController.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
                        }
                        if (_selectedPayer != null) {
                          setState(() {
                            _payerAmounts[_selectedPayer!] = double.tryParse(formatted) ?? 0.0;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currency,
                            items: _currencies.map((c) => DropdownMenuItem<String>(
                              value: c['code'],
                              child: Row(
                                children: [
                                  Text(c['icon'] ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                                  const SizedBox(width: 4),
                                  Text(c['label'] ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                                ],
                              ),
                            )).toList(),
                            onChanged: (v) => setState(() => _currency = v ?? 'CLP'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        decoration: _inputDecoration(label: 'Monto total', hint: _amountPlaceholder),
                        keyboardType: _currency == 'CLP'
                            ? TextInputType.number
                            : const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || double.tryParse(_formatAmountInput(v)) == null ? 'Monto inválido' : null,
                        onChanged: (v) {
                          final formatted = _formatAmountInput(v);
                          if (v != formatted) {
                            _amountController.text = formatted;
                            _amountController.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
                          }
                          if (_selectedPayer != null) {
                            setState(() {
                              _payerAmounts[_selectedPayer!] = double.tryParse(formatted) ?? 0.0;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currency,
                            items: _currencies.map((c) => DropdownMenuItem<String>(
                              value: c['code'],
                              child: Row(
                                children: [
                                  Text(c['icon'] ?? ''),
                                  const SizedBox(width: 4),
                                  Text(c['label'] ?? ''),
                                ],
                              ),
                            )).toList(),
                            onChanged: (v) => setState(() => _currency = v ?? 'CLP'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 28),
          _buildPayers(),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add image', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() => _imagePath = image.path);
                        }
                      },
                      child: Container(
                        width: 110,
                        height: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey,
                            width: 1.2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, size: 32, color: Colors.grey),
                            const SizedBox(height: 6),
                            Text('Add', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    if (_imagePath != null) ...[
                      const SizedBox(height: 8),
                      Text(_imagePath!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _descController,
            decoration: _inputDecoration(label: 'Description', hint: 'E.g. drinks'),
            validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: [
                    ...kExpenseCategories.map((cat) => DropdownMenuItem<String>(
                      value: cat['key'],
                      child: Text(cat['label']),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      if (val != 'otra') {
                        _categoryController.clear();
                      }
                    });
                  },
                  decoration: _inputDecoration(label: 'Category'),
                  validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                ),
              ),
              if (_selectedCategory == 'otra')
                const SizedBox(width: 12),
              if (_selectedCategory == 'otra')
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: _inputDecoration(label: 'Other category'),
                    validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSplitInputs(),
          const SizedBox(height: 28),
          _buildSummary(),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : () {
                  _submit();
                  setState(() {
                    _descController.clear();
                    _amountController.clear();
                    _customSplits.updateAll((key, value) => 0.0);
                    _payerAmounts.clear();
                    _selectedCategory = null;
                    _imagePath = null;
                  });
                },
                child: const Text('Save and add another'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: Icon(widget.expenseToEdit != null ? Icons.save : Icons.add),
                label: Text(widget.expenseToEdit != null ? 'Save changes' : 'Add expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
