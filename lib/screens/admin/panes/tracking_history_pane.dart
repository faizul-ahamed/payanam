import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';

class TrackingHistoryPane extends StatefulWidget {
  const TrackingHistoryPane({super.key});

  @override
  State<TrackingHistoryPane> createState() => _TrackingHistoryPaneState();
}

class _TrackingHistoryPaneState extends State<TrackingHistoryPane> {
  DateTimeRange? _dateRange;
  String? _selectedRoute;
  bool _isLoading = false;
  List<DocumentSnapshot> _history = [];
  List<String> _routes = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
    _fetchHistory();
  }

  Future<void> _fetchRoutes() async {
    final snap = await FirebaseFirestore.instance.collection('routes').get();
    setState(() {
      _routes = snap.docs.map((d) => (d.data() as Map<String, dynamic>)['name']?.toString() ?? d.id).toList();
    });
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    
    Query query = FirebaseFirestore.instance.collection('trip_history');

    // Due to Firestore indexing limitations without complex setup, 
    // we'll filter as much as possible and then filter locally for date ranges if needed.
    // However, we can use orderBy and where on dates if we have the index.
    
    if (_selectedRoute != null) {
      query = query.where('routeId', isEqualTo: _selectedRoute);
    }

    final snap = await query.get();
    
    List<DocumentSnapshot> results = snap.docs;

    // Local filtering for date range
    if (_dateRange != null) {
      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final start = data['startTime'] as Timestamp?;
        if (start == null) return false;
        final date = start.toDate();
        return date.isAfter(_dateRange!.start) && 
               date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Local sorting (newest first)
    results.sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['startTime'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['startTime'] as Timestamp?;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    setState(() {
      _history = results;
      _isLoading = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteRecord(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to permanently delete this trip record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('trip_history').doc(docId).delete();
      _fetchHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted')));
      }
    }
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Deletion'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} selected records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedIds) {
        batch.delete(FirebaseFirestore.instance.collection('trip_history').doc(id));
      }
      await batch.commit();
      _fetchHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedIds.length} records deleted')));
      }
    }
  }

  Future<void> _deleteByDateRange() async {
    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date range first')));
      return;
    }

    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete History by Range'),
          content: Text('Delete all records from ${DateFormat('dd MMM').format(_dateRange!.start)} to ${DateFormat('dd MMM').format(_dateRange!.end)}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete Range'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        // Find records in range and delete
        final snap = await FirebaseFirestore.instance.collection('trip_history').get();
        final toDelete = snap.docs.where((doc) {
          final start = (doc.data())['startTime'] as Timestamp?;
          if (start == null) return false;
          final d = start.toDate();
          return d.isAfter(_dateRange!.start) && d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        });

        final batch = FirebaseFirestore.instance.batch();
        for (var d in toDelete) {
          batch.delete(d.reference);
        }
        await batch.commit();
        _fetchHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History range cleared')));
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
        if (_selectedIds.isNotEmpty) _buildBulkActions(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
            : _history.isEmpty 
              ? _buildEmptyState()
              : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tracking History', style: AppTextStyles.heading1(context).copyWith(fontSize: 22)),
                Text('Review and manage past trip records', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchHistory,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryPurple),
            tooltip: 'Refresh data',
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Route Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRoute,
                  hint: const Text('Filter by Route', style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Routes', style: TextStyle(fontSize: 13))),
                    ..._routes.map((r) => DropdownMenuItem(
                      value: r, 
                      child: Text(
                        r, 
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    )),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedRoute = v);
                    _fetchHistory();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date Filter
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context, 
                  firstDate: DateTime(2024), 
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() => _dateRange = picked);
                  _fetchHistory();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMutedDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dateRange == null 
                          ? 'Select Date' 
                          : '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_dateRange != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _dateRange = null);
                          _fetchHistory();
                        },
                        child: const Icon(Icons.close, size: 14, color: AppColors.error),
                      )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('${_selectedIds.length} items selected', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          TextButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('Delete Selected'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            headingRowHeight: 50,
            dataRowMaxHeight: 60,
            columns: const [
              DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Bus', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Stops', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _history.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final start = data['startTime'] as Timestamp?;
              final end = data['endTime'] as Timestamp?;
              final status = data['status']?.toString().toLowerCase() ?? 'completed';
              final isSelected = _selectedIds.contains(doc.id);

              return DataRow(
                selected: isSelected,
                onSelectChanged: (val) {
                  setState(() {
                    if (val == true) _selectedIds.add(doc.id);
                    else _selectedIds.remove(doc.id);
                  });
                },
                cells: [
                  DataCell(Text((_history.indexOf(doc) + 1).toString(), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(data['busId']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(data['driverId']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('Route ${data['routeId']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  DataCell(Text('${(data['stops'] as List?)?.length ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(start != null ? DateFormat('dd MMM, hh:mm a').format(start.toDate()) : 'N/A', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_formatDuration(start, end), style: const TextStyle(fontSize: 12))),
                  DataCell(_buildStatusBadge(status)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () => _deleteRecord(doc.id),
                        tooltip: 'Delete',
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppColors.success;
    if (status == 'delayed') color = AppColors.warning;
    else if (status == 'breakdown' || status == 'emergency') color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDuration(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return '--';
    final dur = end.toDate().difference(start.toDate());
    if (dur.inHours > 0) return '${dur.inHours}h ${dur.inMinutes % 60}m';
    return '${dur.inMinutes}m';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No tracking history found', style: TextStyle(color: AppColors.textMutedDark, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Try adjusting your filters', style: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }


}
