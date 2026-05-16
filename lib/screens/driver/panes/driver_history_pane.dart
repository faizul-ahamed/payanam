import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class DriverHistoryPane extends StatelessWidget {
  final String driverId;
  const DriverHistoryPane({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    // Only filter by driverId — no orderBy to avoid composite index requirement
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trip_history')
          .where('driverId', isEqualTo: driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load history.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Sort locally by endTime descending (newest first)
        final docs = snapshot.data?.docs ?? [];
        final history = List<QueryDocumentSnapshot>.from(docs);
        history.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['endTime'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['endTime'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending
        });

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No trip history yet', style: TextStyle(color: AppColors.textMutedDark, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Completed trips will appear here',
                  style: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final data = history[index].data() as Map<String, dynamic>;
            final startTime = data['startTime'] as Timestamp?;
            final endTime = data['endTime'] as Timestamp?;
            final route = data['routeId'] ?? 'Unknown Route';
            final session = data['session'] ?? data['currentSession'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      session.toString().toLowerCase() == 'evening'
                          ? Icons.nights_stay_rounded
                          : Icons.wb_sunny_rounded,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route $route',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          startTime != null
                              ? DateFormat('dd MMM yyyy • hh:mm a').format(startTime.toDate())
                              : 'N/A',
                          style: TextStyle(color: AppColors.textMutedDark, fontSize: 12),
                        ),
                        if (session.toString().isNotEmpty)
                          Text(
                            '${session.toString()[0].toUpperCase()}${session.toString().substring(1)} Trip',
                            style: TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'COMPLETED',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(startTime, endTime),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return '--';
    final duration = end.toDate().difference(start.toDate());
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes} min';
  }
}
