// lib/screens/bantuan/post_bantuan_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../../models/bantuan_model.dart';
import '../../models/location_model.dart';
import '../../services/bantuan_service.dart';

class PostBantuanScreen extends StatefulWidget {
  const PostBantuanScreen({Key? key}) : super(key: key);

  @override
  State<PostBantuanScreen> createState() => _PostBantuanScreenState();
}

class _PostBantuanScreenState extends State<PostBantuanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _bantuanService = BantuanService();

  String _selectedType = 'request';
  String _selectedCategory = 'makanan';
  String _selectedAreaId = '';
  String _selectedAreaName = '';
  bool _isLoading = false;
  bool _isLoadingPhone = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ✅ Auto-fetch nombor telefon dari Firestore
  Future<void> _loadUserData() async {
    // Load kawasan dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAreaId = prefs.getString('user_area_id') ?? '';
      _selectedAreaName = prefs.getString('user_area_name') ?? '';
    });

    // Load nombor telefon dari Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final phone = doc.data()?['num_phone'] ?? '';
          setState(() {
            _whatsappController.text = _formatWhatsApp(phone);
          });
        }
      }
    } catch (e) {
      // Kalau fail, biarkan user isi sendiri
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  // ✅ Format nombor telefon jadi format WhatsApp (60xxxxxxxxx)
  String _formatWhatsApp(String phone) {
    // Buang semua bukan digit
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Tukar 01x jadi 601x
    if (cleaned.startsWith('0')) {
      cleaned = '6$cleaned';
    }

    // Kalau dah start dengan 60, ok
    if (!cleaned.startsWith('60')) {
      cleaned = '60$cleaned';
    }

    return cleaned;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih kawasan anda')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser!;

    final bantuan = BantuanModel(
      id: '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      area: _selectedAreaName,
      areaId: _selectedAreaId,
      status: 'open',
      type: _selectedType,
      postedBy: user.displayName ?? user.email ?? 'User',
      postedByUid: user.uid,
      whatsapp: _whatsappController.text.trim(),
      imageUrl: null,
      createdAt: DateTime.now(),
    );

    final result = await _bantuanService.addBantuan(bantuan);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Bantuan berjaya dipost!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text(
          'Post Bantuan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Jenis Bantuan ──────────────────────────────────────────────
              _buildSectionLabel('Jenis Bantuan / Type', Icons.category),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTypeChip(
                    label: '🙋 Minta Bantuan',
                    subtitle: 'Saya perlukan bantuan',
                    value: 'request',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildTypeChip(
                    label: '🤲 Tawar Bantuan',
                    subtitle: 'Saya boleh bantu',
                    value: 'offer',
                    color: Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Kategori ───────────────────────────────────────────────────
              _buildSectionLabel('Kategori / Category', Icons.label_outline),
              const SizedBox(height: 10),
              _buildDropdownField(
                value: _selectedCategory,
                items: BantuanCategories.categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Row(
                      children: [
                        Text(c['icon'] as String,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(c['name'] as String,
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? _selectedCategory),
              ),

              const SizedBox(height: 24),

              // ── Tajuk ──────────────────────────────────────────────────────
              _buildSectionLabel('Tajuk / Title', Icons.title),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _titleController,
                hint: 'Contoh: Perlukan tumpang ke hospital...',
                maxLines: 1,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Sila masukkan tajuk';
                  if (val.length < 10) return 'Tajuk terlalu pendek (min 10 huruf)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Penerangan ─────────────────────────────────────────────────
              _buildSectionLabel('Penerangan / Description', Icons.description_outlined),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _descController,
                hint: 'Terangkan dengan lebih lanjut tentang bantuan yang diperlukan atau ditawarkan...',
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Sila masukkan penerangan';
                  if (val.length < 20) return 'Penerangan terlalu pendek (min 20 huruf)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Kawasan ────────────────────────────────────────────────────
              _buildSectionLabel('Kawasan / Area', Icons.location_on_outlined),
              const SizedBox(height: 10),
              _buildDropdownField(
                value: _selectedAreaId.isEmpty ? null : _selectedAreaId,
                hint: 'Pilih kawasan anda',
                items: KualaTerengganuAreas.areas.map((area) {
                  return DropdownMenuItem<String>(
                    value: area.id,
                    child: Text(area.name, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAreaId = val;
                      _selectedAreaName = KualaTerengganuAreas.getAreaName(val);
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── WhatsApp ───────────────────────────────────────────────────
              _buildSectionLabel('Nombor WhatsApp', Icons.phone_outlined),
              const SizedBox(height: 4),

              // ✅ Info box - explain auto-filled
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nombor ini akan digunakan sebagai butang WhatsApp untuk orang ramai menghubungi anda terus.',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ✅ Show loading kalau masih fetch phone
              _isLoadingPhone
                  ? Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGrey),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _buildTextField(
                      controller: _whatsappController,
                      hint: 'Contoh: 60123456789',
                      maxLines: 1,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Sila masukkan nombor WhatsApp';
                        }
                        if (val.length < 10) return 'Nombor tidak sah';
                        return null;
                      },
                    ),

              const SizedBox(height: 32),

              // ── Submit Button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Post Bantuan',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildTypeChip({
    required String label,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.lightGrey,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppColors.textDark)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: hint != null
              ? Text(hint, style: TextStyle(color: AppColors.textGrey))
              : null,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlue),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }
}