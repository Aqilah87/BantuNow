// lib/screens/bantuan/post_bantuan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
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
  final _imagePicker = ImagePicker();

  String _selectedType = 'request';
  String _selectedCategory = 'makanan';
  String _selectedAreaId = '';
  String _selectedAreaName = '';
  bool _isLoading = false;
  bool _isLoadingPhone = true;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAreaId = prefs.getString('user_area_id') ?? '';
      _selectedAreaName = prefs.getString('user_area_name') ?? '';
    });

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
    } catch (_) {}
    finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  String _formatWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) cleaned = '6$cleaned';
    if (!cleaned.startsWith('60')) cleaned = '60$cleaned';
    return cleaned;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _selectedImage = File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pilih gambar: $e')),
        );
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pilih Gambar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        label: 'Kamera',
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.camera);
                        })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: 'Galeri',
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.gallery);
                        })),
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() => _selectedImage = null);
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Buang Gambar',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            color: AppColors.backgroundBlue,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primaryBlue),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sila pilih kawasan')));
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser!;

    // ✅ Upload image kalau ada
    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _bantuanService.uploadImage(_selectedImage!, user.uid);
    }

    // ✅ Auto-assign koordinat berdasarkan kawasan yang dipilih
    final areaData = KualaTerengganuAreas.getAreaById(_selectedAreaId);
    final double? latitude = areaData?.latitude;
    final double? longitude = areaData?.longitude;

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
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    final result = await _bantuanService.addBantuan(bantuan);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Bantuan berjaya dipost!'),
          backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']),
              backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text('Post Bantuan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

              // ── Type ───────────────────────────────────────────────────────
              _buildSectionLabel('Jenis Bantuan / Type', Icons.category),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTypeChip(
                      label: '🙋 Minta Bantuan',
                      subtitle: 'Saya perlukan bantuan',
                      value: 'request',
                      color: Colors.orange),
                  const SizedBox(width: 12),
                  _buildTypeChip(
                      label: '🤲 Tawar Bantuan',
                      subtitle: 'Saya boleh bantu',
                      value: 'offer',
                      color: Colors.green),
                ],
              ),

              const SizedBox(height: 24),

              // ── Gambar ─────────────────────────────────────────────────────
              _buildSectionLabel('Gambar / Image', Icons.image_outlined),
              const SizedBox(height: 4),
              Text('Pilihan — tambah gambar untuk menarik perhatian',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _selectedImage != null
                            ? AppColors.primaryBlue
                            : AppColors.lightGrey,
                        width: _selectedImage != null ? 2 : 1),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(_selectedImage!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: AppColors.primaryBlue.withOpacity(0.5)),
                            const SizedBox(height: 8),
                            Text('Tekan untuk tambah gambar',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.textGrey)),
                            const SizedBox(height: 4),
                            Text('Kamera atau Galeri',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors.textGrey.withOpacity(0.7))),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Kategori ───────────────────────────────────────────────────
              _buildSectionLabel('Kategori / Category', Icons.label_outline),
              const SizedBox(height: 10),
              _buildDropdownField(
                value: _selectedCategory,
                items: BantuanCategories.categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Row(children: [
                      Text(c['icon']!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(c['name']!, style: const TextStyle(fontSize: 14)),
                    ]),
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
                  if (val.length < 10)
                    return 'Tajuk terlalu pendek (min 10 huruf)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Penerangan ─────────────────────────────────────────────────
              _buildSectionLabel(
                  'Penerangan / Description', Icons.description_outlined),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _descController,
                hint: 'Terangkan dengan lebih lanjut...',
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Sila masukkan penerangan';
                  if (val.length < 20)
                    return 'Penerangan terlalu pendek (min 20 huruf)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Kawasan ────────────────────────────────────────────────────
              _buildSectionLabel('Kawasan / Area', Icons.location_on_outlined),
              const SizedBox(height: 4),
              // ✅ Info: koordinat auto-assign
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi pin pada peta akan ditentukan berdasarkan kawasan yang dipilih.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildDropdownField(
                value: _selectedAreaId.isEmpty ? null : _selectedAreaId,
                hint: 'Pilih kawasan anda',
                items: KualaTerengganuAreas.areas.map((area) {
                  return DropdownMenuItem<String>(
                    value: area.id,
                    child:
                        Text(area.name, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAreaId = val;
                      _selectedAreaName =
                          KualaTerengganuAreas.getAreaName(val);
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── WhatsApp ───────────────────────────────────────────────────
              _buildSectionLabel('Nombor WhatsApp', Icons.phone_outlined),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nombor ini akan jadi butang WhatsApp untuk orang hubungi anda terus.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _isLoadingPhone
                  ? Container(
                      height: 54,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightGrey)),
                      child: const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : _buildTextField(
                      controller: _whatsappController,
                      hint: 'Contoh: 60123456789',
                      maxLines: 1,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Sila masukkan nombor WhatsApp';
                        if (val.length < 10) return 'Nombor tidak sah';
                        return null;
                      },
                    ),

              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────────
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
                      : const Text('Post Bantuan',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildTypeChip(
      {required String label,
      required String subtitle,
      required String value,
      required Color color}) {
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
                width: isSelected ? 2 : 1),
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
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textGrey)),
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
          border: Border.all(color: AppColors.lightGrey)),
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
          border: Border.all(color: AppColors.lightGrey)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: hint != null
              ? Text(hint, style: TextStyle(color: AppColors.textGrey))
              : null,
          icon:
              Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlue),
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