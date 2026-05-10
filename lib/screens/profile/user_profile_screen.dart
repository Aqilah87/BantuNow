// lib/screens/profile/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../services/rating_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userUid;
  final String userName;

  const UserProfileScreen({
    Key? key,
    required this.userUid,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _ratingService = RatingService();

  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _userData = doc.data());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  // ── Star display ─────────────────────────────────────────────────────
  Widget _buildStars(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (rating >= i + 1) {
          return Icon(Icons.star_rounded, color: Colors.amber, size: size);
        } else if (rating >= i + 0.5) {
          return Icon(Icons.star_half_rounded, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_outline_rounded,
              color: Colors.amber.withOpacity(0.4), size: size);
        }
      }),
    );
  }

  // ── Rating bar (distribution) ─────────────────────────────────────
  Widget _buildRatingBar(int star, int count, int total) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$star', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(width: 4),
        Icon(Icons.star_rounded, size: 12, color: Colors.amber),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                star >= 4
                    ? Colors.green
                    : star == 3
                        ? Colors.amber
                        : Colors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text('$count',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }

  // ── Single review card ────────────────────────────────────────────
  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num).toDouble();
    final comment = review['comment'] as String? ?? '';
    final type = review['type'] as String? ?? '';
    final ts = review['created_at'] as Timestamp?;
    final date = ts != null
        ? _formatDate(ts.toDate())
        : '';

    // Fetch reviewer name
    final reviewerUid = review['rated_by_uid'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Avatar
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(reviewerUid)
                  .get(),
              builder: (ctx, snap) {
                final name = snap.hasData && snap.data!.exists
                    ? (snap.data!.data() as Map<String, dynamic>)['name'] ??
                        'User'
                    : 'User';
                return Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      _buildStars(rating, size: 14),
                    ],
                  ),
                ]);
              },
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Badge jenis rating
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: type == 'helper'
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type == 'helper' ? '🤲 Helper' : '🙋 Pemohon',
                    style: TextStyle(
                        fontSize: 10,
                        color: type == 'helper' ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(date,
                      style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                ],
              ],
            ),
          ]),

          // Komen
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote,
                      size: 14, color: AppColors.textGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      comment,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ogs', 'Sep', 'Okt', 'Nov', 'Dis'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = _userData?['name'] ?? widget.userName;
    final area = _userData?['area_name'] ?? '';
    final avgRating = (_userData?['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (_userData?['rating_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [

          // ── AppBar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryBlue.withOpacity(0.7),
                    ],
                  ),
                ),
                child: _isLoadingUser
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar besar
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          if (area.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 13, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(area,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Rating summary card ────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ratingCount == 0
                        ? Column(children: [
                            Icon(Icons.star_outline_rounded,
                                size: 40,
                                color: Colors.amber.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text('Belum ada rating',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.textGrey)),
                          ])
                        : Row(
                            children: [
                              // Kiri — angka besar
                              Column(children: [
                                Text(
                                  avgRating.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                      height: 1),
                                ),
                                const SizedBox(height: 6),
                                _buildStars(avgRating, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  '$ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey),
                                ),
                              ]),

                              const SizedBox(width: 20),
                              const VerticalDivider(width: 1),
                              const SizedBox(width: 20),

                              // Kanan — distribution bar
                              Expanded(
                                child: StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: _ratingService
                                      .getUserRatings(widget.userUid),
                                  builder: (ctx, snap) {
                                    if (!snap.hasData) return const SizedBox();
                                    final reviews = snap.data!;
                                    // Kira distribution
                                    final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
                                    for (final r in reviews) {
                                      final s =
                                          (r['rating'] as num).toInt();
                                      dist[s] = (dist[s] ?? 0) + 1;
                                    }
                                    return Column(
                                      children: [5, 4, 3, 2, 1]
                                          .map((s) => _buildRatingBar(
                                              s,
                                              dist[s] ?? 0,
                                              reviews.length))
                                          .toList(),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // ── Reviews section ────────────────────────────────
                  Row(children: [
                    Icon(Icons.reviews_outlined,
                        size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      'Ulasan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _ratingService.getUserRatings(widget.userUid),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (!snap.hasData || snap.data!.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 40,
                                color: AppColors.textGrey.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada ulasan',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textGrey),
                            ),
                          ]),
                        );
                      }

                      final reviews = snap.data!;
                      return Column(
                        children: reviews
                            .map((r) => _buildReviewCard(r))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}