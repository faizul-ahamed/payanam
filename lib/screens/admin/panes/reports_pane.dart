import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import '../../../theme/app_theme.dart';

class ReportsPane extends StatefulWidget {
  const ReportsPane({super.key});
  @override
  State<ReportsPane> createState() => _ReportsPaneState();
}

class _ReportsPaneState extends State<ReportsPane> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  bool _isLoading = true;

  // Data holders
  List<Map<String, dynamic>> _tripHistory = [];
  Map<String, int> _delayFrequency = {};
  Map<String, Map<String, dynamic>> _busUtilization = {};
  Map<String, int> _studentCountPerRoute = {};
  int _totalTrips = 0;
  int _totalDelays = 0;
  int _totalStudents = 0;
  double _avgTripDuration = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadTripHistory(),
        _loadStudentCounts(),
      ]);
      _calculateDelayFrequency();
      _calculateBusUtilization();
      _calculateSummary();
    } catch (e) {
      debugPrint('Error loading report data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTripHistory() async {
    final startTs = Timestamp.fromDate(_dateRange.start);
    final endTs = Timestamp.fromDate(_dateRange.end.add(const Duration(days: 1)));
    
    final snapshot = await FirebaseFirestore.instance
        .collection('trip_history')
        .get();

    _tripHistory = snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).where((data) {
      final startTime = data['startTime'] as Timestamp?;
      if (startTime == null) return false;
      return startTime.compareTo(startTs) >= 0 && startTime.compareTo(endTs) <= 0;
    }).toList();

    _tripHistory.sort((a, b) {
      final aTime = a['endTime'] as Timestamp?;
      final bTime = b['endTime'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  }

  Future<void> _loadStudentCounts() async {
    final snapshot = await FirebaseFirestore.instance.collection('students').get();
    _studentCountPerRoute = {};
    _totalStudents = snapshot.docs.length;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final route = data['routeId']?.toString() ?? 'Unassigned';
      _studentCountPerRoute[route] = (_studentCountPerRoute[route] ?? 0) + 1;
    }
  }

  void _calculateDelayFrequency() {
    _delayFrequency = {};
    for (var trip in _tripHistory) {
      final status = trip['status']?.toString() ?? '';
      final route = trip['routeId']?.toString() ?? 'Unknown';
      if (status == 'delayed' || status == 'breakdown' || status == 'emergency') {
        _delayFrequency[route] = (_delayFrequency[route] ?? 0) + 1;
      }
    }
  }

  void _calculateBusUtilization() {
    _busUtilization = {};
    for (var trip in _tripHistory) {
      final busId = trip['busId']?.toString() ?? trip['driverId']?.toString() ?? 'Unknown';
      if (!_busUtilization.containsKey(busId)) {
        _busUtilization[busId] = {'trips': 0, 'totalMinutes': 0, 'route': trip['routeId'] ?? ''};
      }
      _busUtilization[busId]!['trips'] = (_busUtilization[busId]!['trips'] as int) + 1;
      final start = trip['startTime'] as Timestamp?;
      final end = trip['endTime'] as Timestamp?;
      if (start != null && end != null) {
        final mins = end.toDate().difference(start.toDate()).inMinutes;
        _busUtilization[busId]!['totalMinutes'] = (_busUtilization[busId]!['totalMinutes'] as int) + mins;
      }
    }
  }

  void _calculateSummary() {
    _totalTrips = _tripHistory.length;
    _totalDelays = _tripHistory.where((t) {
      final s = t['status']?.toString() ?? '';
      return s == 'delayed' || s == 'breakdown' || s == 'emergency';
    }).length;
    
    int totalMins = 0;
    int validCount = 0;
    for (var trip in _tripHistory) {
      final s = trip['startTime'] as Timestamp?;
      final e = trip['endTime'] as Timestamp?;
      if (s != null && e != null) {
        totalMins += e.toDate().difference(s.toDate()).inMinutes;
        validCount++;
      }
    }
    _avgTripDuration = validCount > 0 ? totalMins / validCount : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildDateFilter(),
        _buildSummaryRow(),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryPurple,
          unselectedLabelColor: AppColors.textMutedDark,
          indicatorColor: AppColors.primaryPurple,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Trip History'),
            Tab(text: 'Delay Analysis'),
            Tab(text: 'Bus Utilization'),
            Tab(text: 'Student Distribution'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTripHistoryTab(),
                    _buildDelayAnalysisTab(),
                    _buildBusUtilizationTab(),
                    _buildStudentDistributionTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reports & Analytics', style: AppTextStyles.heading1(context).copyWith(fontSize: 20)),
                Text('Real-time Firebase data insights', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
              ],
            ),
          ),
          _buildExportMenu(),
        ],
      ),
    );
  }

  Widget _buildExportMenu() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'pdf') _exportPdf();
        if (val == 'excel') _exportExcel();
      },
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.download_rounded, color: AppColors.primaryPurple, size: 20),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 8), Text('Export as PDF')])),
        const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 8), Text('Export as Excel')])),
      ],
    );
  }

  Widget _buildDateFilter() {
    final fmt = DateFormat('dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: AppColors.primaryPurple, size: 18),
              const SizedBox(width: 12),
              Text('${fmt.format(_dateRange.start)}  →  ${fmt.format(_dateRange.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('Change', style: TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _miniCard('Total Trips', '$_totalTrips', Icons.alt_route_rounded, AppColors.primaryBlue),
          _miniCard('Delays', '$_totalDelays', Icons.warning_amber_rounded, AppColors.warning),
          _miniCard('Avg Duration', '${_avgTripDuration.toStringAsFixed(0)} min', Icons.timer_outlined, AppColors.success),
          _miniCard('Students', '$_totalStudents', Icons.school_rounded, AppColors.primaryPurple),
        ],
      ),
    );
  }

  Widget _miniCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(color: AppColors.textMutedDark, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: Trip History ───
  Widget _buildTripHistoryTab() {
    if (_tripHistory.isEmpty) return _emptyState('No trips found in this date range');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tripHistory.length,
      itemBuilder: (context, i) {
        final t = _tripHistory[i];
        final start = t['startTime'] as Timestamp?;
        final end = t['endTime'] as Timestamp?;
        final route = t['routeId'] ?? 'Unknown';
        final bus = t['busId'] ?? t['driverId'] ?? '??';
        final session = t['session'] ?? t['currentSession'] ?? '';
        final status = t['status']?.toString() ?? 'completed';
        final duration = _fmtDuration(start, end);

        Color statusColor = AppColors.success;
        if (status == 'delayed') statusColor = AppColors.warning;
        if (status == 'breakdown' || status == 'emergency') statusColor = AppColors.error;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  session.toString().toLowerCase() == 'evening' ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                  color: statusColor, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route $route', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Bus: $bus • ${start != null ? DateFormat('dd MMM, hh:mm a').format(start.toDate()) : 'N/A'}',
                        style: TextStyle(color: AppColors.textMutedDark, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text(duration, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TAB 2: Delay Analysis ───
  Widget _buildDelayAnalysisTab() {
    if (_delayFrequency.isEmpty) return _emptyState('No delays recorded in this period');
    final sorted = _delayFrequency.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value.toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delay Frequency by Route', style: AppTextStyles.heading1(context).copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('${_dateRange.start.difference(_dateRange.end).inDays.abs()} day period', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxVal + 2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem('${sorted[group.x.toInt()].key}\n${rod.toY.toInt()} delays',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                    getTitlesWidget: (val, meta) {
                      if (val.toInt() >= sorted.length) return const SizedBox();
                      final label = sorted[val.toInt()].key;
                      return SideTitleWidget(meta: meta, child: Text(label.length > 8 ? '${label.substring(0, 8)}..' : label, style: const TextStyle(fontSize: 9)));
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (val) => FlLine(color: AppColors.getBorderColor(context).withValues(alpha: 0.2), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(sorted.length, (i) => BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: sorted[i].value.toDouble(), width: 20, color: AppColors.warning,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: LinearGradient(colors: [AppColors.warning, AppColors.error], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
                ])),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...sorted.map((e) => _delayListTile(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _delayListTile(String route, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Route $route', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$count delays', style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: Bus Utilization ───
  Widget _buildBusUtilizationTab() {
    if (_busUtilization.isEmpty) return _emptyState('No bus usage data available');
    final entries = _busUtilization.entries.toList()..sort((a, b) => (b.value['trips'] as int).compareTo(a.value['trips'] as int));
    final totalTripsAll = entries.fold<int>(0, (total, e) => total + (e.value['trips'] as int));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bus Utilization Rate', style: AppTextStyles.heading1(context).copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Based on completed trips & active time', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(entries.length.clamp(0, 8), (i) {
                  final pct = totalTripsAll > 0 ? (entries[i].value['trips'] as int) / totalTripsAll * 100 : 0.0;
                  return PieChartSectionData(
                    value: pct,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    radius: 50,
                    color: _chartColor(i),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12, runSpacing: 8,
            children: List.generate(entries.length.clamp(0, 8), (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _chartColor(i), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Bus ${entries[i].key}', style: const TextStyle(fontSize: 11)),
              ],
            )),
          ),
          const SizedBox(height: 20),
          ...entries.map((e) {
            final trips = e.value['trips'] as int;
            final mins = e.value['totalMinutes'] as int;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceCardColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.directions_bus, color: AppColors.primaryPurple, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bus ${e.key}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Route: ${e.value['route']}', style: TextStyle(color: AppColors.textMutedDark, fontSize: 11)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$trips trips', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryPurple)),
                    Text('${(mins / 60).toStringAsFixed(1)} hrs', style: TextStyle(color: AppColors.textMutedDark, fontSize: 11)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── TAB 4: Student Distribution ───
  Widget _buildStudentDistributionTab() {
    if (_studentCountPerRoute.isEmpty) return _emptyState('No student data available');
    final sorted = _studentCountPerRoute.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value.toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student Count per Route', style: AppTextStyles.heading1(context).copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('$_totalStudents total students across ${sorted.length} routes', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxVal + 5,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem('${sorted[group.x.toInt()].key}\n${rod.toY.toInt()} students',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                    getTitlesWidget: (val, meta) {
                      if (val.toInt() >= sorted.length) return const SizedBox();
                      final label = sorted[val.toInt()].key;
                      return SideTitleWidget(meta: meta, child: Text(label.length > 8 ? '${label.substring(0, 8)}..' : label, style: const TextStyle(fontSize: 9)));
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5, getDrawingHorizontalLine: (val) => FlLine(color: AppColors.getBorderColor(context).withValues(alpha: 0.2), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(sorted.length, (i) => BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: sorted[i].value.toDouble(), width: 20, color: AppColors.primaryPurple,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.primaryPurple], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
                ])),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...sorted.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, color: AppColors.primaryPurple, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${e.value} students', style: const TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Export: PDF ───
  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();
      final fmt = DateFormat('dd MMM yyyy');

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'Payanam - Reports & Analytics'),
          pw.Text('Date Range: ${fmt.format(_dateRange.start)} to ${fmt.format(_dateRange.end)}'),
          pw.SizedBox(height: 16),
          pw.Text('Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.Text('Total Trips: $_totalTrips | Delays: $_totalDelays | Avg Duration: ${_avgTripDuration.toStringAsFixed(0)} min | Students: $_totalStudents'),
          pw.SizedBox(height: 16),
          pw.Text('Trip History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headers: ['Route', 'Bus', 'Session', 'Start Time', 'Duration', 'Status'],
            data: _tripHistory.take(50).map((t) {
              final s = t['startTime'] as Timestamp?;
              final e = t['endTime'] as Timestamp?;
              return [
                t['routeId'] ?? '',
                t['busId'] ?? t['driverId'] ?? '',
                t['session'] ?? '',
                s != null ? DateFormat('dd/MM HH:mm').format(s.toDate()) : 'N/A',
                _fmtDuration(s, e),
                t['status'] ?? 'completed',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Student Count per Route', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.TableHelper.fromTextArray(
            headers: ['Route', 'Student Count'],
            data: _studentCountPerRoute.entries.map((e) => [e.key, e.value.toString()]).toList(),
          ),
        ],
      ));

      final pdfBytes = await pdf.save();
      final dateStr = DateFormat('dd_MMM_yyyy').format(DateTime.now());
      await Printing.sharePdf(bytes: pdfBytes, filename: 'Payanam_Report_$dateStr.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report exported successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      debugPrint('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Export: Excel ───
  Future<void> _exportExcel() async {
    try {
      final excel = xl.Excel.createExcel();

      // Trip History sheet
      final tripSheet = excel['Trip History'];
      tripSheet.appendRow([
        xl.TextCellValue('Route'), xl.TextCellValue('Bus'), xl.TextCellValue('Session'),
        xl.TextCellValue('Start Time'), xl.TextCellValue('End Time'), xl.TextCellValue('Duration'),
        xl.TextCellValue('Status'),
      ]);
      for (var t in _tripHistory) {
        final s = t['startTime'] as Timestamp?;
        final e = t['endTime'] as Timestamp?;
        tripSheet.appendRow([
          xl.TextCellValue(t['routeId']?.toString() ?? ''),
          xl.TextCellValue(t['busId']?.toString() ?? t['driverId']?.toString() ?? ''),
          xl.TextCellValue(t['session']?.toString() ?? ''),
          xl.TextCellValue(s != null ? DateFormat('dd/MM/yyyy HH:mm').format(s.toDate()) : 'N/A'),
          xl.TextCellValue(e != null ? DateFormat('dd/MM/yyyy HH:mm').format(e.toDate()) : 'N/A'),
          xl.TextCellValue(_fmtDuration(s, e)),
          xl.TextCellValue(t['status']?.toString() ?? 'completed'),
        ]);
      }

      // Student sheet
      final studentSheet = excel['Student Distribution'];
      studentSheet.appendRow([xl.TextCellValue('Route'), xl.TextCellValue('Student Count')]);
      for (var e in _studentCountPerRoute.entries) {
        studentSheet.appendRow([xl.TextCellValue(e.key), xl.IntCellValue(e.value)]);
      }

      excel.delete('Sheet1');
      final bytes = excel.save();
      if (bytes != null) {
        // Save to temp directory and share
        final dateStr = DateFormat('dd_MMM_yyyy').format(DateTime.now());
        final tempDir = await Directory.systemTemp.createTemp('payanam_report');
        final filePath = '${tempDir.path}/Payanam_Report_$dateStr.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        // Use Printing.sharePdf to share (it can share any bytes as a file)
        await Printing.sharePdf(
          bytes: file.readAsBytesSync(),
          filename: 'Payanam_Report_$dateStr.xlsx',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel report exported successfully'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      debugPrint('Excel export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting Excel: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Helpers ───
  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: AppColors.textMutedDark, fontSize: 14)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range, size: 16),
            label: const Text('Try a different date range'),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return '--';
    final d = end.toDate().difference(start.toDate());
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes} min';
  }

  Color _chartColor(int i) {
    const colors = [
      AppColors.primaryPurple, AppColors.primaryBlue, AppColors.success,
      AppColors.warning, AppColors.error, Color(0xFF00BCD4),
      Color(0xFFFF9800), Color(0xFF9C27B0),
    ];
    return colors[i % colors.length];
  }
}
