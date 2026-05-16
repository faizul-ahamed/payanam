import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class StudentNotificationsPane extends StatefulWidget {
  final Map<String, dynamic> studentData;
  const StudentNotificationsPane({super.key, required this.studentData});

  @override
  State<StudentNotificationsPane> createState() => _StudentNotificationsPaneState();
}

class _StudentNotificationsPaneState extends State<StudentNotificationsPane> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final Set<String> _readIds = {};
  final Set<String> _shownPopupIds = {}; // Track IDs already shown as system popups in this session
  bool _initialPopupDone = false;

  @override
  void initState() {
    super.initState();
    _loadReadStatus();
    _initNotifications();
  }

  Future<void> _loadReadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'readNotificationIds_${widget.studentData['collegeId'] ?? 'default'}';
    final savedIds = prefs.getStringList(key) ?? [];
    if (mounted) {
      setState(() {
        _readIds.addAll(savedIds);
      });
    }
  }

  Future<void> _saveReadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'readNotificationIds_${widget.studentData['collegeId'] ?? 'default'}';
    await prefs.setStringList(key, _readIds.toList());
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(settings: initSettings);
  }

  void _showPhoneNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'student_alerts',
      'Student Alert Notifications',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );

    // Also vibrate
    bool vibrationEnabled = widget.studentData['vibrationEnabled'] ?? true;
    if (vibrationEnabled && await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }
  }

  void _markAllAsRead(List<QueryDocumentSnapshot> docs) {
    setState(() {
      for (var doc in docs) {
        _readIds.add(doc.id);
      }
    });
    _saveReadStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: AppTextStyles.heading1(context).copyWith(fontSize: 24),
              ),
              // Mark all as read button — will be connected below
              _buildMarkAllReadButton(context),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('routeId', whereIn: ['all', widget.studentData['routeId'] ?? 'none'])
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
                          'Could not load notifications.\n${snapshot.error}',
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

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text("No notifications yet", style: TextStyle(color: AppColors.textMutedDark)),
                      const SizedBox(height: 8),
                      Text(
                        "Alerts will appear here when the bus is active",
                        style: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              // Sort locally by timestamp descending
              final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              // Show the latest notification as a phone popup (once per session on start, or when a new one arrives)
              if (docs.isNotEmpty) {
                final latest = docs.first;
                final latestData = latest.data() as Map<String, dynamic>;
                final String latestId = latest.id;
                final bool isRead = _readIds.contains(latestId);

                // Only show popup if it's NOT read
                if (!isRead) {
                    bool shouldShow = false;
                    
                    if (!_initialPopupDone) {
                        // First load of the app: show the most recent unread one
                        _initialPopupDone = true;
                        shouldShow = true;
                    } else {
                        // After first load: only show if it's a NEW notification that just arrived
                        // We check if the timestamp is very recent (last 30 seconds)
                        final Timestamp? ts = latestData['timestamp'] as Timestamp?;
                        if (ts != null) {
                            final diff = DateTime.now().difference(ts.toDate()).inSeconds;
                            if (diff.abs() < 30) {
                                shouldShow = true;
                            }
                        }
                    }

                    if (shouldShow && !_shownPopupIds.contains(latestId)) {
                        _shownPopupIds.add(latestId);
                        final title = latestData['title'] ?? 'Notification';
                        final body = latestData['body'] ?? '';
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           _showPhoneNotification(title, body);
                        });
                    }
                } else if (!_initialPopupDone) {
                    // Even if latest is read, we mark initial as done so we don't keep searching
                    _initialPopupDone = true;
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isRead = _readIds.contains(doc.id);
                  return _buildNotificationItem(context, data, isRead, doc.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarkAllReadButton(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('routeId', whereIn: ['all', widget.studentData['routeId'] ?? 'none'])
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final hasUnread = docs.any((doc) => !_readIds.contains(doc.id));
        
        return TextButton.icon(
          onPressed: hasUnread ? () => _markAllAsRead(docs) : null,
          icon: Icon(
            Icons.done_all_rounded,
            size: 16,
            color: hasUnread ? AppColors.primaryPurple : AppColors.textMutedDark,
          ),
          label: Text(
            'Mark all read',
            style: TextStyle(
              color: hasUnread ? AppColors.primaryPurple : AppColors.textMutedDark,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, Map<String, dynamic> data, bool isRead, String docId) {
    final String title = data['title'] ?? 'Notification';
    final String body = data['body'] ?? '';
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    final String time = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : 'Recently';
    final String type = data['type'] ?? 'info';

    IconData icon;
    Color color;

    switch (type) {
      case 'alert':
        icon = Icons.warning_amber_rounded;
        color = AppColors.warning;
        break;
      case 'emergency':
        icon = Icons.error_outline_rounded;
        color = AppColors.error;
        break;
      case 'trip':
        icon = Icons.play_circle_outline;
        color = AppColors.primaryPurple;
        break;
      case 'stop':
        icon = Icons.location_on_outlined;
        color = AppColors.primaryBlue;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        color = AppColors.primaryPurple;
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          setState(() => _readIds.add(docId));
          _saveReadStatus();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.getSurfaceCardColor(context)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead
                ? AppColors.getBorderColor(context).withValues(alpha: 0.3)
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 15,
                            color: isRead ? AppColors.textMutedDark : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            time,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: isRead
                          ? AppColors.textMutedDark.withValues(alpha: 0.6)
                          : AppColors.getTextSecondary(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
