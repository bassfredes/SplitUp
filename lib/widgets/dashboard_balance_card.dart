import 'package:flutter/material.dart';
import '../utils/formatters.dart'; // Asegúrate de que la ruta sea correcta

class DashboardBalanceCard extends StatelessWidget {
  final Future<Map<String, double>> balancesFuture;
  final bool isMobile;

  const DashboardBalanceCard({
    super.key,
    required this.balancesFuture,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0, // Eliminamos la elevación de la Card interna
      color: Colors.transparent, // Hacemos la Card interna transparente
      margin: EdgeInsets.zero, // Eliminamos el margen de la Card interna
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 0, // Se ajustará en los layouts específicos
          horizontal: 0, // Se ajustará en los layouts específicos
        ),
        child: isMobile
            ? _buildMobileLayout(context)
            : _buildDesktopLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 8), // Ajuste de padding
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.black54, size: 20), // Tamaño ajustado
              const SizedBox(width: 8),
              const Text(
                'Summary of your balances',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18), // Tamaño ajustado
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 16), // Ajuste de padding
          child: _buildBalancesDisplay(context),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // TODO: Implement Settle Up functionality
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF179D8B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              elevation: 0,
            ),
            child: const Text('Settle up', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 0, bottom: 8), // Ajuste de padding, igual a _buildGroupsSection
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: Colors.black54, size: 22), // Tamaño ajustado
                    const SizedBox(width: 8),
                    const Text(
                      'Summary of your balances',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20), // Tamaño ajustado
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0), // Ajuste de padding
                child: _buildBalancesDisplay(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20), // Espacio aumentado
        Flexible(
          fit: FlexFit.loose,
          child: ElevatedButton(
            onPressed: () {
              // TODO: Implement Settle Up functionality
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF179D8B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 0,
            ),
            child: const Text('Settle up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildBalancesDisplay(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: balancesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0), // Adjusted padding for loader
            child: Center(
              child: SizedBox(
                height: 30, // Consistent height for loader
                width: 30,  // Consistent width for loader
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Text('Error loading balances.', style: TextStyle(fontSize: 16, color: Colors.red)),
          );
        }
        final balances = snapshot.data ?? {};
        if (balances.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0), // Adjusted padding
            child: Text('No balances yet.', style: TextStyle(fontSize: 18, color: Colors.grey)), // Adjusted font size
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: balances.entries.map((entry) {
              final currency = entry.key;
              final value = entry.value;
              final color = value < 0 ? const Color(0xFFD32F2F) : const Color(0xFF388E3C);
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0), // Add some vertical spacing between currency balances
                child: Text(
                  formatCurrency(value, currency), // formatCurrency should handle symbol and formatting
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 22 : 26, // Adjusted responsive font size for multiple lines
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
