// lib/screens/bantuan/post_bantuan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/bantuan_model.dart';
import '../../models/location_model.dart';
import '../../services/bantuan_service.dart';

class PostBantuanScreen extends StatefulWidget {
  // ✅ Optional existingPost — kalau ada, jadi edit mode
  final BantuanModel? existingPost;

  const PostBantuanScreen({Key? key, this.existingPost}) : super(key: key);

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

  // ✅ Track existing image URL (untuk edit mode)
  String? _existingImageUrl;
  bool _removeExistingImage = false;

  bool get _isEditMode => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _prefillExistingData();
    } else {
      _loadUserData();
    }
  }

  // ✅ Pre-fill semua fields dengan data post existing
  void _prefillExistingData() {
    final post = widget.existingPost!;
    _titleController.text = post.title;
    _descController.text = post.description;
    _whatsappController.text = post.whatsapp ?? '';
    _selectedType = post.type;
    _selectedCategory = post.category;
    _selectedAreaId = post.areaId;
    _selectedAreaName = post.area;
    _existingImageUrl = post.imageUrl;
    setState(() => _isLoadingPhone = false);
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
          setState(() => _whatsappController.text = _formatWhatsApp(phone));
        }
      }
    } catch (_) {} finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  String _formatWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) cleaned = '6$cleaned';
    if (!cleaned.startsWith('60')) cleaned = '60$cleaned';
    return cleaned;
  }

  Future<void> _pickImage(ImageSource source, bool isMalay) async {
    try {
      final picked = await _imagePicker.pickImage(
          source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _removeExistingImage = true; // ganti existing image
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isMalay ? 'Gagal pilih gambar' : 'Failed to pick image'}: $e')),
        );
      }
    }
  }

  void _showImagePicker(bool isMalay) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isMalay ? 'Pilih Gambar' : 'Select Image',
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
                        label: isMalay ? 'Kamera' : 'Camera',
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.camera, isMalay);
                        })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: isMalay ? 'Galeri' : 'Gallery',
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.gallery, isMalay);
                        })),
              ],
            ),
            // ✅ Boleh buang gambar (sama ada baru atau existing)
            if (_selectedImage != null ||
                (_existingImageUrl != null && !_removeExistingImage)) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _removeExistingImage = true;
                  });
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                    isMalay ? 'Buang Gambar' : 'Remove Image',
                    style: const TextStyle(color: Colors.red)),
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
        child: Column(children: [
          Icon(icon, size: 32, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue)),
        ]),
      ),
    );
  }

  Future<void> _submit(bool isMalay) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isMalay ? 'Sila pilih kawasan' : 'Please select area')));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;

    // ✅ Handle image logic
    String? imageUrl;
    if (_selectedImage != null) {
      // Ada gambar baru — upload
      imageUrl = await _bantuanService.uploadImage(_selectedImage!, user.uid);
    } else if (!_removeExistingImage) {
      // Kekalkan gambar lama
      imageUrl = _existingImageUrl;
    }
    // Kalau _removeExistingImage = true dan tiada gambar baru → imageUrl = null

    final areaData = KualaTerengganuAreas.getAreaById(_selectedAreaId);

    if (_isEditMode) {
      // ✅ UPDATE mod
      try {
        await FirebaseFirestore.instance
            .collection('bantuan')
            .doc(widget.existingPost!.id)
            .update({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'category': _selectedCategory,
          'area': _selectedAreaName,
          'areaId': _selectedAreaId,
          'type': _selectedType,
          'whatsapp': _whatsappController.text.trim(),
          'imageUrl': imageUrl,
          'latitude': areaData?.latitude,
          'longitude': areaData?.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '✅ Post berjaya dikemaskini!'
              : '✅ Post updated successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true); // ✅ return true supaya MyPosts tahu ada update
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal kemaskini: $e'), backgroundColor: AppColors.error));
      }
    } else {
      // ✅ CREATE mod (sama macam sebelum)
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
        latitude: areaData?.latitude,
        longitude: areaData?.longitude,
      );

      final result = await _bantuanService.addBantuan(bantuan);
      setState(() => _isLoading = false);
      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '✅ Bantuan berjaya dipost!'
              : '✅ Help posted successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMalay = context.watch<LanguageProvider>().isMalay;

    // ✅ Tentukan sama ada nak tunjuk gambar existing atau baru
    final showExistingImage =
        _existingImageUrl != null && !_removeExistingImage && _selectedImage == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        // ✅ Tukar title ikut mode
        title: Text(
          _isEditMode
              ? (isMalay ? 'Edit Post' : 'Edit Post')
              : (isMalay ? 'Post Bantuan' : 'Post Help'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              _buildSectionLabel(
                  isMalay ? 'Jenis Bantuan' : 'Type of Help', Icons.category),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTypeChip(
                    label: isMalay ? '🙋 Minta Bantuan' : '🙋 Request Help',
                    subtitle:
                        isMalay ? 'Saya perlukan bantuan' : 'I need help',
                    value: 'request',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildTypeChip(
                    label: isMalay ? '🤲 Tawar Bantuan' : '🤲 Offer Help',
                    subtitle: isMalay ? 'Saya boleh bantu' : 'I can help',
                    value: 'offer',
                    color: Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionLabel(
                  isMalay ? 'Gambar' : 'Image', Icons.image_outlined),
              const SizedBox(height: 4),
              Text(
                  isMalay
                      ? 'Pilihan — tambah gambar untuk menarik perhatian'
                      : 'Optional — add image to attract attention',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showImagePicker(isMalay),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: (_selectedImage != null || showExistingImage)
                            ? AppColors.primaryBlue
                            : AppColors.lightGrey,
                        width: (_selectedImage != null || showExistingImage)
                            ? 2
                            : 1),
                  ),
                  child: _selectedImage != null
                      // Gambar baru (File)
                      ? Stack(children: [
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
                        ])
                      : showExistingImage
                          // ✅ Gambar existing (Network)
                          ? Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(_existingImageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _removeExistingImage = true),
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
                            ])
                          // Tiada gambar
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: AppColors.primaryBlue
                                        .withOpacity(0.5)),
                                const SizedBox(height: 8),
                                Text(
                                    isMalay
                                        ? 'Tekan untuk tambah gambar'
                                        : 'Tap to add image',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textGrey)),
                                const SizedBox(height: 4),
                                Text(
                                    isMalay
                                        ? 'Kamera atau Galeri'
                                        : 'Camera or Gallery',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey
                                            .withOpacity(0.7))),
                              ],
                            ),
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionLabel(
                  isMalay ? 'Kategori' : 'Category', Icons.label_outline),
              const SizedBox(height: 10),
              _buildDropdownField(
                value: _selectedCategory,
                items: BantuanCategories.categories
                    .map((c) => DropdownMenuItem<String>(
                          value: c['id'],
                          child: Row(children: [
                            Text(c['icon']!,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Text(c['name']!,
                                style: const TextStyle(fontSize: 14)),
                          ]),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? _selectedCategory),
              ),

              const SizedBox(height: 24),

              _buildSectionLabel(isMalay ? 'Tajuk' : 'Title', Icons.title),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _titleController,
                hint: isMalay
                    ? 'Contoh: Perlukan tumpang ke hospital...'
                    : 'Example: Need a ride to hospital...',
                maxLines: 1,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return isMalay
                        ? 'Sila masukkan tajuk'
                        : 'Please enter title';
                  if (val.length < 10)
                    return isMalay
                        ? 'Tajuk terlalu pendek (min 10 huruf)'
                        : 'Title too short (min 10 chars)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              _buildSectionLabel(
                  isMalay ? 'Penerangan' : 'Description',
                  Icons.description_outlined),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _descController,
                hint: isMalay
                    ? 'Terangkan dengan lebih lanjut...'
                    : 'Describe in more detail...',
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return isMalay
                        ? 'Sila masukkan penerangan'
                        : 'Please enter description';
                  if (val.length < 20)
                    return isMalay
                        ? 'Penerangan terlalu pendek (min 20 huruf)'
                        : 'Description too short (min 20 chars)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              _buildSectionLabel(
                  isMalay ? 'Kawasan' : 'Area', Icons.location_on_outlined),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.backgroundBlue,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMalay
                            ? 'Lokasi pin pada peta akan ditentukan berdasarkan kawasan yang dipilih.'
                            : 'Map pin location will be set based on selected area.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildDropdownField(
                value:
                    _selectedAreaId.isEmpty ? null : _selectedAreaId,
                hint: isMalay ? 'Pilih kawasan anda' : 'Select your area',
                items: KualaTerengganuAreas.areas
                    .map((area) => DropdownMenuItem<String>(
                          value: area.id,
                          child: Text(area.name,
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
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

              _buildSectionLabel(
                  isMalay ? 'Nombor WhatsApp' : 'WhatsApp Number',
                  Icons.phone_outlined),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMalay
                            ? 'Nombor ini akan jadi butang WhatsApp untuk orang hubungi anda terus.'
                            : 'This number will be the WhatsApp button for people to contact you.',
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
                          border:
                              Border.all(color: AppColors.lightGrey)),
                      child: const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))),
                    )
                  : _buildTextField(
                      controller: _whatsappController,
                      hint: 'Contoh: 60123456789',
                      maxLines: 1,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return isMalay
                              ? 'Sila masukkan nombor WhatsApp'
                              : 'Please enter WhatsApp number';
                        if (val.length < 10)
                          return isMalay
                              ? 'Nombor tidak sah'
                              : 'Invalid number';
                        return null;
                      },
                    ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _submit(isMalay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          // ✅ Tukar label button ikut mode
                          _isEditMode
                              ? (isMalay
                                  ? 'Kemaskini Post'
                                  : 'Update Post')
                              : (isMalay ? 'Post Bantuan' : 'Post Help'),
                          style: const TextStyle(
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

  // Helper widgets (sama macam sebelum)
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

  Widget _buildTextField(
      {required TextEditingController controller,
      required String hint,
      required int maxLines,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
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
          hintStyle:
              TextStyle(color: AppColors.textGrey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
      {required String? value,
      required List<DropdownMenuItem<String>> items,
      required void Function(String?) onChanged,
      String? hint}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: hint != null
              ? Text(hint,
                  style: TextStyle(color: AppColors.textGrey))
              : null,
          icon: Icon(Icons.keyboard_arrow_down,
              color: AppColors.primaryBlue),
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