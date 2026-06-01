// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../providers/bantuan_provider.dart';
import '../../services/auth_service.dart';
import '../../services/geospatial_service.dart';
import '../../models/bantuan_model.dart';
import '../auth/login_screen.dart';
import '../location/select_location_screen.dart';
import '../bantuan/bantuan_detail_screen.dart';
import '../bantuan/post_bantuan_screen.dart';
import '../map/map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/chat_screen.dart';        
import '../../services/chat_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BantuanProvider>().loadUserAreaAndLocation();
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return user.displayName ?? user.email ?? 'User';
  }

  List<BantuanModel> _applySearch(List<BantuanModel> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((post) {
      final titleMatch = post.title.toLowerCase().contains(_searchQuery);
      final descMatch = post.description.toLowerCase().contains(_searchQuery);
      final areaMatch = post.area.toLowerCase().contains(_searchQuery);
      final categoryMatch = BantuanCategories.getCategoryName(post.category)
          .toLowerCase()
          .contains(_searchQuery);
      return titleMatch || descMatch || areaMatch || categoryMatch;
    }).toList();
  }

  void _showLoginRequired(BuildContext context, String action, bool isMalay) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.lock_outline, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(isMalay ? 'Login Diperlukan' : 'Login Required'),
        ]),
        content: Text(isMalay
            ? 'Anda perlu log masuk untuk $action.\n\nLog masuk sekarang?'
            : 'You need to login to $action.\n\nLogin now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isMalay ? 'Batal' : 'Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()))
                  .then((_) {
                context.read<BantuanProvider>().loadUserAreaAndLocation();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isMalay ? 'Log Masuk' : 'Login',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(
      BuildContext context, BantuanModel bantuan, bool isMalay) async {
    if (!_isLoggedIn) {
      _showLoginRequired(context,
          isMalay ? 'menghantar mesej' : 'send a message', isMalay);
      return;
    }

    // Tak boleh chat dengan diri sendiri
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    if (bantuan.postedByUid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'Ini adalah post anda sendiri'
            : 'This is your own post'),
      ));
      return;
    }

    try {
      final chatService = ChatService();
      final conversationId = await chatService.getOrCreateConversation(
        otherUid: bantuan.postedByUid,
        otherName: bantuan.postedBy,
        bantuanId: bantuan.id,
        bantuanTitle: bantuan.title,
      );

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: bantuan.postedBy,
            otherUserUid: bantuan.postedByUid,
            bantuanTitle: bantuan.title,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? 'Gagal membuka mesej: $e'
              : 'Failed to open chat: $e'),
        ));
      }
    }
  }

  void _showCategoryFilter(bool isMalay) {
    final provider = context.read<BantuanProvider>();
    Set<String> tempSelected = Set.from(provider.selectedCategories);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Icon(Icons.filter_list, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  Text(isMalay ? 'Filter Kategori' : 'Filter Category',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        setModalState(() => tempSelected.clear()),
                    child: Text(isMalay ? 'Kosongkan Semua' : 'Clear All',
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              const Divider(height: 1),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: BantuanCategories.categories.map((cat) {
                  final id = cat['id'] as String;
                  final name = cat['name'] as String;
                  final icon = cat['icon'] as String;
                  final isChecked = tempSelected.contains(id);
                  return CheckboxListTile(
                    value: isChecked,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true)
                          tempSelected.add(id);
                        else
                          tempSelected.remove(id);
                      });
                    },
                    title: Row(children: [
                      Text(icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Text(name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: isChecked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isChecked
                                  ? AppColors.primaryBlue
                                  : AppColors.textDark)),
                    ]),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                  );
                }).toList(),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      context
                          .read<BantuanProvider>()
                          .setSelectedCategories(tempSelected);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      tempSelected.isEmpty
                          ? (isMalay
                              ? 'Papar Semua Kategori'
                              : 'Show All Categories')
                          : '${isMalay ? 'Guna Filter' : 'Apply Filter'} (${tempSelected.length} ${isMalay ? 'dipilih' : 'selected'})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBestMatchSheet(bool isMalay) {
    final provider = context.read<BantuanProvider>();

    Set<String> tempCategories = Set.from(provider.selectedCategories);
    double tempRadius = provider.bestMatchRadiusKm;
    String tempType = provider.bestMatchType;
    bool tempAvailable = provider.bestMatchRequireAvailable;

    final radiusOptions = [
      {'label': isMalay ? 'Semua' : 'All', 'value': 0.0},
      {'label': '5 km', 'value': 5.0},
      {'label': '10 km', 'value': 10.0},
      {'label': '25 km', 'value': 25.0},
      {'label': '50 km', 'value': 50.0},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMalay ? 'Criteria Best Match' : 'Best Match Criteria',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark),
                        ),
                        Text(
                          isMalay
                              ? 'Tetapkan kriteria untuk ranking'
                              : 'Set criteria for ranking',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        tempCategories = {};
                        tempRadius = 0;
                        tempType = 'all';
                        tempAvailable = false;
                      }),
                      child: Text(isMalay ? 'Reset' : 'Reset',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                const SizedBox(height: 20),

                _sectionLabel(
                  icon: Icons.category_outlined,
                  label: isMalay ? '1. Kategori' : '1. Category',
                  subtitle: tempCategories.isEmpty
                      ? (isMalay ? 'Semua kategori' : 'All categories')
                      : '${tempCategories.length} ${isMalay ? 'dipilih' : 'selected'}',
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BantuanCategories.categories.map((cat) {
                    final id = cat['id'] as String;
                    final icon = cat['icon'] as String;
                    final name = (cat['name'] as String).split(' / ')[0];
                    final isSelected = tempCategories.contains(id);
                    return GestureDetector(
                      onTap: () => setSheetState(() {
                        if (isSelected)
                          tempCategories.remove(id);
                        else
                          tempCategories.add(id);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text(name,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primaryBlue)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                _sectionLabel(
                  icon: Icons.radar,
                  label: isMalay ? '2. Radius Kawasan' : '2. Area Radius',
                  subtitle: tempRadius == 0
                      ? (isMalay ? 'Tiada had jarak' : 'No distance limit')
                      : '${tempRadius.toStringAsFixed(0)} km',
                  color: Colors.orange,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: radiusOptions.map((opt) {
                    final val = opt['value'] as double;
                    final label = opt['label'] as String;
                    final isSelected = tempRadius == val;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempRadius = val),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange
                              : Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.orange
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.orange.shade700)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                _sectionLabel(
                  icon: Icons.swap_horiz_rounded,
                  label: isMalay ? '3. Jenis Post' : '3. Post Type',
                  subtitle: tempType == 'all'
                      ? (isMalay ? 'Semua jenis' : 'All types')
                      : tempType == 'request'
                          ? '🙋 Request'
                          : '🤲 Offer',
                  color: Colors.green,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _typeChip(
                    label: isMalay ? 'Semua' : 'All',
                    icon: '📋',
                    value: 'all',
                    selected: tempType,
                    color: Colors.green,
                    onTap: () => setSheetState(() => tempType = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(
                    label: 'Request',
                    icon: '🙋',
                    value: 'request',
                    selected: tempType,
                    color: Colors.green,
                    onTap: () => setSheetState(() => tempType = 'request'),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(
                    label: 'Offer',
                    icon: '🤲',
                    value: 'offer',
                    selected: tempType,
                    color: Colors.green,
                    onTap: () => setSheetState(() => tempType = 'offer'),
                  ),
                ]),

                const SizedBox(height: 24),

                _sectionLabel(
                  icon: Icons.volunteer_activism_outlined,
                  label: isMalay
                      ? '4. Ketersediaan Poster'
                      : '4. Poster Availability',
                  subtitle: tempAvailable
                      ? (isMalay
                          ? 'Hanya poster yang Available'
                          : 'Available posters only')
                      : (isMalay ? 'Semua poster' : 'All posters'),
                  color: Colors.teal,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () =>
                      setSheetState(() => tempAvailable = !tempAvailable),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tempAvailable
                          ? Colors.teal.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tempAvailable
                            ? Colors.teal
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        tempAvailable
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: tempAvailable ? Colors.teal : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMalay
                                  ? '🟢 Hanya tunjuk post dari user yang Available'
                                  : '🟢 Show posts from Available users only',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tempAvailable
                                      ? Colors.teal.shade700
                                      : AppColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMalay
                                  ? 'Lebih mudah untuk dapatkan respon cepat'
                                  : 'More likely to get a quick response',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<BantuanProvider>()
                          .applyBestMatchCriteria(
                            categories: tempCategories,
                            radiusKm: tempRadius,
                            type: tempType,
                            requireAvailable: tempAvailable,
                          );
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 18),
                    label: Text(
                      isMalay ? 'Guna Best Match' : 'Apply Best Match',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    ]);
  }

  Widget _typeChip({
    required String label,
    required String icon,
    required String value,
    required String selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? Colors.white : color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMalay = context.watch<LanguageProvider>().isMalay;
    final provider = context.watch<BantuanProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(isMalay),
      body: RefreshIndicator(
        onRefresh: () => context.read<BantuanProvider>().refreshStream(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMalay, provider),
              _buildTypeFilter(isMalay, provider),
              _buildAreaFilterBar(isMalay, provider),
              _buildCategoryFilterBar(isMalay, provider),
              _buildBantuanList(isMalay, provider),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(isMalay),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMalay) {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
      title: const Row(children: [
        Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
        SizedBox(width: 8),
        Text('BantuNow',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ]),

    actions: [
      IconButton(
        icon: const Icon(Icons.map_outlined, color: Colors.white),
        tooltip: isMalay ? 'Peta Bantuan' : 'Help Map',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MapScreen())),
      ),
      if (!_isLoggedIn)
        TextButton(
          onPressed: () =>
              Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()))
                  .then((_) => setState(() {})),
          child: Text(isMalay ? 'Log Masuk' : 'Login',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
    ],
    );
  }

  Widget _buildHeader(bool isMalay, BantuanProvider provider) {
    return Container(
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLoggedIn
                ? '${isMalay ? 'Selamat Datang' : 'Welcome'}, $_userName! 👋'
                : (isMalay ? 'Assalamualaikum! 👋' : 'Hello! 👋'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
                provider.userArea.isEmpty
                    ? 'Kuala Terengganu'
                    : provider.userArea,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (_isLoggedIn) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.remove('user_area_id');
                  await prefs.remove('user_area_name');
                  if (!mounted) return;
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SelectLocationScreen()))
                      .then((_) =>
                          context.read<BantuanProvider>().reloadArea());
                },
                child: Text(isMalay ? '(Tukar)' : '(Change)',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white)),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isMalay ? 'Cari bantuan...' : 'Search help...',
                hintStyle:
                    TextStyle(color: AppColors.textGrey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: AppColors.textGrey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.search, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${isMalay ? 'Mencari' : 'Searching'}: "$_searchQuery"',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Text('✕',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMalay
                        ? '🔒 Lokasi digunakan untuk matching sahaja — tidak disimpan atau dikongsi'
                        : '🔒 Location used for matching only — not stored or shared',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeFilter(bool isMalay, BantuanProvider provider) {
    final types = [
      {'id': 'all', 'label': isMalay ? 'Semua' : 'All'},
      {'id': 'request', 'label': '🙋 Request'},
      {'id': 'offer', 'label': '🤲 Offer'},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: types.map((type) {
          final isSelected = provider.selectedType == type['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => context
                  .read<BantuanProvider>()
                  .setSelectedType(type['id']!),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.backgroundBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(type['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryBlue)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAreaFilterBar(bool isMalay, BantuanProvider provider) {
    if (provider.userAreaId.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        Icon(Icons.location_on, size: 14, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Text(isMalay ? 'Kawasan saya sahaja:' : 'My area only:',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context
              .read<BantuanProvider>()
              .setFilterByArea(!provider.filterByArea),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: provider.filterByArea
                  ? AppColors.primaryBlue
                  : AppColors.backgroundBlue,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: provider.filterByArea
                      ? AppColors.primaryBlue
                      : AppColors.lightGrey),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  provider.filterByArea
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: provider.filterByArea
                      ? Colors.white
                      : AppColors.primaryBlue),
              const SizedBox(width: 4),
              Text(provider.userArea,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: provider.filterByArea
                          ? Colors.white
                          : AppColors.primaryBlue)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildCategoryFilterBar(bool isMalay, BantuanProvider provider) {
    final hasFilter = provider.selectedCategories.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        GestureDetector(
          onTap: () => _showCategoryFilter(isMalay),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: hasFilter ? AppColors.primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: hasFilter
                      ? AppColors.primaryBlue
                      : AppColors.lightGrey),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 4)
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune,
                  size: 16,
                  color: hasFilter ? Colors.white : AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text(
                hasFilter
                    ? 'Filter (${provider.selectedCategories.length})'
                    : (isMalay ? 'Kategori' : 'Category'),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        hasFilter ? Colors.white : AppColors.primaryBlue),
              ),
            ]),
          ),
        ),

        if (provider.userLat != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context
                .read<BantuanProvider>()
                .setSortByNearest(!provider.sortByNearest),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color:
                    provider.sortByNearest ? Colors.orange : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: provider.sortByNearest
                        ? Colors.orange
                        : AppColors.lightGrey),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 4)
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.near_me,
                    size: 16,
                    color: provider.sortByNearest
                        ? Colors.white
                        : Colors.orange),
                const SizedBox(width: 6),
                Text(isMalay ? 'Terdekat' : 'Nearest',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: provider.sortByNearest
                            ? Colors.white
                            : Colors.orange)),
              ]),
            ),
          ),

          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showBestMatchSheet(isMalay),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color:
                    provider.sortByRanking ? Colors.purple : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: provider.sortByRanking
                        ? Colors.purple
                        : AppColors.lightGrey),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 4)
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome,
                    size: 16,
                    color: provider.sortByRanking
                        ? Colors.white
                        : Colors.purple),
                const SizedBox(width: 6),
                Text(
                  isMalay ? 'Terbaik' : 'Best Match',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: provider.sortByRanking
                          ? Colors.white
                          : Colors.purple),
                ),
                if (provider.sortByRanking &&
                    provider.hasBestMatchCriteria) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.amber, shape: BoxShape.circle),
                  ),
                ],
              ]),
            ),
          ),

          if (provider.sortByRanking) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => context
                  .read<BantuanProvider>()
                  .resetBestMatchCriteria(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(Icons.close,
                    size: 14, color: AppColors.textGrey),
              ),
            ),
          ],
        ],

        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (!hasFilter)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.backgroundBlue,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      isMalay ? 'Semua Kategori' : 'All Categories',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primaryBlue)),
                ),
              ...provider.selectedCategories.map((id) {
                final cat = BantuanCategories.categories.firstWhere(
                    (c) => c['id'] == id,
                    orElse: () =>
                        {'id': id, 'name': id, 'icon': '📌'});
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat['icon'] as String,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text((cat['name'] as String).split(' / ')[0],
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => context
                              .read<BantuanProvider>()
                              .removeCategory(id),
                          child: Icon(Icons.close,
                              size: 14, color: AppColors.primaryBlue),
                        ),
                      ]),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBantuanList(bool isMalay, BantuanProvider provider) {
    return StreamBuilder<List<BantuanModel>>(
      stream: provider.bantuanStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                    isMalay
                        ? 'Ralat memuatkan data'
                        : 'Error loading data',
                    style: TextStyle(color: AppColors.textGrey)),
              ]),
            ),
          );
        }

        final filtered = provider.applyFiltersAndSort(snapshot.data ?? []);
        final list = _applySearch(filtered);

        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(children: [
                Icon(Icons.search_off, size: 64, color: AppColors.textGrey),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? (isMalay
                          ? 'Tiada hasil untuk "$_searchQuery"'
                          : 'No results for "$_searchQuery"')
                      : (isMalay
                          ? 'Tiada bantuan dijumpai'
                          : 'No help found'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 16),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(
                        isMalay ? 'Kosongkan Carian' : 'Clear Search'),
                  ),
                ],
                if (provider.sortByRanking &&
                    provider.hasBestMatchCriteria) ...[
                  const SizedBox(height: 8),
                  Text(
                    isMalay
                        ? 'Cuba longgarkan criteria Best Match'
                        : 'Try relaxing your Best Match criteria',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context
                        .read<BantuanProvider>()
                        .resetBestMatchCriteria(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                        isMalay ? 'Reset Criteria' : 'Reset Criteria'),
                  ),
                ] else if (provider.filterByArea ||
                    provider.selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context
                        .read<BantuanProvider>()
                        .clearAllFilters(),
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(
                        isMalay ? 'Kosongkan Filter' : 'Clear Filter'),
                  ),
                ],
                if (_isLoggedIn &&
                    !provider.filterByArea &&
                    provider.selectedCategories.isEmpty &&
                    !provider.sortByRanking &&
                    _searchQuery.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PostBantuanScreen()))
                        .then((_) => setState(() {})),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                        isMalay
                            ? 'Post Bantuan Pertama'
                            : 'Post First Help',
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue),
                  ),
                ],
              ]),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  '${list.length} ${isMalay ? 'hasil untuk' : 'results for'} "$_searchQuery"',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, index) =>
                  _buildBantuanCard(list[index], isMalay, provider),
            ),
          ],
        );
      },
    );
  }

  // ── CARD — tap mana-mana bahagian terus buka detail ──────────────
  Widget _buildBantuanCard(
      BantuanModel bantuan, bool isMalay, BantuanProvider provider) {
    final isRequest = bantuan.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest
        ? (isMalay ? 'Minta Bantuan' : 'Request Help')
        : (isMalay ? 'Tawar Bantuan' : 'Offer Help');
    final typeIcon =
        isRequest ? Icons.help_outline : Icons.volunteer_activism;

    final distance =
        (provider.userLat != null && provider.userLon != null)
            ? GeospatialService.getPostDistance(
                post: bantuan,
                userLat: provider.userLat!,
                userLon: provider.userLon!)
            : null;

    RankedPost? rankedPost;
    if (provider.sortByRanking &&
        provider.userLat != null &&
        provider.userLon != null) {
      final result = GeospatialService.rankPosts(
          posts: [bantuan],
          userLat: provider.userLat!,
          userLon: provider.userLon!,
          preferredCategories: provider.selectedCategories,
          radiusKm: provider.bestMatchRadiusKm,
          filterType: provider.bestMatchType,
          requireAvailable: provider.bestMatchRequireAvailable);
      if (result.isNotEmpty) rankedPost = result.first;
    }

    void openDetail() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BantuanDetailScreen(
              bantuan: bantuan,
              onLoginRequired: (action) =>
                  _showLoginRequired(context, action, isMalay),
              isLoggedIn: _isLoggedIn,
            ),
          ),
        );

    // GestureDetector wrap seluruh kad
    return GestureDetector(
      onTap: openDetail,
      child: Container(
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
            if (bantuan.imageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(bantuan.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                          ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${BantuanCategories.getCategoryIcon(bantuan.category)} ${BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0]}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.primaryBlue),
                      ),
                    ),
                  ]),
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
                          fontSize: 13,
                          color: AppColors.textGrey,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 2),
                    Text(bantuan.area,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primaryBlue)),
                    if (distance != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.near_me,
                                  size: 10,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 3),
                              Text(
                                  GeospatialService.getDistanceLabel(
                                      distance),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ],
                    if (provider.sortByRanking && rankedPost != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 10,
                                  color: Colors.purple.shade700),
                              const SizedBox(width: 3),
                              Text(
                                  '${(rankedPost.compositeScore * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.access_time,
                        size: 12, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(_timeAgo(bantuan.createdAt, isMalay),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textGrey)),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                        // ── Poster info + rating ───────────────────────────
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(bantuan.postedByUid)
                              .get(),
                          builder: (ctx, snap) {
                            final data = snap.hasData && snap.data!.exists
                                ? snap.data!.data() as Map<String, dynamic>
                                : null;
                            final avgRating =
                                (data?['rating'] as num?)?.toDouble() ?? 0.0;
                            final ratingCount =
                                (data?['rating_count'] as num?)?.toInt() ?? 0;
                            return Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppColors.primaryBlue.withOpacity(0.12),
                                child: Text(
                                  bantuan.postedBy.isNotEmpty
                                      ? bantuan.postedBy[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bantuan.postedBy,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (ratingCount > 0) ...[
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  avgRating.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '($ratingCount)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGrey),
                                ),
                              ] else
                                Text(
                                  isMalay ? 'Belum ada rating' : 'No rating yet',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGrey),
                                ),
                            ]);
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: openDetail,

                        icon: Icon(Icons.visibility_outlined,
                            size: 16, color: AppColors.primaryBlue),
                        label: Text(
                            isMalay ? 'Lihat Details' : 'View Details',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryBlue)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _openChat(context, bantuan, isMalay),
                        icon: const Icon(Icons.message_outlined,
                            size: 16, color: Colors.white),
                        label: Text(
                            isMalay ? 'Hubungi' : 'Contact',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isMalay) {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.backgroundBlue,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined,
              size: 40,
              color: AppColors.primaryBlue.withOpacity(0.4)),
          const SizedBox(height: 4),
          Text(isMalay ? 'Tiada Gambar' : 'No Image',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryBlue.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget? _buildFAB(bool isMalay) {
    return FloatingActionButton(
      onPressed: () {
        if (!_isLoggedIn) {
          _showLoginRequired(
              context, isMalay ? 'post bantuan' : 'post help', isMalay);
        } else {
          Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PostBantuanScreen()))
              .then((_) => setState(() {}));
        }
      },
      backgroundColor: AppColors.primaryBlue,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  String _timeAgo(DateTime dateTime, bool isMalay) {
    final diff = DateTime.now().difference(dateTime);
    if (isMalay) {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      return '${diff.inDays}h lalu';
    } else {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
  }
}