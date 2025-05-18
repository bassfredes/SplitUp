import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase utilitaria para manejar paginación en Firestore
class PaginationHelper<T> {
  final int pageSize;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  
  PaginationHelper({this.pageSize = 10});
  
  /// Verifica si hay más datos disponibles para cargar
  bool get hasMoreData => _hasMoreData;
  
  /// Reinicia la paginación
  void reset() {
    _lastDocument = null;
    _hasMoreData = true;
  }
  
  /// Obtiene la siguiente página de datos
  Future<List<T>> getNextPage(
    Query baseQuery,
    T Function(DocumentSnapshot doc) converter,
  ) async {
    if (!_hasMoreData) return [];
    
    Query query = baseQuery.limit(pageSize);
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }
    
    final snapshot = await query.get();
    final docs = snapshot.docs;
    
    if (docs.isEmpty || docs.length < pageSize) {
      _hasMoreData = false;
    }
    
    if (docs.isNotEmpty) {
      _lastDocument = docs.last;
    }
    
    return docs.map((doc) => converter(doc)).toList();
  }
}
