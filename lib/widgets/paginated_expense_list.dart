import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../widgets/expense_tile.dart';
import '../utils/formatters.dart'; 

typedef ShowExpenseDetailCallback = void Function(BuildContext context, ExpenseModel expense, String groupName, Map<String, UserModel> usersById);

class PaginatedExpenseList extends StatefulWidget {
  final List<ExpenseModel> expenses;
  final Map<String, UserModel> usersById;
  final String currentUserId;
  final String groupName;
  final ShowExpenseDetailCallback showExpenseDetail;

  const PaginatedExpenseList({
    super.key,
    required this.expenses,
    required this.usersById,
    required this.currentUserId,
    required this.groupName,
    required this.showExpenseDetail,
  });

  @override
  _PaginatedExpenseListState createState() => _PaginatedExpenseListState();
}

class _PaginatedExpenseListState extends State<PaginatedExpenseList> {
  int currentPage = 0;
  static const int pageSize = 15; // Reducido para mejor visualización en móviles

  @override
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty) {
      return const Center(child: Text('No expenses recorded for this group yet.'));
    }

    final pageCount = (widget.expenses.length / pageSize).ceil();
    final start = currentPage * pageSize;
    final end = (start + pageSize > widget.expenses.length) ? widget.expenses.length : start + pageSize;
    final pageExpenses = widget.expenses.sublist(start, end);

    final Map<String, List<ExpenseModel>> groupedByDate = {};
    for (final e in pageExpenses) {
      // Utiliza el formateador de fecha importado desde utils/formatters.dart
      final key = formatDateShort(e.date.toLocal()); // Corregido a formatDateShort
      groupedByDate.putIfAbsent(key, () => []).add(e);
    }
    final sortedDateKeys = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a)); // Asumiendo que formatDate produce un string comparable cronológicamente

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sortedDateKeys.map((dateStr) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
              child: Text(
                dateStr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.teal),
              ),
            ),
            ...groupedByDate[dateStr]!.map((e) => ExpenseTile(
              expense: e,
              usersById: widget.usersById,
              currentUserId: widget.currentUserId,
              onTap: () => widget.showExpenseDetail(context, e, widget.groupName, widget.usersById),
            )),
            const SizedBox(height: 10),
          ],
        )),
        if (pageCount > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left_rounded),
                    onPressed: currentPage > 0 ? () => _goToPage(currentPage - 1) : null,
                    color: Colors.grey[700],
                    splashRadius: 22,
                    tooltip: 'Previous Page',
                  ),
                  ..._buildPaginationButtons(currentPage, pageCount, _goToPage),
                  IconButton(
                    icon: const Icon(Icons.arrow_right_rounded),
                    onPressed: currentPage < pageCount - 1 ? () => _goToPage(currentPage + 1) : null,
                    color: Colors.grey[700],
                    splashRadius: 22,
                    tooltip: 'Next Page',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _goToPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  List<Widget> _buildPaginationButtons(int currentPage, int pageCount, Function(int) goToPage) {
    List<Widget> buttons = [];
    const int maxVisibleButtons = 5; // Número de botones de página visibles a la vez

    if (pageCount <= maxVisibleButtons) {
      for (int i = 0; i < pageCount; i++) {
        buttons.add(_paginationButton(i, currentPage, goToPage));
      }
    } else {
      // Siempre mostrar el primer botón
      buttons.add(_paginationButton(0, currentPage, goToPage));

      // Calcular el rango de botones intermedios
      int startPage;
      int endPage;

      if (currentPage < maxVisibleButtons - 2) { // Cerca del inicio
        startPage = 1;
        endPage = maxVisibleButtons - 2;
        buttons.add(_paginationButton(startPage, currentPage, goToPage)); // Asegurar que el 2do botón se muestre si es necesario
        for (int i = startPage + 1; i <= endPage; i++) {
           buttons.add(_paginationButton(i, currentPage, goToPage));
        }
        if (endPage < pageCount - 2) {
             buttons.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('...')));
        }
      } else if (currentPage > pageCount - (maxVisibleButtons - 2)) { // Cerca del final
        startPage = pageCount - (maxVisibleButtons - 1);
         if (startPage > 1) {
            buttons.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('...')));
        }
        for (int i = startPage; i < pageCount -1; i++) {
           buttons.add(_paginationButton(i, currentPage, goToPage));
        }
      } else { // En el medio
        buttons.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('...')));
        for (int i = currentPage - 1; i <= currentPage + 1; i++) {
          buttons.add(_paginationButton(i, currentPage, goToPage));
        }
        buttons.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('...')));
      }
      // Siempre mostrar el último botón
      buttons.add(_paginationButton(pageCount - 1, currentPage, goToPage));
    }
    return buttons;
  }

  Widget _paginationButton(int pageIndex, int currentPage, Function(int) goToPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: MaterialButton(
        minWidth: 40,
        height: 40,
        color: pageIndex == currentPage ? Colors.teal : Colors.grey[200],
        textColor: pageIndex == currentPage ? Colors.white : Colors.black,
        onPressed: () => goToPage(pageIndex),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: pageIndex == currentPage ? 2.0 : 0.0,
        child: Text((pageIndex + 1).toString()),
      ),
    );
  }
}
