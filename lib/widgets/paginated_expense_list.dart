import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../providers/expense_provider.dart'; // Import ExpenseProvider
import '../widgets/expense_tile.dart';
import '../utils/formatters.dart';

typedef ShowExpenseDetailCallback = void Function(
    BuildContext context, ExpenseModel expense, String groupName, Map<String, UserModel> usersById);

class PaginatedExpenseList extends StatefulWidget {
  final String groupId; // Nuevo: para cargar y observar los gastos correctos
  final Map<String, UserModel> usersById;
  final String currentUserId;
  final String groupName;
  final ShowExpenseDetailCallback showExpenseDetail;

  const PaginatedExpenseList({
    super.key,
    required this.groupId, // Añadido
    required this.usersById,
    required this.currentUserId,
    required this.groupName,
    required this.showExpenseDetail,
  });

  @override
  _PaginatedExpenseListState createState() => _PaginatedExpenseListState();
}

class _PaginatedExpenseListState extends State<PaginatedExpenseList> {
  final ScrollController _scrollController = ScrollController();
  late ExpenseProvider _expenseProvider;

  @override
  void initState() {
    super.initState();
    _expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    // La carga inicial de gastos para el grupo se maneja en GroupDetailScreen.
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Cargar más cuando el usuario está cerca del final de la lista (ej. a 200px del final)
    // y hay más gastos por cargar, y no se está cargando actualmente.
    // También verificar que el provider esté manejando el groupId correcto.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        _expenseProvider.hasMoreExpenses &&
        !_expenseProvider.loadingMoreExpenses &&
        _expenseProvider.currentGroupId == widget.groupId) {
      _expenseProvider.loadMoreExpenses(widget.groupId);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        // Si el provider está mostrando datos de un grupo diferente al actual
        // y no está en proceso de cargar los del grupo actual,
        // esto podría indicar que la carga inicial desde GroupDetailScreen aún no se ha completado
        // o no se disparó. En un escenario ideal, GroupDetailScreen ya habría llamado a loadExpenses.
        if (expenseProvider.currentGroupId != widget.groupId && !expenseProvider.loadingExpenses) {
          // Podrías mostrar un loader o un mensaje aquí, o confiar en que GroupDetailScreen
          // maneje el estado de carga inicial. Por ahora, si los gastos están vacíos y se está cargando,
          // el siguiente bloque lo manejará.
        }
        
        final expensesToDisplay = expenseProvider.expenses;

        // Caso 1: No hay gastos y no se está cargando nada (ni inicial ni más).
        if (expensesToDisplay.isEmpty && !expenseProvider.loadingExpenses && !expenseProvider.loadingMoreExpenses) {
          return const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0), // Añadir padding para que no esté pegado
            child: Text('No expenses recorded for this group yet.'),
          ));
        }
        
        // Caso 2: No hay gastos aún, pero se está en proceso de carga (inicial o más).
        // O también si hay gastos pero se está cargando la primera página (loadingExpenses = true)
        if ((expensesToDisplay.isEmpty && (expenseProvider.loadingExpenses || expenseProvider.loadingMoreExpenses)) || expenseProvider.loadingExpenses) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ));
        }

        // Agrupar gastos por fecha para la visualización
        final Map<DateTime, List<ExpenseModel>> groupedByDate = {};
        for (final e in expensesToDisplay) {
          final dateKey = DateTime(e.date.year, e.date.month, e.date.day);
          groupedByDate.putIfAbsent(dateKey, () => []).add(e);
        }
        
        final sortedDateKeys = groupedByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // Más recientes primero

        // El itemCount necesita considerar los grupos de fechas, el loader y el mensaje de "no más gastos".
        // Como ahora agrupamos, el ListView.builder principal iterará sobre las fechas.
        // El ScrollController se aplica a este ListView.
        return ListView.builder(
          controller: _scrollController,
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), // El scroll principal es manejado por SingleChildScrollView en GroupDetailScreen
          // El itemCount será la cantidad de grupos de fechas + 1 para el loader/mensaje final.
          itemCount: sortedDateKeys.length + 1, 
          itemBuilder: (context, index) {
            // Si el índice corresponde al item después de todas las fechas, es para el loader o mensaje.
            if (index == sortedDateKeys.length) { 
              if (expenseProvider.loadingMoreExpenses) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ));
              } else if (!expenseProvider.hasMoreExpenses && expensesToDisplay.isNotEmpty) {
                 return const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text("No more expenses to load.", style: TextStyle(color: Colors.grey)),
                ));
              }
              return const SizedBox.shrink(); // No mostrar nada si no está cargando y hay más o si la lista está vacía inicialmente
            }
            
            // Seguridad: si por alguna razón el índice está fuera de rango para sortedDateKeys.
            if (index >= sortedDateKeys.length) {
                return const SizedBox.shrink(); 
            }

            final dateKey = sortedDateKeys[index];
            final expensesForDate = groupedByDate[dateKey]!;
            
            // Retornar una columna para cada grupo de fecha
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                  child: Text(
                    formatDateShort(dateKey.toLocal()),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.teal),
                  ),
                ),
                // ListView.builder anidado para los gastos de esa fecha (no es lo ideal para performance si son muchos)
                // Sería mejor un Column directamente si no son demasiados por día.
                // Por simplicidad y consistencia con el código original, se usa map.
                ...expensesForDate.map((e) => ExpenseTile(
                  expense: e,
                  usersById: widget.usersById,
                  currentUserId: widget.currentUserId,
                  onTap: () => widget.showExpenseDetail(context, e, widget.groupName, widget.usersById),
                )),
                const SizedBox(height: 10), // Espacio después de cada grupo de fecha
              ],
            );
          },
        );
      },
    );
  }
}
