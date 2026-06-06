// lib/widgets/rating_dialog.dart

import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../services/rating_service.dart';

class RatingDialog extends StatefulWidget {
  final String bantuanId;
  final String ratedUserUid;
  final String ratedUserName;
  final String type;
  final bool isMalay;

  const RatingDialog({
    Key? key,
    required this.bantuanId,
    required this.ratedUserUid,
    required this.ratedUserName,
    required this.type,
    required this.isMalay,
  }) : super(key: key);

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  final _ratingService = RatingService();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 8),
          Text(
            widget.isMalay ? 'Beri Rating' : 'Rate Experience',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.ratedUserName,
            style: TextStyle(fontSize: 14, color: AppColors.textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Star rating
          // Star rating — half star support
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final fullStar = index + 1.0;
              final halfStar = index + 0.5;
              return GestureDetector(
                onTap: () {
                  // Tap kanan = full star, tap kiri = half star
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    onTapDown: (details) {
                      final isLeftHalf =
                          details.localPosition.dx < 22;
                      setState(() {
                        _rating = isLeftHalf ? halfStar : fullStar;
                      });
                    },
                    child: _rating >= fullStar
                        ? const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 40)
                        : _rating >= halfStar
                            ? const Icon(Icons.star_half_rounded,
                                color: Colors.amber, size: 40)
                            : const Icon(Icons.star_outline_rounded,
                                color: Colors.amber, size: 40),
                  ),
                ),
              );
            }),
          ),

            const SizedBox(height: 8),
            Text(
              _rating.toString().endsWith('.0')
                  ? '${_rating.toInt()} ⭐'
                  : '$_rating ⭐',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 4),
            Text(
              _getRatingLabel(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getRatingColor(),
            ),
          ),
          const SizedBox(height: 16),
          // Comment
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: widget.isMalay
                  ? 'Komen anda (pilihan)...'
                  : 'Your comment (optional)...',
              hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryBlue),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.isMalay ? 'Langkau' : 'Skip',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  widget.isMalay ? 'Hantar' : 'Submit',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }

  String _getRatingLabel() {
    if (_rating == 0.5) return widget.isMalay ? 'Sangat Buruk 😞' : 'Very Poor 😞';
    if (_rating == 1.0) return widget.isMalay ? 'Sangat Buruk 😞' : 'Very Poor 😞';
    if (_rating == 1.5) return widget.isMalay ? 'Buruk 😟' : 'Poor 😟';
    if (_rating == 2.0) return widget.isMalay ? 'Kurang Baik 😕' : 'Below Average 😕';
    if (_rating == 2.5) return widget.isMalay ? 'Kurang Memuaskan 😐' : 'Fair 😐';
    if (_rating == 3.0) return widget.isMalay ? 'Okay 😐' : 'Okay 😐';
    if (_rating == 3.5) return widget.isMalay ? 'Agak Baik 🙂' : 'Above Average 🙂';
    if (_rating == 4.0) return widget.isMalay ? 'Baik 😊' : 'Good 😊';
    if (_rating == 4.5) return widget.isMalay ? 'Sangat Baik 😄' : 'Very Good 😄';
    if (_rating == 5.0) return widget.isMalay ? 'Cemerlang 🌟' : 'Excellent 🌟';
    return '';
  }

  Color _getRatingColor() {
    if (_rating <= 1.0) return Colors.red;
    if (_rating <= 2.0) return Colors.deepOrange;
    if (_rating <= 3.0) return Colors.amber;
    if (_rating <= 4.0) return Colors.lightGreen;
    return Colors.green;
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final result = await _ratingService.submitRating(
      bantuanId: widget.bantuanId,
      ratedUserUid: widget.ratedUserUid,
      rating: _rating,
      comment: _commentController.text.trim(),
      type: widget.type,
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    Navigator.pop(context, result['success']);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isMalay ? '⭐ Rating berjaya dihantar!' : '⭐ Rating submitted!'),
        backgroundColor: const Color.fromARGB(255, 197, 215, 197),
      ));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}