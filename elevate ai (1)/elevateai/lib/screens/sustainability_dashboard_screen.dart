import 'package:flutter/material.dart';
import '../flutter_integration.dart';
import 'package:fl_chart/fl_chart.dart';

class SustainabilityDashboardScreen extends StatefulWidget {
  const SustainabilityDashboardScreen({super.key});

  @override
  State<SustainabilityDashboardScreen> createState() => _SustainabilityDashboardScreenState();
}

class _SustainabilityDashboardScreenState extends State<SustainabilityDashboardScreen> {
  final _cafeteriaService = CafeteriaService();
  bool _isLoading = true;
  Map<String, dynamic>? _impactData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await _cafeteriaService.getSustainabilityImpact(user.id);
        setState(() {
          _impactData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Sustainability', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPersonalImpactCard(),
                    const SizedBox(height: 24),
                    _buildCampusImpactSection(),
                    const SizedBox(height: 32),
                    _buildWeeklyTrendChart(),
                    const SizedBox(height: 32),
                    _buildEcoTips(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPersonalImpactCard() {
    final personal = _impactData?['personal_impact'] ?? {};
    final meals = personal['meals_saved'] ?? 0;
    final food = personal['food_saved_kg'] ?? 0.0;
    final co2 = personal['co2_saved_kg'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.eco, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('MY ECO IMPACT', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _impactMetric('$meals', 'Meals Saved', Icons.restaurant),
              _impactMetric('${food}kg', 'Food Saved', Icons.shopping_basket),
              _impactMetric('${co2}kg', 'CO2 Reduced', Icons.cloud_done),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'Contribution Score: ${personal['contribution_score']}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (personal['contribution_score'] ?? 0) / 100,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _impactMetric(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildCampusImpactSection() {
    final campus = _impactData?['campus_impact'] ?? {};
    final totalFood = campus['total_food_saved_kg'] ?? 0.0;
    final rate = campus['participation_rate'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Campus Impact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _infoCard('Total Saved', '${totalFood}kg', Icons.public, Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _infoCard('Participation', '$rate%', Icons.people, Colors.orange),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    final trends = _impactData?['weekly_trends'] as List? ?? [];
    if (trends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Waste Reduction Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 20,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < trends.length) {
                        final date = DateTime.parse(trends[value.toInt()]['meal_date']);
                        return Text('${date.day}/${date.month}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: trends.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: (e.value['waste_saved'] as num).toDouble(),
                      color: Colors.green.shade400,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEcoTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Eco Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _tipItem('Plan your week', 'Opt-out of weekend meals if you are going home to save up to 2kg of food waste.'),
        _tipItem('Carry your own bottle', 'Reduced plastic usage contributes significantly to your campus score.'),
      ],
    );
  }

  Widget _tipItem(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
