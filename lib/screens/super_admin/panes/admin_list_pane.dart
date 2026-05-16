import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class AdminListPane extends StatefulWidget {
  const AdminListPane({super.key});

  @override
  State<AdminListPane> createState() => _AdminListPaneState();
}

class _AdminListPaneState extends State<AdminListPane> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateStatus(String docId, String status, {String? email, String? name}) async {
    try {
      await _firestore.collection('admins').doc(docId).set({
        'status': status,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').where('role', isEqualTo: 'admin').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
              }

              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No admins registered', style: TextStyle(color: AppColors.textMutedDark)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final userData = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  final userEmail = userData['email']?.toString() ?? '';
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('admins').doc(id).get(),
                    builder: (context, adminSnapshot) {
                      final adminData = adminSnapshot.data?.data() as Map<String, dynamic>?;
                      final status = (adminData?['status'] ?? 'pending').toString().toLowerCase();
                      final name = adminData?['name'] ?? userEmail.split('@')[0];
                      final phone = adminData?['phone'] ?? 'No Phone';

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
                            CircleAvatar(
                              backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppColors.primaryPurple),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(userEmail, style: const TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
                                  Text(phone, style: const TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildStatusBadge(status),
                                const SizedBox(height: 8),
                                if (status == 'pending')
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: AppColors.success),
                                        onPressed: () => _updateStatus(id, 'approved', email: userEmail, name: name),
                                        tooltip: 'Approve',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel, color: AppColors.error),
                                        onPressed: () => _updateStatus(id, 'rejected', email: userEmail, name: name),
                                        tooltip: 'Reject',
                                      ),
                                    ],
                                  ),
                                if (status == 'approved')
                                   TextButton(
                                    onPressed: () => _updateStatus(id, 'rejected'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.error, textStyle: const TextStyle(fontSize: 12)),
                                    child: const Text('Revoke'),
                                  ),
                                if (status == 'rejected')
                                   TextButton(
                                    onPressed: () => _updateStatus(id, 'approved'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.success, textStyle: const TextStyle(fontSize: 12)),
                                    child: const Text('Re-approve'),
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Accounts', style: AppTextStyles.heading1(context).copyWith(fontSize: 22)),
          Text('Approve or reject sub-admin access requests', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppColors.warning;
    if (status == 'approved') color = AppColors.success;
    if (status == 'rejected') color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
