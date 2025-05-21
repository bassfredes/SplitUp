import 'package:flutter/material.dart';
import '../services/firestore_monitor.dart';
import 'package:flutter/scheduler.dart'; // Importar SchedulerBinding

/// Widget para mostrar el uso de Firestore en modo desarrollo
/// Útil para diagnosticar problemas de exceso de lecturas
class FirestoreUsageWidget extends StatefulWidget {
  final Widget child;
  final bool showInProduction;
  
  const FirestoreUsageWidget({
    super.key,
    required this.child,
    this.showInProduction = false,
  });

  @override
  State<FirestoreUsageWidget> createState() => _FirestoreUsageWidgetState();
}

class _FirestoreUsageWidgetState extends State<FirestoreUsageWidget> {
  final FirestoreMonitor _monitor = FirestoreMonitor();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _monitor.addListener(_onMonitorUpdate);
  }

  @override
  void dispose() {
    _monitor.removeListener(_onMonitorUpdate);
    super.dispose();
  }

  void _onMonitorUpdate() {
    if (mounted) {
      // Usar addPostFrameCallback para evitar llamar a setState durante el build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Comprobar de nuevo por si el widget se desmontó mientras tanto
          setState(() {});
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // En producción, solo mostrar el child a menos que se fuerce
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (isProduction && !widget.showInProduction) {
      return widget.child;
    }
    
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).viewPadding.top + 4,
          right: 4,
          child: _buildInfoButton(),
        ),
        if (_isExpanded)
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 50,
            right: 4,
            child: _buildInfoPanel(),
          ),
      ],
    );
  }
  
  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.7 * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              '${_monitor.readCount}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoPanel() {
    final cacheRate = (_monitor.cacheHitRate * 100).toStringAsFixed(1);
    
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.8 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Uso de Firestore',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Divider(color: Colors.white30),
          _infoRow('Lecturas:', '${_monitor.readCount}'),
          _infoRow('Escrituras:', '${_monitor.writeCount}'),
          _infoRow('Aciertos caché:', '${_monitor.cacheHitCount}'),
          _infoRow('Tasa de caché:', '$cacheRate%'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Detalles de uso de Firestore'),
                  content: SingleChildScrollView(
                    child: Text(_monitor.generateReport()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha((0.6 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ver reporte completo',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
