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
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 18 : 28,
          horizontal: isMobile ? 8 : 28,
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
        const Text('Summary of your balances', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        _buildBalancesDisplay(context),
        const SizedBox(height: 16),
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Summary of your balances', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
              _buildBalancesDisplay(context),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
            padding: EdgeInsets.only(top: 8.0),
            child: CircularProgressIndicator(),
          );
        }
        final balances = snapshot.data ?? {};
        if (balances.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('No balances', style: TextStyle(fontSize: 22, color: Colors.grey)),
          );
        }
        // TODO: Consider how to display multiple currencies if that's a possibility.
        // For now, just displaying the first one.
        final value = balances.values.first;
        final currency = balances.keys.first;
        final color = value < 0 ? const Color(0xFFE14B4B) : const Color(0xFF1BC47D);
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            formatCurrency(value, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 36,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
