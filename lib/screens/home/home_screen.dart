// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../services/auth_service.dart';
import '../../services/bantuan_service.dart';
import '../../models/bantuan_model.dart';
import '../auth/login_screen.dart';
import '../location/select_location_screen.dart';
import '../bantuan/bantuan_detail_screen.dart';
import '../bantuan/post_bantuan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _bantuanService = BantuanService();

  String _userArea = '';
  String _userAreaId = '';
  String _selectedCategory = 'all';
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _loadUserArea();
  }

  Future<void> _loadUserArea() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userArea = prefs.getString('user_area_name') ?? '';
      _userAreaId = prefs.getString('user_area_id') ?? '';
    });
  }

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return user.displayName ?? user.email ?? 'User';
  }

  void _showLoginRequired(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            const Text('Login Diperlukan'),
          ],
        ),
        content: Text('Anda perlu log masuk untuk $action.\n\nLog masuk sekarang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal / Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()))
                  .then((_) => _loadUserArea());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Masuk / Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, BantuanModel bantuan) async {
    if (!_isLoggedIn) {
      _showLoginRequired(context, 'menghubungi melalui WhatsApp');
      return;
    }
    if (bantuan.whatsapp == null || bantuan.whatsapp!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombor WhatsApp tidak tersedia')),
      );
      return;
    }
    final message = Uri.encodeComponent(
        'Salam, saya berminat dengan post anda bertajuk "${bantuan.title}" di BantuNow.');
    final url = Uri.parse('https://wa.me/${bantuan.whatsapp}?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadUserArea,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildTypeFilter(),
              _buildCategoryFilter(),
              _buildBantuanList(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          const Text('BantuNow',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
      actions: [
        if (_isLoggedIn)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.signOut();
              setState(() {});
            },
          )
        else
          TextButton(
            onPressed: () {
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()))
                  .then((_) => setState(() {}));
            },
            child: const Text('Log Masuk',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoggedIn)
            Text('Selamat Datang, $_userName! 👋',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
          else
            const Text('Assalamualaikum! 👋',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(_userArea.isEmpty ? 'Kuala Terengganu' : _userArea,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (_isLoggedIn) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('user_area_id');
                    await prefs.remove('user_area_name');
                    if (!mounted) return;
                    Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SelectLocationScreen()))
                        .then((_) => _loadUserArea());
                  },
                  child: const Text('(Tukar)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari bantuan... / Search help...',
                hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    final types = [
      {'id': 'all', 'label': 'All'},
      {'id': 'request', 'label': 'Request Help'},
      {'id': 'offer', 'label': 'Offer Help'},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: types.map((type) {
          final isSelected = _selectedType == type['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = type['id']!),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBlue : AppColors.backgroundBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(type['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.primaryBlue)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      {'id': 'all', 'label': 'Semua Kategori / All Categories', 'icon': '🔍'},
      ...BantuanCategories.categories.map((c) => {
            'id': c['id'] as String,
            'label': c['name'] as String,
            'icon': c['icon'] as String,
          }),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlue),
            style: TextStyle(fontSize: 14, color: AppColors.textDark),
            onChanged: (value) {
              if (value != null) setState(() => _selectedCategory = value);
            },
            items: categories.map((cat) {
              final isSelected = _selectedCategory == cat['id'];
              return DropdownMenuItem<String>(
                value: cat['id'] as String,
                child: Row(
                  children: [
                    Text(cat['icon'] as String, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Text(cat['label'] as String,
                        style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ✅ Guna StreamBuilder — real Firestore data
  Widget _buildBantuanList() {
    return StreamBuilder<List<BantuanModel>>(
      stream: _bantuanService.getBantuanStream(
        type: _selectedType == 'all' ? null : _selectedType,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Error
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Ralat memuatkan data\nError loading data',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
          );
        }

        final list = snapshot.data ?? [];

        // Empty
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64, color: AppColors.textGrey),
                  const SizedBox(height: 16),
                  Text('Tiada bantuan dijumpai\nNo help found',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                  if (_isLoggedIn) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PostBantuanScreen())),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Post Bantuan Pertama',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, index) => _buildBantuanCard(list[index]),
        );
      },
    );
  }

  Widget _buildBantuanCard(BantuanModel bantuan) {
    final isRequest = bantuan.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest ? 'Request Help' : 'Offer Help';
    final typeIcon = isRequest ? Icons.help_outline : Icons.volunteer_activism;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (bantuan.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(bantuan.imageUrl!,
                  height: 160, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder()),
            )
          else
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildImagePlaceholder(),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 12, color: typeColor),
                          const SizedBox(width: 4),
                          Text(typeLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${BantuanCategories.getCategoryIcon(bantuan.category)} ${BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0]}',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(bantuan.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),

                const SizedBox(height: 6),

                Text(bantuan.description,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textGrey, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 2),
                    Text(bantuan.area,
                        style: TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                    const Spacer(),
                    Icon(Icons.access_time, size: 12, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(_timeAgo(bantuan.createdAt),
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BantuanDetailScreen(
                                bantuan: bantuan,
                                onLoginRequired: (action) =>
                                    _showLoginRequired(context, action),
                                isLoggedIn: _isLoggedIn,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.visibility_outlined,
                            size: 16, color: AppColors.primaryBlue),
                        label: Text('View Details',
                            style: TextStyle(fontSize: 13, color: AppColors.primaryBlue)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(context, bantuan),
                        icon: const Icon(Icons.chat, size: 16, color: Colors.white),
                        label: const Text('WhatsApp',
                            style: TextStyle(fontSize: 13, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.backgroundBlue,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined,
              size: 40, color: AppColors.primaryBlue.withOpacity(0.4)),
          const SizedBox(height: 4),
          Text('Tiada Gambar',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primaryBlue.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget? _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        if (!_isLoggedIn) {
          _showLoginRequired(context, 'post bantuan');
        } else {
          // ✅ Navigate ke PostBantuanScreen
          Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PostBantuanScreen()))
              .then((_) => setState(() {}));
        }
      },
      backgroundColor: AppColors.primaryBlue,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }
}