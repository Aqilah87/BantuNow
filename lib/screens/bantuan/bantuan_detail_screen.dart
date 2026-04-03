// lib/screens/bantuan/bantuan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/bantuan_model.dart';
import '../../services/bantuan_service.dart';
import '../../services/deep_link_service.dart';

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

  Future<void> _loadPosterPhone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.bantuan.postedByUid).get();
      if (doc.exists) {
        setState(() => _posterPhone = doc.data()?['num_phone'] ?? '');
      }
    } catch (e) {
      setState(() => _posterPhone = widget.bantuan.whatsapp ?? '');
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  String _formatPhoneDisplay(String phone) {
    if (phone.isEmpty) return '';
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('60') && cleaned.length >= 11) return '0${cleaned.substring(2)}';
    return phone;
  }

  String _formatWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) cleaned = '6$cleaned';
    if (!cleaned.startsWith('60')) cleaned = '60$cleaned';
    return cleaned;
  }

  Future<void> _openWhatsApp(bool isMalay) async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired(isMalay ? 'menghubungi melalui WhatsApp' : 'contact via WhatsApp');
      return;
    }
    final phone = widget.bantuan.whatsapp ?? _posterPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay ? 'Nombor WhatsApp tidak tersedia' : 'WhatsApp number not available'),
      ));
      return;
    }
    final formatted = _formatWhatsApp(phone);
    final message = Uri.encodeComponent(
        '${isMalay ? 'Salam' : 'Hello'}, ${isMalay ? 'saya berminat dengan post anda bertajuk' : 'I am interested in your post titled'} "${widget.bantuan.title}" ${isMalay ? 'di' : 'on'} BantuNow.');
    final url = Uri.parse('https://wa.me/$formatted?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay ? 'Tidak dapat membuka WhatsApp' : 'Cannot open WhatsApp'),
        ));
      }
    }
  }

  void _sharePost(bool isMalay) {
    final bantuan = widget.bantuan;
    final link = DeepLinkService.generatePostLink(bantuan.id);
    final isRequest = bantuan.type == 'request';
    final typeEmoji = isRequest ? '🙋' : '🤲';
    final typeLabel = isRequest
        ? (isMalay ? 'Minta Bantuan' : 'Request Help')
        : (isMalay ? 'Tawar Bantuan' : 'Offer Help');
    final categoryName = BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0];
    final desc = bantuan.description.length > 100
        ? '${bantuan.description.substring(0, 100)}...'
        : bantuan.description;

    final shareText = isMalay
        ? '$typeEmoji *$typeLabel di BantuNow!*\n\n📌 *${bantuan.title}*\n🏷️ Kategori: $categoryName\n📍 Kawasan: ${bantuan.area}\n\n$desc\n\n🔗 Lihat selengkapnya:\n$link\n\n_Dikongsi melalui BantuNow — Aplikasi Bantuan Komuniti Kuala Terengganu_'
        : '$typeEmoji *$typeLabel on BantuNow!*\n\n📌 *${bantuan.title}*\n🏷️ Category: $categoryName\n📍 Area: ${bantuan.area}\n\n$desc\n\n🔗 View more:\n$link\n\n_Shared via BantuNow — Kuala Terengganu Community Assistance App_';

    Share.share(shareText, subject: bantuan.title);
  }

  void _copyLink(bool isMalay) {
    final link = DeepLinkService.generatePostLink(widget.bantuan.id);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(isMalay ? 'Link berjaya disalin!' : 'Link copied!'),
      ]),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _shareViaWhatsApp() async {
    final link = DeepLinkService.generatePostLink(widget.bantuan.id);
    final bantuan = widget.bantuan;
    final message = Uri.encodeComponent('🙌 *${bantuan.title}*\n📍 ${bantuan.area}\n\n$link');
    final url = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showShareSheet(bool isMalay) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isMalay ? 'Kongsi Post' : 'Share Post',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(isMalay ? 'Kongsikan post ini kepada rakan anda' : 'Share this post with your friends',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(icon: Icons.share, label: isMalay ? 'Kongsi' : 'Share',
                    color: AppColors.primaryBlue, onTap: () { Navigator.pop(ctx); _sharePost(isMalay); }),
                _buildShareOption(icon: Icons.chat, label: 'WhatsApp',
                    color: const Color(0xFF25D366), onTap: () { Navigator.pop(ctx); _shareViaWhatsApp(); }),
                _buildShareOption(icon: Icons.link, label: isMalay ? 'Salin Link' : 'Copy Link',
                    color: Colors.orange, onTap: () { Navigator.pop(ctx); _copyLink(isMalay); }),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.backgroundBlue, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.link, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  DeepLinkService.generatePostLink(widget.bantuan.id),
                  style: TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      ]),
    );
  }

  Future<void> _markAsCompleted(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Tandakan Selesai?' : 'Mark as Completed?'),
        content: Text(isMalay
            ? 'Adakah anda pasti bantuan ini telah selesai?\n\nPost akan ditutup dan tidak akan dipaparkan lagi.'
            : 'Are you sure this help has been completed?\n\nThe post will be closed and no longer displayed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel', style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isMalay ? 'Ya, Selesai' : 'Yes, Done', style: const TextStyle(color: Colors.white)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay ? '✅ Bantuan ditandakan selesai!' : '✅ Help marked as completed!'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    }
  }

  Future<void> _deletePost(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Padam Post?' : 'Delete Post?'),
        content: Text(isMalay
            ? 'Adakah anda pasti mahu memadam post ini? Tindakan ini tidak boleh dibatalkan.'
            : 'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel', style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isMalay ? 'Padam' : 'Delete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isActionLoading = true);
    try {
      await FirebaseFirestore.instance.collection('bantuan').doc(widget.bantuan.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay ? '🗑️ Post berjaya dipadam' : '🗑️ Post deleted successfully'),
        backgroundColor: Colors.red,
      ));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isActionLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isMalay ? 'Gagal memadam' : 'Failed to delete'}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMalay = context.watch<LanguageProvider>().isMalay;
    final bantuan = widget.bantuan;
    final isRequest = bantuan.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest
        ? (isMalay ? 'Minta Bantuan' : 'Request Help')
        : (isMalay ? 'Tawar Bantuan' : 'Offer Help');
    final isActive = bantuan.status == 'open';
    final statusColor = isActive ? Colors.green : Colors.grey;
    final statusLabel = isActive
        ? (isMalay ? 'Aktif' : 'Active')
        : (isMalay ? 'Selesai' : 'Completed');
    final statusIcon = isActive ? Icons.check_circle : Icons.task_alt;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: bantuan.imageUrl != null ? 280 : 120,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
                onPressed: () => _showShareSheet(isMalay),
              ),
              if (_isOwner)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  onSelected: (val) {
                    if (val == 'complete') _markAsCompleted(isMalay);
                    if (val == 'delete') _deletePost(isMalay);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'complete', child: Row(children: [
                      const Icon(Icons.task_alt, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(isMalay ? 'Tandakan Selesai' : 'Mark as Completed'),
                    ])),
                    PopupMenuItem(value: 'delete', child: Row(children: [
                      const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(isMalay ? 'Padam Post' : 'Delete Post',
                          style: const TextStyle(color: Colors.red)),
                    ])),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: bantuan.imageUrl != null
                  ? Image.network(bantuan.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder())
                  : _buildImagePlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: typeColor.withOpacity(0.3)),
                      ),
                      child: Text(typeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeColor)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.backgroundBlue, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${BantuanCategories.getCategoryIcon(bantuan.category)} ${BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0]}',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  Text(bantuan.title,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),

                  const SizedBox(height: 8),

                  Row(children: [
                    Icon(Icons.access_time, size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text('${isMalay ? 'Dipost' : 'Posted'}: ${_timeAgo(bantuan.createdAt, isMalay)}',
                        style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Text(bantuan.area, style: TextStyle(fontSize: 13, color: AppColors.primaryBlue)),
                  ]),

                  const SizedBox(height: 20),

                  // Description
                  _buildCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardTitle(isMalay ? 'Penerangan' : 'Description', Icons.description_outlined),
                      const SizedBox(height: 10),
                      Text(bantuan.description,
                          style: TextStyle(fontSize: 15, color: AppColors.textDark, height: 1.6)),
                    ],
                  )),

                  const SizedBox(height: 16),

                  // User Info
                  _buildCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardTitle(
                          isMalay ? 'Maklumat Pengguna' : 'User Info', Icons.person_outline),
                      const SizedBox(height: 14),
                      Row(children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.backgroundBlue,
                          child: Text(
                            bantuan.postedBy.isNotEmpty ? bantuan.postedBy[0].toUpperCase() : 'U',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(bantuan.postedBy,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          Text(bantuan.area, style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.phone, size: 18, color: Colors.green),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isMalay ? 'Nombor Telefon' : 'Phone Number',
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          _isLoadingPhone
                              ? const SizedBox(width: 80, height: 16, child: LinearProgressIndicator())
                              : Text(
                                  widget.isLoggedIn
                                      ? (_formatPhoneDisplay(_posterPhone).isEmpty
                                          ? (isMalay ? 'Tidak tersedia' : 'Not available')
                                          : _formatPhoneDisplay(_posterPhone))
                                      : '••••••••••',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600,
                                      color: widget.isLoggedIn ? AppColors.textDark : AppColors.textGrey),
                                ),
                        ]),
                        if (!widget.isLoggedIn) ...[
                          const Spacer(),
                          TextButton(
                            onPressed: () => widget.onLoginRequired(
                                isMalay ? 'melihat nombor telefon' : 'view phone number'),
                            child: Text(isMalay ? 'Login untuk lihat' : 'Login to view',
                                style: TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.backgroundBlue, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.location_on, size: 18, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isMalay ? 'Kawasan' : 'Location',
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          Text(bantuan.area,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        ]),
                      ]),
                    ],
                  )),

                  const SizedBox(height: 24),

                  // Share button
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _showShareSheet(isMalay),
                      icon: Icon(Icons.share, color: AppColors.primaryBlue, size: 18),
                      label: Text(isMalay ? 'Kongsi Post' : 'Share Post',
                          style: TextStyle(color: AppColors.primaryBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // WhatsApp button
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading ? null : () => _openWhatsApp(isMalay),
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: Text(isMalay ? 'Hubungi via WhatsApp' : 'Contact via WhatsApp',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  // Owner buttons
                  if (_isOwner && bantuan.status == 'open') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _isActionLoading ? null : () => _markAsCompleted(isMalay),
                        icon: const Icon(Icons.task_alt, color: Colors.green, size: 18),
                        label: Text(isMalay ? 'Tandakan Selesai' : 'Mark Complete',
                            style: const TextStyle(color: Colors.green, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _isActionLoading ? null : () => _deletePost(isMalay),
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        label: Text(isMalay ? 'Padam Post' : 'Delete Post',
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )),
                    ]),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primaryBlue),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
    ]);
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.backgroundBlue,
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 60, color: AppColors.primaryBlue.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text('Tiada Gambar', style: TextStyle(color: AppColors.primaryBlue.withOpacity(0.3), fontSize: 14)),
        ],
      )),
    );
  }

  String _timeAgo(DateTime dateTime, bool isMalay) {
    final diff = DateTime.now().difference(dateTime);
    if (isMalay) {
      if (diff.inMinutes < 60) return '${diff.inMinutes} minit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';
    } else {
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
  }
}