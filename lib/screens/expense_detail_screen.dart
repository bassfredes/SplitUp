import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../utils/formatters.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String groupId;
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.groupId, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  ExpenseModel? expense;
  // Optimización: Recibir mapa de participantes en lugar de lista
  Map<String, UserModel> participantsMap = {};
  bool loading = true;
  String? error;
  // Optimización: Recibir nombre del grupo
  String? groupName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leer argumentos aquí porque dependen del context
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      groupName = arguments['groupName'] as String?;
      participantsMap = arguments['participantsMap'] as Map<String, UserModel>? ?? {};
    }
    // Cargar solo el gasto si no se ha hecho ya
    if (loading && expense == null) {
       _loadExpense();
    }
  }

  // Optimización: Renombrar y simplificar la función
  Future<void> _loadExpense() async {
    // Asegurarse de no volver a cargar si ya está cargando o cargado
    if (!loading && expense != null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Ya no se necesita buscar el grupo
      // final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
      // groupName = groupDoc.exists ? groupDoc.data()!["name"] as String? : null;

      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(widget.expenseId)
          .get();

      if (!doc.exists) {
        setState(() {
          error = 'Gasto no encontrado';
          loading = false;
        });
        return;
      }

      final exp = ExpenseModel.fromMap(doc.data()!, doc.id);

      // Ya no se necesita buscar participantes, usar el mapa pasado
      // final usersSnap = await FirebaseFirestore.instance
      //     .collection('users')
      //     .where(FieldPath.documentId, whereIn: exp.participantIds)
      //     .get();
      // participants = usersSnap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();

      // Validar que los participantes del gasto estén en el mapa (deberían)
      final missingParticipants = exp.participantIds.where((id) => !participantsMap.containsKey(id)).toList();
      if (missingParticipants.isNotEmpty) {
        debugPrint("[WARN] ExpenseDetailScreen: Faltan participantes en el mapa pasado: $missingParticipants");
        // Opcional: Podrías intentar cargarlos aquí como fallback, pero idealmente no debería pasar.
      }

      setState(() {
        expense = exp;
        loading = false;
      });
    } catch (e, stacktrace) {
      debugPrint("Error loading expense: $e\n$stacktrace");
      setState(() {
        error = 'Error al cargar el gasto';
        loading = false;
      });
    }
  }

  // Optimización: Usar el mapa de participantes
  String _getUserName(String id) {
    return participantsMap[id]?.name ?? 'Usuario desconocido';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        currentRoute: '/expense_detail',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF6F8FA),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 18)),
                  )
                : expense == null
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No se encontró el gasto.'),
                      )
                    : Center(
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
                                color: const Color.fromRGBO(0, 0, 0, 0.07),
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
                                  // Usar el groupName recibido
                                  BreadcrumbItem(groupName != null ? 'Grupo: $groupName' : 'Grupo', route: '/group/${widget.groupId}'),
                                  BreadcrumbItem(expense != null ? expense!.description : 'Gasto'),
                                ],
                                onTap: (i) {
                                  if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                                  if (i == 1) Navigator.pushReplacementNamed(context, '/group/${widget.groupId}');
                                },
                              ),
                              const SizedBox(height: 32),
                              Text(
                                expense!.description,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Text('Monto: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  // Usar la función formatCurrency
                                  Text(formatCurrency(expense!.amount, expense!.currency)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Fecha: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${expense!.date.toLocal()}'.split(' ')[0]),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Categoría: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(expense!.category ?? '-'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text('Participantes:', style: TextStyle(fontWeight: FontWeight.bold)),
                              // Usar _getUserName que ahora usa el mapa
                              ...expense!.participantIds.map((id) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(_getUserName(id)),
                                  )),
                              const SizedBox(height: 16),
                              const Text('Pagadores:', style: TextStyle(fontWeight: FontWeight.bold)),
                              // Usar _getUserName que ahora usa el mapa
                              ...expense!.payers.map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('${_getUserName(p['userId'])}: ${formatCurrency((p['amount'] as num).toDouble(), expense!.currency)}'),
                                  )),
                              const SizedBox(height: 16),
                              if (expense!.attachments != null && expense!.attachments!.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Adjuntos:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...expense!.attachments!.map((a) => Text(a)),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Editar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      // Asegurarse de pasar el mapa de participantes a la pantalla de edición
                                      Navigator.pushNamed(
                                        context,
                                        '/group/${widget.groupId}/expense/${widget.expenseId}/edit',
                                        arguments: {
                                          'expense': expense,
                                          'participantsMap': participantsMap, // Pasar el mapa
                                          'groupId': widget.groupId,
                                          'groupName': groupName, // Pasar también el nombre del grupo
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }
}
