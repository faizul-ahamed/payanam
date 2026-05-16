import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import 'package:intl/intl.dart';

class NotificationsPane extends StatefulWidget {
  const NotificationsPane({super.key});

  @override
  State<NotificationsPane> createState() => _NotificationsPaneState();
}

class _NotificationsPaneState extends State<NotificationsPane> {
  final _authService = AuthService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  String _selectedType = 'info';
  String _selectedRouteId = 'all';
  bool _isSending = false;

  final List<Map<String, dynamic>> _types = [
    {'value': 'info', 'label': 'General Info', 'icon': Icons.info_outline, 'color': AppColors.primaryBlue},
    {'value': 'alert', 'label': 'Delay Alert', 'icon': Icons.timer_outlined, 'color': Colors.orange},
    {'value': 'emergency', 'label': 'Emergency', 'icon': Icons.emergency_outlined, 'color': AppColors.error},
    {'value': 'holiday', 'label': 'Holiday Notice', 'icon': Icons.event_available_outlined, 'color': AppColors.success},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await _authService.sendNotification(
        routeId: _selectedRouteId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        type: _selectedType,
      );
      
      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification Sent Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildNewNotificationForm(),
          const SizedBox(height: 48),
          _buildNotificationHistoryHeader(),
          const SizedBox(height: 16),
          _buildNotificationHistoryList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification System',
          style: AppTextStyles.heading1(context).copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          'Broadcast messages to students and drivers globally or per route.',
          style: AppTextStyles.bodyMedium(context).copyWith(color: AppColors.textMutedDark),
        ),
      ],
    );
  }

  Widget _buildNewNotificationForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_alert_rounded, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 12),
              Text(
                'New Announcement',
                style: AppTextStyles.heading1(context).copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Type & Target (Stack vertically on mobile to prevent overflow)
          _buildTypeDropdown(),
          const SizedBox(height: 20),
          _buildTargetDropdown(),
          const SizedBox(height: 20),
          
          // Title Field
          _buildTextField(
            controller: _titleController,
            label: 'Title',
            hint: 'e.g. Bus Delay Alert',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 20),
          
          // Body Field
          _buildTextField(
            controller: _bodyController,
            label: 'Message Content',
            hint: 'Write your message here...',
            icon: Icons.chat_bubble_outline_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 32),
          
          // Send Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Broadcast Notification', style: AppTextStyles.buttonText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedType,
          items: _types.map((t) => DropdownMenuItem(
            value: t['value'] as String,
            child: Row(
              children: [
                Icon(t['icon'] as IconData, size: 18, color: t['color'] as Color),
                const SizedBox(width: 10),
                Text(t['label'] as String, style: const TextStyle(fontSize: 14)),
              ],
            ),
          )).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
          decoration: _dropdownDecoration(),
          dropdownColor: AppColors.getSurfaceCardColor(context),
        ),
      ],
    );
  }

  Widget _buildTargetDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Audience',
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _authService.getRoutesStream(),
          builder: (context, snapshot) {
            final routes = snapshot.data ?? [];
            return DropdownButtonFormField<String>(
              initialValue: _selectedRouteId,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded, size: 18, color: AppColors.primaryPurple),
                      const SizedBox(width: 10),
                      const Text('All Users', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                ...routes.map((r) {
                  // For these routes, the 'name' field already contains the full string 
                  // like "Route 9 - MOHANUR" which matches the student's routeId.
                  final String targetId = (r['name'] != null && r['name'].toString().isNotEmpty)
                      ? r['name'].toString()
                      : (r['routeId'] ?? r['id']);
                  return DropdownMenuItem(
                    value: targetId,
                    child: Row(
                      children: [
                        const Icon(Icons.alt_route_rounded, size: 18, color: AppColors.primaryPurple),
                        const SizedBox(width: 10),
                        Text(r['routeId'] ?? 'Route', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _selectedRouteId = v!),
              decoration: _dropdownDecoration(),
              dropdownColor: AppColors.getSurfaceCardColor(context),
            );
          }
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.getBackgroundColor(context).withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: AppColors.textMutedDark, size: 20),
            filled: true,
            fillColor: AppColors.getBackgroundColor(context).withValues(alpha: 0.5),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationHistoryHeader() {
    return Row(
      children: [
        Text(
          'Broadcast History',
          style: AppTextStyles.heading1(context).copyWith(fontSize: 20),
        ),
        const Spacer(),
        const Icon(Icons.history_rounded, color: AppColors.textMutedDark, size: 20),
      ],
    );
  }

  Widget _buildNotificationHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(color: AppColors.primaryPurple),
          ));
        }

        final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
        
        // Sort locally by timestamp descending to avoid index dependency
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return -1; // Newest first (null timestamp from serverTimestamp usually means just added)
          if (bTime == null) return 1;
          return bTime.compareTo(aTime);
        });
        
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications sent yet.',
                    style: TextStyle(color: AppColors.textMutedDark),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildNotificationCard(id, data);
          },
        );
      }
    );
  }

  Widget _buildNotificationCard(String id, Map<String, dynamic> data) {
    final type = data['type'] ?? 'info';
    final typeConfig = _types.firstWhere((t) => t['value'] == type, orElse: () => _types[0]);
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd MMM, hh:mm a').format(timestamp.toDate())
        : 'Recently';
    
    final routeId = data['routeId'] ?? 'all';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (typeConfig['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(typeConfig['icon'] as IconData, color: typeConfig['color'] as Color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['title'] ?? 'No Title',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 11),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              data['body'] ?? 'No Content',
              style: TextStyle(color: AppColors.getTextPrimary(context).withValues(alpha: 0.8), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    routeId == 'all' ? 'GLOBAL' : routeId.toUpperCase(),
                    style: const TextStyle(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
          onPressed: () => _authService.deleteNotification(id),
          tooltip: 'Delete Notification',
        ),
      ),
    );
  }
}
