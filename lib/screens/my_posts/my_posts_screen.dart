// lib/screens/my_posts/my_posts_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../models/bantuan_model.dart';
import '../../services/bantuan_service.dart';
import '../bantuan/bantuan_detail_screen.dart';
import '../bantuan/post_bantuan_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({Key? key}) : super(key: key);

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final _bantuanService = BantuanService();

  @override
  void initState() {
    super.initState();
    // ✅ Auto-close posts yang stuck in_progress > 7 hari
    _bantuanService.checkAndAutoClose();
  }

  // ─── Status helpers ──────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Active';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Completed';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.circle;
      case 'in_progress':
        return Icons.handshake_outlined;
      default:
        return Icons.task_alt;
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: AppColors.primaryBlue,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('My Posts',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ),
        body: Center(
          child: Text('Sila log masuk untuk melihat post anda',
              style: TextStyle(color: AppColors.textGrey)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('My Posts',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: StreamBuilder<List<BantuanModel>>(
        stream: _bantuanService.getUserBantuan(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Ralat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined,
                      size: 80,
                      color: AppColors.textGrey.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('Tiada post lagi',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(
                    'Tekan butang + untuk post bantuan pertama anda!',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textGrey),
                  ),
                ],
              ),
            );
          }

          // ✅ 3-status counts
          final activePosts =
              posts.where((p) => p.status == 'open').length;
          final inProgressPosts =
              posts.where((p) => p.status == 'in_progress').length;
          final completedPosts =
              posts.where((p) => p.status == 'closed').length;

          return Column(
            children: [
              // ── Stats bar ────────────────────────────────────────────────
              Container(
                color: AppColors.primaryBlue,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    _buildStatChip(
                        '${posts.length}', 'Total', Colors.white),
                    const SizedBox(width: 8),
                    _buildStatChip(
                        '$activePosts', 'Active', Colors.green.shade300),
                    const SizedBox(width: 8),
                    _buildStatChip('$inProgressPosts', 'In Progress',
                        Colors.orange.shade300),
                    const SizedBox(width: 8),
                    _buildStatChip('$completedPosts', 'Done',
                        Colors.grey.shade300),
                  ],
                ),
              ),

              // ── Post list ────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) =>
                      _buildPostCard(context, posts[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, BantuanModel post) {
    final statusColor = _statusColor(post.status);
    final statusLabel = _statusLabel(post.status);
    final statusIcon = _statusIcon(post.status);
    final isRequest = post.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest ? 'Request' : 'Offer';
    final isOpen = post.status == 'open';
    final isInProgress = post.status == 'in_progress';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BantuanDetailScreen(
              bantuan: post,
              onLoginRequired: (_) {},
              isLoggedIn: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            // ── Post image ─────────────────────────────────────────────
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  post.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Chips row ─────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(typeLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: typeColor)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${BantuanCategories.getCategoryIcon(post.category)} ${BantuanCategories.getCategoryName(post.category).split(' / ')[0]}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryBlue),
                        ),
                      ),
                      const Spacer(),
                      // ✅ Status chip with dynamic color
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon,
                                size: 8, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(post.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.primaryBlue),
                      const SizedBox(width: 2),
                      Text(post.area,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryBlue)),
                      const Spacer(),
                      Icon(Icons.access_time,
                          size: 12, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(_timeAgo(post.createdAt),
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),

                  // ✅ In-progress helper info sub-row
                  if (isInProgress && post.helperName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.handshake_outlined,
                            size: 13, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'Helper: ${post.helperName}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                        if (post.helperConfirmed) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle,
                              size: 13, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text('Confirmed',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.green)),
                        ],
                      ]),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // ── Action buttons ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit — only when open
                      if (isOpen) ...[
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostBantuanScreen(
                                    existingPost: post),
                              ),
                            );
                          },
                          icon: Icon(Icons.edit_outlined,
                              color: AppColors.primaryBlue, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.backgroundBlue,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Delete
                      IconButton(
                        onPressed: () =>
                            _confirmDelete(context, post),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),

                      // ✅ "Selesai & Rate" — only owner when helper confirmed
                      if (isInProgress && post.helperConfirmed) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BantuanDetailScreen(
                                  bantuan: post,
                                  onLoginRequired: (_) {},
                                  isLoggedIn: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.task_alt,
                              color: Colors.green, size: 16),
                          label: const Text('Rate & Close',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 12)),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                Colors.green.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, BantuanModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Padam Post?'),
        content: const Text('Tindakan ini tidak boleh dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Padam',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(post.id)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🗑️ Post berjaya dipadam'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memadam: $e')),
        );
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }
}