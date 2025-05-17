import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../config/category_colors.dart';
import '../utils/formatters.dart'; // Importar formatters

class CategorySpendingChart extends StatefulWidget {
  final String? groupId;
  
  const CategorySpendingChart({super.key, required this.groupId});
  
  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

class _CategorySpendingChartState extends State<CategorySpendingChart> {
  String _selectedPeriod = 'this_month';
  DateTimeRange? _customDateRange;
  bool _initialRenderComplete = false; // Nueva bandera

  final Map<String, String> _periods = {
    'this_month': 'This month',
    'last_month': 'Last month',
    'custom': 'Custom range',
  };

  @override
  void initState() { // Nuevo método initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _initialRenderComplete = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return const SizedBox.shrink();
    }
    
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, _) {
        if (expenseProvider.expenses.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No expenses to show in this group.'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildChart(expenseProvider.expenses),
            const SizedBox(height: 8),
            _buildLegend(expenseProvider.expenses),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Category Spending',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        DropdownButton<String>(
          value: _selectedPeriod,
          items: _periods.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == 'custom') {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020, 1),
                lastDate: DateTime(2100),
                initialDateRange: _customDateRange,
              );
              if (picked != null) {
                setState(() {
                  _customDateRange = picked;
                  _selectedPeriod = value!;
                });
              }
            } else {
              setState(() {
                _selectedPeriod = value!;
              });
            }
          },
          underline: const SizedBox(),
        ),
      ],
    );
  }


  Widget _buildChart(List<ExpenseModel> expenses) {
    final filteredExpenses = _filterExpensesByPeriod(expenses);
    final categoryData = _calculateCategoryData(filteredExpenses);
    
    if (categoryData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No expense data to display'),
        ),
      );
    }

    // Obtener el código de moneda de los gastos filtrados
    final String currencyCode = filteredExpenses.isNotEmpty ? filteredExpenses.first.currency : '';

    return SizedBox(
      height: 200,
      child: PieChart( // Se elimina el Stack y el Center para quitar el total del centro
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 60, // Aumentar para un agujero central más grande
          sections: _buildChartSections(categoryData),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
              // print('PieChart Touch Event: $event, Response: $pieTouchResponse'); // Log para depuración
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                return;
              }
              // Solo mostrar detalles en el evento de FlTapUpEvent
              if (event is FlTapUpEvent) {
                final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                if (touchedIndex >= 0 && touchedIndex < categoryData.length) {
                  final category = categoryData[touchedIndex].category;
                  // Pasar currencyCode a _showCategoryDetails
                  _showCategoryDetails(category, filteredExpenses, currencyCode);
                }
              }
            },
          ),
        ),
      ),
    );
  }

  
  Widget _buildLegend(List<ExpenseModel> expenses) {
    final filteredExpenses = _filterExpensesByPeriod(expenses);
    final categoryData = _calculateCategoryData(filteredExpenses);
    final overallTotalAmount = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount); // Total general
    
    if (categoryData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Obtener el código de moneda de los gastos filtrados
    final String currencyCode = filteredExpenses.isNotEmpty ? filteredExpenses.first.currency : '';

    List<Widget> legendItems = categoryData.map((data) {
      final categoryTotalAmount = categoryData.fold<double>(0, (sum, item) => sum + item.amount); // Suma de los montos de las categorías para el porcentaje
      final percentage = categoryTotalAmount > 0 ? (data.amount / categoryTotalAmount * 100).round() : 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0), // Reducir padding vertical
        child: ListTile(
          dense: true, // Hacer ListTile más compacto
          leading: Container(
            width: 18, // Ligeramente más pequeño
            height: 18, // Ligeramente más pequeño
            decoration: BoxDecoration(
              color: getCategoryColor(data.category),
              shape: BoxShape.circle,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  data.category.isNotEmpty ? data.category : 'Uncategorized',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '${percentage}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          trailing: Text(
            // Usar formatCurrency para el monto de la categoría
            formatCurrency(data.amount, currencyCode), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          // Pasar currencyCode a _showCategoryDetails
          onTap: () => _showCategoryDetails(data.category, filteredExpenses, currencyCode),
        ),
      );
    }).toList();

    // Añadir el total general a la leyenda
    legendItems.add(
      Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: ListTile(
          dense: true,
          title: const Text(
            'Overall Total',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            // Usar formatCurrency para el total general
            formatCurrency(overallTotalAmount, currencyCode),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      )
    );

    return Column(
      children: legendItems,
    );
  }

  List<PieChartSectionData> _buildChartSections(List<CategoryData> categoryData) {
    final totalAmount = categoryData.fold<double>(0, (sum, data) => sum + data.amount);
    // int? touchedIndex = -1; // Variable para manejar el índice tocado si se implementa lógica de resaltado

    return List.generate(categoryData.length, (i) {
      final data = categoryData[i];
      // final isTouched = i == touchedIndex; // Lógica para determinar si la sección está tocada
      const fontSize = 14.0; // Tamaño de fuente constante por ahora
      const radius = 50.0;   // Radio constante por ahora
      final percentage = totalAmount > 0 ? (data.amount / totalAmount * 100).round() : 0;

      return PieChartSectionData(
        color: getCategoryColor(data.category),
        value: data.amount,
        title: '${percentage}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [const Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    });
  }

  List<ExpenseModel> _filterExpensesByPeriod(List<ExpenseModel> expenses) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    
    return expenses.where((expense) {
      if (_selectedPeriod == 'this_month') {
        return expense.date.isAfter(currentMonth);
      } else if (_selectedPeriod == 'last_month') {
        return expense.date.isAfter(lastMonth) && expense.date.isBefore(currentMonth);
      } else if (_selectedPeriod == 'custom' && _customDateRange != null) {
        return expense.date.isAfter(_customDateRange!.start) && 
               expense.date.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
      }
      return true;
    }).toList();
  }

  List<CategoryData> _calculateCategoryData(List<ExpenseModel> expenses) {
    final categoryMap = <String, double>{};
    
    for (final expense in expenses) {
      final category = expense.category ?? 'Sin categoría';
      categoryMap[category] = (categoryMap[category] ?? 0) + expense.amount;
    }
    
    // Ordenar por monto descendente
    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedCategories
        .map((e) => CategoryData(e.key, e.value))
        .toList();
  }
  
  // Modificar la firma para aceptar currencyCode
  void _showCategoryDetails(String category, List<ExpenseModel> expenses, String currencyCode) {
    if (!mounted || !_initialRenderComplete) return; // Comprobar la bandera y si está montado

    final categoryExpenses = expenses
        .where((e) => (e.category ?? 'Uncategorized') == category)
        .toList();
    
    final totalAmount = categoryExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal sea más alto
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets, // Para evitar que el teclado cubra el modal
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.isNotEmpty ? category : 'Uncategorized',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  // Usar formatCurrency para el total en el modal
                  'Total: ${formatCurrency(totalAmount, currencyCode)}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recent expenses:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Flexible( // Usar Flexible en lugar de Expanded para que tome el espacio necesario
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: categoryExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = categoryExpenses[index];
                      return ListTile(
                        title: Text(expense.description),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(expense.date)),
                        trailing: Text(
                          // Usar formatCurrency para cada gasto en el modal
                          formatCurrency(expense.amount, currencyCode),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryData {
  final String category;
  final double amount;
  
  CategoryData(this.category, this.amount);
}
