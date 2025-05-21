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
  bool _isDropdownHovered = false; // Variable para el estado hover del Dropdown

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

        // Determinar si es vista de escritorio
        final isDesktop = MediaQuery.of(context).size.width >= 600;

        if (isDesktop) {
          // Diseño para escritorio: gráfico a la izquierda, leyenda a la derecha
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2, // Gráfico toma más espacio
                    child: _buildChart(expenseProvider.expenses),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3, // Leyenda toma menos espacio o se ajusta
                    child: _buildLegend(expenseProvider.expenses),
                  ),
                ],
              ),
            ],
          );
        } else {
          // Diseño para móvil: gráfico arriba, leyenda abajo
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
        }
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
        MouseRegion(
          onEnter: (_) => setState(() => _isDropdownHovered = true),
          onExit: (_) => setState(() => _isDropdownHovered = false),
          child: Theme( // Envolver con Theme para anular todos los colores de estados del DropdownButton
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              // Ajustamos todos los colores que podrían afectar la apariencia después del clic
              buttonTheme: const ButtonThemeData(
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: _isDropdownHovered ? Colors.teal.withAlpha((0.05 * 255).round()) : Colors.white, // Fondo dinámico
                border: Border.all(
                  color: _isDropdownHovered ? Colors.teal : Colors.grey.shade300, // Borde dinámico
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                isDense: true, // Hace que el dropdown sea más compacto
                isExpanded: false,
                focusColor: Colors.transparent, // Color cuando tiene foco (importante después del clic)
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
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                dropdownColor: Colors.white,
                iconEnabledColor: Colors.teal, // Color del icono cuando está habilitado
                iconDisabledColor: Colors.grey,
                elevation: 3, // Elevación del menú desplegado
                // Agregamos el callback para reset del estado hover después del clic
                onTap: () {
                  // Pequeño truco para asegurar que el estado se actualice correctamente después del clic
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      setState(() {
                        // Asegura que el estado hover se actualice correctamente
                      });
                    }
                  });
                }
              ),
            ),
          ),
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
          sectionsSpace: 0, // Eliminamos el espacio entre secciones
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
                '$percentage%',
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

    // Añadir un divisor y el total general a la leyenda
    legendItems.add(
      Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Column(
          children: [
            const Divider(height: 1, thickness: 1), // Línea divisoria
            const SizedBox(height: 8), // Espacio después del divisor
            ListTile(
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
          ],
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
        title: '$percentage%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          // Eliminamos las sombras del texto
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

    // Ordenar gastos por fecha, más recientes primero
    final categoryExpenses = expenses
        .where((e) => (e.category ?? 'Uncategorized') == category)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    final totalAmount = categoryExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final categoryColor = getCategoryColor(category);
    
    // Calcular el porcentaje que representa esta categoría del total
    final allExpensesTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final categoryPercentage = allExpensesTotal > 0 
        ? ((totalAmount / allExpensesTotal) * 100).round() 
        : 0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Fondo transparente para el modal personalizado
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Tamaño inicial
          minChildSize: 0.4, // Tamaño mínimo
          maxChildSize: 0.9, // Tamaño máximo
          expand: false,
          builder: (_, scrollController) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
 color: Colors.black.withAlpha((0.1 * 255).round()),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cabecera con el color de la categoría
                      Container(
                        decoration: BoxDecoration(
 color: categoryColor.withAlpha((0.9 * 255).round()),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Barra de drag visual
                            Center(
                              child: Container(
                                height: 5,
                                width: 40,
                                decoration: BoxDecoration(
 color: Colors.white.withAlpha((0.5 * 255).round()),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Título y botón cerrar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    // Círculo con el color de la categoría
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      category.isNotEmpty ? category : 'Uncategorized',
                                      style: const TextStyle(
                                        fontSize: 22, 
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Información del total y porcentaje
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total gasto',
                                      style: TextStyle(
                                        fontSize: 14, 
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(totalAmount, currencyCode),
                                      style: const TextStyle(
                                        fontSize: 24, 
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
 color: Colors.white.withAlpha((0.2 * 255).round()),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$categoryPercentage% del total',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Lista de gastos
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Gastos recientes (${categoryExpenses.length})',
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),
                      
                      // Lista de gastos con scroll
                      Expanded(
                        child: categoryExpenses.isEmpty 
                          ? const Center(child: Text('No hay gastos registrados'))
                          : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: categoryExpenses.length,
                            itemBuilder: (context, index) {
                              final expense = categoryExpenses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              expense.description,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            formatCurrency(expense.amount, currencyCode),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: categoryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('dd MMM, yyyy').format(expense.date),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ),
                    ],
                  ),
                ),
                
                // Botón de acción flotante
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    onPressed: () {
                      // Aquí se podría implementar la funcionalidad para agregar un nuevo gasto en esta categoría
                      Navigator.of(context).pop();
                    },
                    backgroundColor: categoryColor,
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            );
          },
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
