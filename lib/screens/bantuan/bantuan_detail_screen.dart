// lib/screens/bantuan/bantuan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../models/bantuan_model.dart';
import '../../services/bantuan_service.dart';

class BantuanDetailScreen extends StatefulWidget {
  final BantuanModel bantuan;
  final Function(String action) onLoginRequired;
  final bool isLoggedIn;

  const BantuanDetailScreen({
    Key? key,
    required this.bantuan,
    required this.onLoginRequired,
    required this.isLoggedIn,
  }) : super(key: key);

  @override
  State<BantuanDetailScreen> createState() => _BantuanDetailScreenState();
}

class _BantuanDetailScreenState extends State<BantuanDetailScreen> {
  final _bantuanService = BantuanService();
  String _posterPhone = '';
  bool _isLoadingPhone = true;
  bool _isActionLoading = false;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.bantuan.postedByUid;

  @override
  void initState() {
    super.initState();
    _loadPosterPhone();
  }

  // ✅ Fetch nombor telefon poster dari Firestore
  Future<void> _loadPosterPhone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.bantuan.postedByUid)
          .get();
      if (doc.exists) {
        setState(() {
          _posterPhone = doc.data()?['num_phone'] ?? '';
        });
      }
    } catch (e) {
      // guna whatsapp field kalau ada
      setState(() {
        _posterPhone = widget.bantuan.whatsapp ?? '';
      });
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  // ✅ Format phone untuk display
  String _formatPhoneDisplay(String phone) {
    if (phone.isEmpty) return 'Tidak tersedia';
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('60') && cleaned.length >= 11) {
      return '0${cleaned.substring(2)}';
    }
    return phone;
  }

  // ✅ Format untuk WhatsApp link
  String _formatWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) cleaned = '6$cleaned';
    if (!cleaned.startsWith('60')) cleaned = '60$cleaned';
    return cleaned;
  }

  Future<void> _openWhatsApp() async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired('menghubungi melalui WhatsApp');
      return;
    }

    final phone = widget.bantuan.whatsapp ?? _posterPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombor WhatsApp tidak tersedia')),
      );
      return;
    }

    final formatted = _formatWhatsApp(phone);
    final message = Uri.encodeComponent(
        'Salam, saya berminat dengan post anda bertajuk "${widget.bantuan.title}" di BantuNow.');
    final url = Uri.parse('https://wa.me/$formatted?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  // ✅ Mark as completed
  Future<void> _markAsCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tandakan Selesai?'),
        content: const Text(
            'Adakah anda pasti bantuan ini telah selesai?\n\nPost akan ditutup dan tidak akan dipaparkan lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Selesai', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    final result = await _bantuanService.closeBantuan(widget.bantuan.id);
    setState(() => _isActionLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Bantuan ditandakan selesai!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  // ✅ Delete post
  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Padam Post?'),
        content: const Text('Adakah anda pasti mahu memadam post ini? Tindakan ini tidak boleh dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Padam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(widget.bantuan.id)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Post berjaya dipadam'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isActionLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memadam: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bantuan = widget.bantuan;
    final isRequest = bantuan.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest ? 'Request Help' : 'Offer Help';

    // Status config
    final isActive = bantuan.status == 'open';
    final statusColor = isActive ? Colors.green : Colors.grey;
    final statusLabel = isActive ? 'Active' : 'Completed';
    final statusIcon = isActive ? Icons.check_circle : Icons.task_alt;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ✅ Full-size image dengan AppBar overlay
          SliverAppBar(
            expandedHeight: bantuan.imageUrl != null ? 280 : 120,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Owner actions dalam appbar
              if (_isOwner)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  onSelected: (val) {
                    if (val == 'complete') _markAsCompleted();
                    if (val == 'delete') _deletePost();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'complete',
                      child: Row(
                        children: [
                          Icon(Icons.task_alt, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Mark as Completed'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Post', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: bantuan.imageUrl != null
                  ? Image.network(
                      bantuan.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),

          // ✅ Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Badges row ─────────────────────────────────────────────
                  Row(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Text(typeLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: typeColor)),
                      ),
                      const SizedBox(width: 8),

                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${BantuanCategories.getCategoryIcon(bantuan.category)} ${BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0]}',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primaryBlue),
                        ),
                      ),
                      const Spacer(),

                      // ✅ Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Title ──────────────────────────────────────────────────
                  Text(
                    bantuan.title,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),

                  const SizedBox(height: 8),

                  // ✅ Timestamp + distance
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        'Posted: ${_timeAgo(bantuan.createdAt)}',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textGrey),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        bantuan.area,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Description ────────────────────────────────────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle('Penerangan / Description',
                            Icons.description_outlined),
                        const SizedBox(height: 10),
                        Text(
                          bantuan.description,
                          style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textDark,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── User Info ──────────────────────────────────────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle('Maklumat Pengguna / User Info',
                            Icons.person_outline),
                        const SizedBox(height: 14),

                        // Avatar + Name
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.backgroundBlue,
                              child: Text(
                                bantuan.postedBy.isNotEmpty
                                    ? bantuan.postedBy[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bantuan.postedBy,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark)),
                                Text(bantuan.area,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textGrey)),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // ✅ Phone number
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.phone,
                                  size: 18, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nombor Telefon',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey)),
                                _isLoadingPhone
                                    ? const SizedBox(
                                        width: 80,
                                        height: 16,
                                        child: LinearProgressIndicator())
                                    : Text(
                                        widget.isLoggedIn
                                            ? _formatPhoneDisplay(_posterPhone)
                                            : '••••••••••',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: widget.isLoggedIn
                                                ? AppColors.textDark
                                                : AppColors.textGrey),
                                      ),
                              ],
                            ),
                            if (!widget.isLoggedIn) ...[
                              const Spacer(),
                              TextButton(
                                onPressed: () => widget
                                    .onLoginRequired('melihat nombor telefon'),
                                child: Text('Login untuk lihat',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primaryBlue)),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ✅ Location
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.location_on,
                                  size: 18, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kawasan / Location',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey)),
                                Text(bantuan.area,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark)),
                              ],
                            ),
                            const Spacer(),
                            // ✅ Distance badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.near_me,
                                      size: 12, color: AppColors.primaryBlue),
                                  const SizedBox(width: 4),
                                  Text('Dalam kawasan KT',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primaryBlue)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Action Buttons ─────────────────────────────────────────

                  // ✅ WhatsApp button (semua user)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading ? null : _openWhatsApp,
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text(
                        'Contact via WhatsApp',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  // ✅ Owner buttons
                  if (_isOwner && bantuan.status == 'open') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Mark as Completed
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isActionLoading ? null : _markAsCompleted,
                            icon: const Icon(Icons.task_alt,
                                color: Colors.green, size: 18),
                            label: const Text('Mark Completed',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Delete
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isActionLoading ? null : _deletePost,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            label: const Text('Delete Post',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_isActionLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey)),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.backgroundBlue,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined,
                size: 60, color: AppColors.primaryBlue.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('Tiada Gambar',
                style: TextStyle(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}