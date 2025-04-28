import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';

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
        const Text('Nuevo Gasto', style: TextStyle(fontWeight: FontWeight.bold)),
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
        const Text('¿Quién pagó?', style: TextStyle(fontWeight: FontWeight.bold)),
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
        const Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('División:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _splitType,
              items: const [
                DropdownMenuItem(value: 'equal', child: Text('Igual')),
                DropdownMenuItem(value: 'custom', child: Text('Montos')),
                DropdownMenuItem(value: 'percent', child: Text('Porcentaje')),
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
                child: const Text('Dividir igual'),
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
            const Text('Resumen de participantes', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text('${value.toStringAsFixed(2)} $_currency'),
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
    // Validación de sumas
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (_splitType == 'percent') {
      final totalPercent = _selectedParticipants.fold<double>(0, (sum, id) => sum + (_customSplits[id] ?? 0));
      if ((totalPercent - 100.0).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La suma de los porcentajes debe ser 100%')));
        return;
      }
    } else if (_splitType == 'equal' || _splitType == 'custom') {
      final totalSplit = _selectedParticipants.fold<double>(0, (sum, id) => sum + (_customSplits[id] ?? 0));
      if ((totalSplit - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La suma de los montos debe ser igual al total')));
        return;
      }
    }
    setState(() => _loading = true);
    // Transformar payers a List<Map<String, dynamic>>
    final payers = _payerAmounts.entries.map((e) => {'userId': e.key, 'amount': e.value}).toList();
    // Transformar customSplits a List<Map<String, dynamic>>?
    final customSplits = _splitType == 'equal'
        ? null
        : _customSplits.entries.map((e) => {'userId': e.key, 'amount': e.value}).toList();
    final firestoreService = FirestoreService();
    if (widget.expenseToEdit != null) {
      // Modo edición
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
      await firestoreService.updateExpense(updatedExpense);
      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.pop(context, updatedExpense);
    } else {
      // Guardar en Firestore
      final expense = ExpenseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      await firestoreService.addExpense(expense);
      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.pop(context, expense);
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
    return Container(
      width: double.infinity,
      color: const Color(0xFFF6F8FA),
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(maxWidth: 1200),
            margin: const EdgeInsets.only(top: 20, bottom: 20),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Breadcrumb(
                  items: [
                    BreadcrumbItem('Inicio', route: '/dashboard'),
                    BreadcrumbItem(widget.groupName != null ? 'Grupo: ${widget.groupName}' : 'Grupo', route: '/group/${widget.groupId}'),
                    BreadcrumbItem(widget.expenseToEdit != null ? 'Editando Gasto: ${widget.expenseToEdit!.description}' : 'Nuevo Gasto'),
                  ],
                  onTap: (i) {
                    if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                    if (i == 1) Navigator.pushReplacementNamed(context, '/group/${widget.groupId}');
                  },
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.expenseToEdit != null ? 'Editando Gasto' : 'Nuevo Gasto',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      _buildParticipantSelector(),
                      const SizedBox(height: 28),
                      // Monto y moneda alineados
                      Row(
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
                      ),
                      const SizedBox(height: 28),
                      // ¿Quién pagó? y Fecha en filas separadas
                      _buildPayers(),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Agregar imagen', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                        Text('Agregar', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                        decoration: _inputDecoration(label: 'Descripción', hint: 'Ej: bebidas'),
                        validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 28),
                      // Campo de categoría como dropdown
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
                              decoration: _inputDecoration(label: 'Categoría'),
                              validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                            ),
                          ),
                          if (_selectedCategory == 'otra')
                            const SizedBox(width: 12),
                          if (_selectedCategory == 'otra')
                            Expanded(
                              child: TextFormField(
                                controller: _categoryController,
                                decoration: _inputDecoration(label: 'Otra categoría'),
                                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Solo dejar la segunda sección de División
                      _buildSplitInputs(),
                      const SizedBox(height: 28),
                      _buildSummary(),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _loading ? null : () {
                            _submit();
                            // Limpiar campos para agregar otro gasto
                            setState(() {
                              _descController.clear();
                              _amountController.clear();
                              _customSplits.updateAll((key, value) => 0.0);
                              _payerAmounts.clear();
                              _selectedCategory = null;
                              _imagePath = null;
                            });
                          },
                          child: const Text('Guardar y agregar otro'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: Icon(widget.expenseToEdit != null ? Icons.save : Icons.add),
                          label: Text(widget.expenseToEdit != null ? 'Guardar cambios' : 'Agregar gasto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          onPressed: _loading ? null : _submit,
                        ),
                      ],
                    ),
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
