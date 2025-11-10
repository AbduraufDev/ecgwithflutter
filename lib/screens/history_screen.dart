import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Tarix'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
              Color(0xFF4C1D95),
              Color(0xFF6B21A8),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<HRVMeasurement>>(
            future: _measurements,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'O\'lchash ma\'lumotlari yo\'q',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Birinchi o\'lchashni boshlang',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final measurements = snapshot.data!;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 16),

                    // Period selector
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
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

                    SizedBox(height: 24),

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
                                    Expanded(
                                      child: _StatCard(
                                        title: 'O\'rt. Yurak',
                                        value:
                                            '${stats['avgHeartRate']!.toStringAsFixed(0)}',
                                        unit: 'BPM',
                                        icon: Icons.favorite,
                                        gradient: [
                                          Color(0xFFEF4444),
                                          Color(0xFFDC2626)
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        title: 'O\'rt. HRV',
                                        value:
                                            '${stats['avgSDNN']!.toStringAsFixed(0)}',
                                        unit: 'ms',
                                        icon: Icons.timeline,
                                        gradient: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF2563EB)
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        title: 'Recovery',
                                        value:
                                            '${stats['avgRMSSD']!.toStringAsFixed(0)}',
                                        unit: 'ms',
                                        icon: Icons.battery_charging_full,
                                        gradient: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669)
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        title: 'O\'rt. Stress',
                                        value:
                                            '${stats['avgStressIndex']!.toStringAsFixed(1)}',
                                        unit: '/10',
                                        icon: Icons.psychology,
                                        gradient: [
                                          Color(0xFFF59E0B),
                                          Color(0xFFD97706)
                                        ],
                                      ),
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

                    SizedBox(height: 24),

                    // Chart - Heart rate trend
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yurak Urishi Trendu',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
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
                          Text(
                            'Stress Indeksi Trendu',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            padding: EdgeInsets.all(16),
                            child:
                                _StressIndexChart(measurements: measurements),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Measurements list
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Barcha O\'lchashlar',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: measurements.length,
                      itemBuilder: (context, index) {
                        final m = measurements[index];
                        return _MeasurementCard(measurement: m);
                      },
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
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
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final List<Color> gradient;

  _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      return Center(
        child: Text(
          'Ma\'lumot yo\'q',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    final spots = List.generate(
      measurements.length,
      (i) => FlSpot(i.toDouble(), measurements[i].heartRate.toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFFEC4899),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Color(0xFFEC4899),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFEC4899).withOpacity(0.3),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
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
      return Center(
        child: Text(
          'Ma\'lumot yo\'q',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    final spots = List.generate(
      measurements.length,
      (i) => FlSpot(i.toDouble(), measurements[i].stressIndex.toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFFF59E0B),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Color(0xFFF59E0B),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF59E0B).withOpacity(0.3),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
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
    final formattedTime =
        DateFormat('HH:mm, d MMM').format(measurement.timestamp);

    List<Color> stressGradient;
    if (measurement.stressIndex > 6) {
      stressGradient = [Color(0xFFEF4444), Color(0xFFDC2626)];
    } else if (measurement.stressIndex > 4) {
      stressGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
    } else {
      stressGradient = [Color(0xFF10B981), Color(0xFF059669)];
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedTime,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: stressGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Stress: ${measurement.stressIndex}/10',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricColumn(
                label: 'Yurak',
                value: '${measurement.heartRate}',
                unit: 'BPM',
              ),
              _MetricColumn(
                label: 'HRV',
                value: '${measurement.sdnn.toStringAsFixed(0)}',
                unit: 'ms',
              ),
              _MetricColumn(
                label: 'RMSSD',
                value: '${measurement.rmssd.toStringAsFixed(0)}',
                unit: 'ms',
              ),
            ],
          ),
          if (measurement.notes.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'Izoh: ${measurement.notes}',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  _MetricColumn({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
        SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 2),
            Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
