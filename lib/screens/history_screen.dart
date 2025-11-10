import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/hrv_database.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HRVMeasurement>> _measurements;
  int _selectedPeriod = 7; // 7, 30, or 0 (all)

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  void _loadMeasurements() {
    setState(() {
      if (_selectedPeriod == 7) {
        _measurements = HRVDatabase().getLast7DaysMeasurements();
      } else if (_selectedPeriod == 30) {
        _measurements = HRVDatabase().getLast30DaysMeasurements();
      } else {
        _measurements = HRVDatabase().getAllMeasurements();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('O\'lchash Tarixи'),
        backgroundColor: Color(0xFF2C3E50),
      ),
      body: FutureBuilder<List<HRVMeasurement>>(
        future: _measurements,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('O\'lchash ma\'lumotlari yo\'q'),
            );
          }

          final measurements = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Period selector
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PeriodButton(
                        label: '7 kun',
                        isSelected: _selectedPeriod == 7,
                        onTap: () {
                          setState(() => _selectedPeriod = 7);
                          _loadMeasurements();
                        },
                      ),
                      _PeriodButton(
                        label: '30 kun',
                        isSelected: _selectedPeriod == 30,
                        onTap: () {
                          setState(() => _selectedPeriod = 30);
                          _loadMeasurements();
                        },
                      ),
                      _PeriodButton(
                        label: 'Hammasi',
                        isSelected: _selectedPeriod == 0,
                        onTap: () {
                          setState(() => _selectedPeriod = 0);
                          _loadMeasurements();
                        },
                      ),
                    ],
                  ),
                ),

                // Statistics cards
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: FutureBuilder<Map<String, double>>(
                    future: HRVDatabase().getAverageStats(measurements),
                    builder: (context, statsSnapshot) {
                      if (statsSnapshot.hasData) {
                        final stats = statsSnapshot.data!;
                        return Column(
                          children: [
                            Row(
                              children: [
                                _StatCard(
                                  title: 'O\'rt. Qalb',
                                  value: '${stats['avgHeartRate']!.toStringAsFixed(0)} BPM',
                                  icon: Icons.favorite,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                _StatCard(
                                  title: 'O\'rt. SDNN',
                                  value: '${stats['avgSDNN']!.toStringAsFixed(1)} ms',
                                  icon: Icons.trending_up,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(
                                  title: 'O\'rt. RMSSD',
                                  value: '${stats['avgRMSSD']!.toStringAsFixed(1)} ms',
                                  icon: Icons.show_chart,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 12),
                                _StatCard(
                                  title: 'O\'rt. Stress',
                                  value: '${stats['avgStressIndex']!.toStringAsFixed(0)}/10',
                                  icon: Icons.psychology,
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ),

                SizedBox(height: 20),

                // Chart - Heart rate trend
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qalb urishi trendu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 12),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                        ),
                        padding: EdgeInsets.all(16),
                        child: _HeartRateChart(measurements: measurements),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Chart - Stress index trend
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stress indeksi trendu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 12),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                        ),
                        padding: EdgeInsets.all(16),
                        child: _StressIndexChart(measurements: measurements),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Measurements list
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Barcha o\'lchashlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: measurements.length,
                  itemBuilder: (context, index) {
                    final m = measurements[index];
                    return _MeasurementCard(measurement: m);
                  },
                ),

                SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF2C3E50) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _HeartRateChart extends StatelessWidget {
  final List<HRVMeasurement> measurements;

  _HeartRateChart({required this.measurements});

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return Center(child: Text('Ma\'lumot yo\'q'));
    }

    final spots = List.generate(
      measurements.length,
      (i) => FlSpot(i.toDouble(), measurements[i].heartRate.toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: true),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
}

class _StressIndexChart extends StatelessWidget {
  final List<HRVMeasurement> measurements;

  _StressIndexChart({required this.measurements});

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return Center(child: Text('Ma\'lumot yo\'q'));
    }

    final spots = List.generate(
      measurements.length,
      (i) => FlSpot(i.toDouble(), measurements[i].stressIndex.toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: true),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final HRVMeasurement measurement;

  _MeasurementCard({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('HH:mm, MMM d').format(measurement.timestamp);
    
    Color stressColor = measurement.stressIndex > 6
        ? Colors.red
        : measurement.stressIndex > 4
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formattedTime, style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: stressColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Stress: ${measurement.stressIndex}/10',
                    style: TextStyle(color: stressColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qalb urishi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('${measurement.heartRate} BPM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SDNN', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('${measurement.sdnn.toStringAsFixed(1)} ms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RMSSD', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('${measurement.rmssd.toStringAsFixed(1)} ms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
            if (measurement.notes.isNotEmpty) ...[
              SizedBox(height: 12),
              Text('Izoh: ${measurement.notes}', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
