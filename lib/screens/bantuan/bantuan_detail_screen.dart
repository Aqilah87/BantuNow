// lib/screens/bantuan/bantuan_detail_screen.dart

import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../models/bantuan_model.dart';

class BantuanDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isRequest = bantuan.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest ? 'Minta Bantuan / Help Request' : 'Tawar Bantuan / Help Offer';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text(
          'Detail Bantuan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              bantuan.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 16),

            // Info cards row
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.category_outlined,
                  label:
                      '${BantuanCategories.getCategoryIcon(bantuan.category)} ${BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0]}',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.location_on_outlined,
                  label: bantuan.area,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penerangan / Description',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bantuan.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textDark,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Posted by
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.backgroundBlue,
                    child: Text(
                      bantuan.postedBy.isNotEmpty
                          ? bantuan.postedBy[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bantuan.postedBy,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _formatDate(bantuan.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            if (isRequest) ...[
              _buildActionButton(
                context: context,
                label: 'Tawarkan Bantuan / Offer Help',
                icon: Icons.volunteer_activism,
                color: Colors.green,
                action: 'menawarkan bantuan',
              ),
            ] else ...[
              _buildActionButton(
                context: context,
                label: 'Mohon Bantuan / Request Help',
                icon: Icons.help_outline,
                color: Colors.orange,
                action: 'memohon bantuan',
              ),
            ],

            const SizedBox(height: 12),

            _buildActionButton(
              context: context,
              label: 'Chat / Hubungi',
              icon: Icons.chat_outlined,
              color: AppColors.primaryBlue,
              action: 'menghantar mesej',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textGrey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.textGrey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required String action,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          if (!isLoggedIn) {
            onLoginRequired(action);
          } else {
            // TODO: implement action
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label - Coming soon!')),
            );
          }
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ogs', 'Sep', 'Okt', 'Nov', 'Dis'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}