import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../config/category_colors.dart';
import '../utils/formatters.dart'; // Importar formatters
import '../providers/group_provider.dart'; // Añadir esta

class CategorySpendingChart extends StatefulWidget {
  final String? groupId;
  
  const CategorySpendingChart({super.key, required this.groupId});
  
  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

// Añadir SingleTickerProviderStateMixin para el AnimationController
class _CategorySpendingChartState extends State<CategorySpendingChart> with TickerProviderStateMixin {
  String _selectedPeriod = 'this_month';
  DateTimeRange? _customDateRange;
  bool _initialRenderComplete = false; // Nueva bandera
  bool _isDropdownHovered = false; // Variable para el estado hover del Dropdown
  String? _selectedGroupIdInChart; // Nuevo: para el grupo seleccionado en el gráfico

  // Para animación de carga
  AnimationController? _loadAnimationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  bool _hasLoadAnimationPlayed = false;

  // Para animación de hover en secciones del gráfico
  int _hoveredSectionIndex = -1;
  AnimationController? _hoverAnimationController;

  final Map<String, String> _periods = {
    'this_month': 'This month',
    'last_month': 'Last month',
    'custom': 'Custom range',
  };

  @override
  void initState() {
    super.initState();
    _selectedGroupIdInChart = widget.groupId;

    _loadAnimationController = AnimationController(
      duration: const Duration(milliseconds: 650), // Duración de la animación de carga
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _loadAnimationController!,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Empezar desde un poco abajo
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _loadAnimationController!,
      curve: Curves.easeOutCubic, // Curva suave para el slide
    ));

    _hoverAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Duración de la animación de hover
      vsync: this,
    )..addListener(() { // Listener movido aquí
      if (mounted) {
        setState(() {}); // Reconstruir para aplicar el valor de animación
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Cargar gastos para el grupo inicial seleccionado si existe
        if (_selectedGroupIdInChart != null) {
          Provider.of<ExpenseProvider>(context, listen: false).loadExpenses(_selectedGroupIdInChart!);
        }
        setState(() {
          _initialRenderComplete = true;
          // La animación de carga se disparará en _buildChart cuando haya datos
        });
      }
    });
  }

  @override
  void dispose() {
    _loadAnimationController?.dispose();
    _hoverAnimationController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CategorySpendingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupId != oldWidget.groupId) {
      setState(() {
        _selectedGroupIdInChart = widget.groupId;
        _selectedPeriod = 'this_month';
        _customDateRange = null;
      });
      if (_selectedGroupIdInChart != null) {
         Provider.of<ExpenseProvider>(context, listen: false).loadExpenses(_selectedGroupIdInChart!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return const SizedBox.shrink();
    }

    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, _) {
        // Filter expenses and calculate category data
        final filteredExpensesForChart = _filterExpensesByPeriod(expenseProvider.expenses);
        final finalCategoryData = _calculateCategoryData(filteredExpensesForChart);

        Widget chartOrEmptyMessageWidget;

        if (finalCategoryData.isEmpty) {
          _hasLoadAnimationPlayed = false;
          chartOrEmptyMessageWidget = const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No expense data to display for the selected period.'),
            ),
          );
        } else {
          if (!_hasLoadAnimationPlayed) {
            _loadAnimationController?.forward(from: 0.0);
            _hasLoadAnimationPlayed = true;
          }
          // Obtener el código de moneda de los gastos filtrados
          final String currencyCode = filteredExpensesForChart.isNotEmpty ? filteredExpensesForChart.first.currency : '';
          chartOrEmptyMessageWidget = PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 60,
              sections: _buildChartSections(finalCategoryData), // Use finalCategoryData
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions) {
                      if (_hoveredSectionIndex != -1) {
                        _hoverAnimationController?.reverse();
                        _hoveredSectionIndex = -1;
                      }
                      return;
                    }

                    if (event is FlPointerHoverEvent || event is FlTapDownEvent) {
                      if (pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                        if (_hoveredSectionIndex != pieTouchResponse.touchedSection!.touchedSectionIndex) {
                          _hoveredSectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          _hoverAnimationController?.forward(from: 0.0);
                        } else if (!_hoverAnimationController!.isAnimating && _hoverAnimationController!.status == AnimationStatus.dismissed) {
                          _hoverAnimationController?.forward(from: 0.0);
                        }
                      } else {
                        if (_hoveredSectionIndex != -1) {
                          _hoverAnimationController?.reverse();
                          _hoveredSectionIndex = -1;
                        }
                      }
                    } else if (event is FlPointerExitEvent) {
                      if (_hoveredSectionIndex != -1) {
                        _hoverAnimationController?.reverse();
                        _hoveredSectionIndex = -1;
                      }
                    }
                  });

                  if (event is FlTapUpEvent) {
                    final touchedIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex;
                    // Use finalCategoryData here
                    if (touchedIndex != null && touchedIndex >= 0 && touchedIndex < finalCategoryData.length) {
                      final categoryKey = finalCategoryData[touchedIndex].category;
                      // Use filteredExpensesForChart here
                      _showCategoryDetails(categoryKey, filteredExpensesForChart, currencyCode);
                    }
                  }
                },
              ),
            ),
          );
        }

        final Widget animatedChartArea = FadeTransition(
          opacity: _fadeAnimation!,
          child: SlideTransition(
            position: _slideAnimation!,
            child: SizedBox(
              height: 200,
              child: chartOrEmptyMessageWidget,
            ),
          ),
        );

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
                    child: animatedChartArea,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3, // Leyenda toma menos espacio o se ajusta
                    // Conditionally render legend
                    child: finalCategoryData.isNotEmpty ? _buildLegend(expenseProvider.expenses) : const SizedBox.shrink(),
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
              animatedChartArea,
              const SizedBox(height: 8),
              // Conditionally render legend
              if (finalCategoryData.isNotEmpty) _buildLegend(expenseProvider.expenses),
            ],
          );
        }
      },
    );
  }

  Widget _buildHeader() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final availableGroups = groupProvider.groups;
    final isMobile = MediaQuery.of(context).size.width < 1000; // Para consistencia de estilo

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start, // Cambiado de .center a .start
          children: [
            // Título con icono
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded, color: Colors.black54, size: isMobile ? 20 : 22),
                const SizedBox(width: 8),
                Text(
                  'Category Spending',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 18 : 20,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            // Selector de período
            MouseRegion(
              onEnter: (_) => setState(() => _isDropdownHovered = true),
              onExit: (_) => setState(() => _isDropdownHovered = false),
              child: Theme( // Envolver con Theme para anular todos los colores de estados del DropdownButton
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
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
                    isDense: true,
                    isExpanded: false,
                    focusColor: Colors.transparent,
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
                    iconEnabledColor: Colors.teal,
                    iconDisabledColor: Colors.grey,
                    elevation: 3,
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          setState(() {
                          });
                        }
                      });
                    }
                  ),
                ),
              ),
            ),
          ],
        ),
        if (availableGroups.isNotEmpty && availableGroups.length > 1) ...[ // Mostrar solo si hay más de un grupo
          const SizedBox(height: 12),
          Padding( // Envolver el Row del selector de grupo con Padding
            padding: const EdgeInsets.only(right: 0), // Asegurar que no haya padding a la derecha
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Selected Group:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedGroupIdInChart,
                    items: availableGroups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(group.name, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (newGroupId) {
                      if (newGroupId != null && newGroupId != _selectedGroupIdInChart) {
                        Provider.of<ExpenseProvider>(context, listen: false).loadExpenses(newGroupId);
                        setState(() {
                          _selectedGroupIdInChart = newGroupId;
                          _selectedPeriod = 'this_month'; // Resetear período
                          _customDateRange = null;      // Resetear rango custom
                        });
                      }
                    },
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // _buildChart is no longer needed as its logic is moved to the main build method.
  // Consider removing _buildChart if it's not used elsewhere, or simplify it if it still has a purpose.
  // For now, we'll keep it commented out or remove it later if confirmed it's entirely redundant.
  /* 
  Widget _buildChart(List<ExpenseModel> expenses) {
    // This logic is now in the main build method.
    // ...
  }
  */
  
  Widget _buildLegend(List<ExpenseModel> expenses) {
    // Note: _buildLegend is called with expenseProvider.expenses.
    // It internally filters by period and calculates category data.
    // This is consistent with its previous behavior.
    // If _buildLegend should use pre-filtered expenses (filteredExpensesForChart from build method),
    // then its signature and internal logic would need to change.
    // For now, keeping it as is, assuming it needs the full list to potentially show different totals or details.
    final filteredExpenses = _filterExpensesByPeriod(expenses);
    final categoryData = _calculateCategoryData(filteredExpenses);
    final overallTotalAmount = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount); // Total general
    
    // This check might seem redundant if _buildLegend is only called when finalCategoryData is not empty.
    // However, _buildLegend does its own filtering. If the main build method's finalCategoryData
    // is based on filteredExpensesForChart, and _buildLegend also filters expenseProvider.expenses,
    // they should ideally yield the same emptiness state for the *selected period*.
    // If there's a possibility of discrepancy (e.g. different filtering logic or timing), this check is a safeguard.
    // For now, assuming the filtering in build() and buildLegend() for the selected period will be consistent.
    if (categoryData.isEmpty) {
      return const SizedBox.shrink(); 
    }

    // Obtener el código de moneda de los gastos filtrados
    final String currencyCode = filteredExpenses.isNotEmpty ? filteredExpenses.first.currency : '';

    List<Widget> legendItems = categoryData.map((data) {
      final categoryTotalAmount = categoryData.fold<double>(0, (sum, item) => sum + item.amount); // Suma de los montos de las categorías para el porcentaje
      final percentage = categoryTotalAmount > 0 ? (data.amount / categoryTotalAmount * 100).round() : 0;
      final categoryDisplayLabel = _getCategoryDisplayLabel(data.category); // Obtener el label

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0), // Reducir padding vertical
        child: ListTile(
          dense: true, // Hacer ListTile más compacto
          leading: Container(
            width: 18, // Ligeramente más pequeño
            height: 18, // Ligeramente más pequeño
            decoration: BoxDecoration(
              color: getCategoryColor(data.category), // Usar la key para el color
              shape: BoxShape.circle,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  categoryDisplayLabel, // Usar el label para mostrar
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
          // Pasar la key de la categoría a _showCategoryDetails
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

    return List.generate(categoryData.length, (i) {
      final data = categoryData[i];
      final bool currentlyTouched = i == _hoveredSectionIndex;
      
      // Usar el valor de _hoverAnimation para interpolar radio y fontSize
      final double animationFactor = (_hoverAnimationController?.value ?? 0.0);
      final double radius = 55.0 + (10.0 * (currentlyTouched ? animationFactor : 0.0));
      final double fontSize = 14.0 + (3.0 * (currentlyTouched ? animationFactor : 0.0));

      // Propiedades que cambian con la animación de hover
      // Se reduce el umbral de animationFactor de 0.5 a 0.2 para que el efecto sea visible antes
      final Color titleColor = currentlyTouched && animationFactor > 0.2 ? Colors.white : Colors.white.withOpacity(0.9);
      final List<BoxShadow>? shadows = currentlyTouched && animationFactor > 0.2
          ? [
              const BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: Offset(1, 1)), // Sombra direccional sutil
              const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(0, 0)) // Sombra ambiental más suave
            ]
          : null;

      final percentage = totalAmount > 0 ? (data.amount / totalAmount * 100).round() : 0;

      return PieChartSectionData(
        color: getCategoryColor(data.category),
        value: data.amount,
        title: '$percentage%',
        radius: radius, // Usar radio animado
        titleStyle: TextStyle(
          fontSize: fontSize, // Usar tamaño de fuente animado
          fontWeight: FontWeight.bold,
          color: titleColor, // Usar color de título modificado
          shadows: shadows,  // Usar sombras modificadas
        ),
        borderSide: BorderSide.none, // Asegurar que no haya borde
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
  void _showCategoryDetails(String categoryKey, List<ExpenseModel> expenses, String currencyCode) { // categoryKey en lugar de category
    if (!mounted || !_initialRenderComplete) return;

    final categoryDisplayLabel = _getCategoryDisplayLabel(categoryKey); // Obtener el label

    // Ordenar gastos por fecha, más recientes primero
    final categoryExpenses = expenses
        .where((e) => (e.category ?? 'Uncategorized') == categoryKey) // Filtrar por key
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    final totalAmount = categoryExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final categoryColor = getCategoryColor(categoryKey); // Usar key para el color
    
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
            return Container(
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
                                    color: Colors.white, // El círculo interior es blanco
                                    shape: BoxShape.circle,
                                    // El borde puede ser del color de la categoría si se desea, o simplemente blanco
                                    border: Border.all(color: categoryColor, width: 2), 
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  categoryDisplayLabel, // Usar el label para mostrar
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
            );
          },
        );
      },
    );
  }

  // Helper para obtener el label de la categoría
  String _getCategoryDisplayLabel(String categoryKey) {
    // Asumiendo que tienes un mapa o una lógica para convertir keys a labels
    // Este es un ejemplo, deberás adaptarlo a tu estructura de datos de categorías
    const categoryLabels = {
      'food': 'Food',
      'transport': 'Transport',
      'housing': 'Housing',
      'utilities': 'Utilities',
      'entertainment': 'Entertainment',
      'health': 'Health',
      'education': 'Education',
      'apparel': 'Apparel',
      'personal_care': 'Personal Care',
      'gifts_donations': 'Gifts & Donations',
      'travel': 'Travel',
      'debt_payments': 'Debt Payments',
      'savings_investments': 'Savings & Investments',
      'pets': 'Pets',
      'office_supplies': 'Office Supplies',
      'subscriptions': 'Subscriptions',
      'taxes': 'Taxes',
      'insurance': 'Insurance',
      'other': 'Other',
      'uncategorized': 'Uncategorized',
      'sin_categoría': 'Uncategorized', // Asegúrate de manejar también esta key si se usa
    };
    return categoryLabels[categoryKey.toLowerCase()] ?? categoryKey; // Devuelve la key si no se encuentra el label
  }
}

class CategoryData {
  final String category;
  final double amount;
  
  CategoryData(this.category, this.amount);
}

// Define CategoryExpenseList StatefulWidget BEFORE _CategorySpendingChartState
class CategoryExpenseList extends StatefulWidget {
  final ScrollController scrollController;
  final String selectedGroupId;
  final String categoryKey;
  final String currencyCode;
  final Color categoryColor;
  final String categoryDisplayLabel;

  const CategoryExpenseList({
    super.key,
    required this.scrollController,
    required this.selectedGroupId,
    required this.categoryKey,
    required this.currencyCode,
    required this.categoryColor,
    required this.categoryDisplayLabel,
  });

  @override
  State<CategoryExpenseList> createState() => _CategoryExpenseListState();
}

class _CategoryExpenseListState extends State<CategoryExpenseList> {
  late ExpenseProvider _expenseProvider;

  @override
  void initState() {
    super.initState();
    // It's important to get the provider instance without listening here,
    // as the Consumer widget will handle rebuilding on changes.
    _expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.scrollController.position.pixels == widget.scrollController.position.maxScrollExtent &&
        _expenseProvider.hasMoreExpenses &&
        !_expenseProvider.loadingMoreExpenses) {
      _expenseProvider.loadMoreExpenses(widget.selectedGroupId);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    // Do not dispose the scrollController itself as it's managed by DraggableScrollableSheet
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final allGroupExpenses = expenseProvider.expenses;
        final categoryExpenses = allGroupExpenses
            .where((e) => (e.category ?? 'Uncategorized') == widget.categoryKey)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date, most recent first

        final totalAmountForCategory = categoryExpenses.fold<double>(0, (sum, e) => sum + e.amount);
        
        final allExpensesTotalInGroup = allGroupExpenses.fold<double>(0, (sum, e) => sum + e.amount);
        final categoryPercentage = allExpensesTotalInGroup > 0 
            ? ((totalAmountForCategory / allExpensesTotalInGroup) * 100).round() 
            : 0;

        return Container(
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
            // mainAxisSize: MainAxisSize.min, // This might not be needed if Column is child of Expanded
            children: [
              // Header Section
              Container(
                decoration: BoxDecoration(
                  color: widget.categoryColor.withAlpha((0.9 * 255).round()),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: widget.categoryColor, width: 2), 
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.categoryDisplayLabel,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total gasto',
                              style: TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                            Text(
                              formatCurrency(totalAmountForCategory, widget.currencyCode),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Gastos (${categoryExpenses.length})', // Updated to show current count
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              
              Expanded(
                child: categoryExpenses.isEmpty && !expenseProvider.loadingMoreExpenses
                  ? const Center(child: Text('No hay gastos registrados para esta categoría.'))
                  : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: categoryExpenses.length + (expenseProvider.loadingMoreExpenses ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == categoryExpenses.length) { // This is the loading indicator item
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0), // Increased padding
                            child: expenseProvider.hasMoreExpenses 
                                   ? const CircularProgressIndicator()
                                   : const Text("No más gastos por cargar."), // Message when no more expenses
                          ),
                        );
                      }
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
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(expense.amount, widget.currencyCode), // Use widget.currencyCode
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: widget.categoryColor, // Use widget.categoryColor
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [ // Removed MainAxisAlignment.spaceBetween
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd MMM, yyyy').format(expense.date),
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
        );
      },
    );
  }
}
