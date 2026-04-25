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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _rating = index + 1.0),
                child: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 40,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
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
    switch (_rating.toInt()) {
      case 1: return widget.isMalay ? 'Sangat Buruk 😞' : 'Very Poor 😞';
      case 2: return widget.isMalay ? 'Kurang Baik 😕' : 'Poor 😕';
      case 3: return widget.isMalay ? 'Okay 😐' : 'Okay 😐';
      case 4: return widget.isMalay ? 'Baik 😊' : 'Good 😊';
      case 5: return widget.isMalay ? 'Sangat Baik 🌟' : 'Excellent 🌟';
      default: return '';
    }
  }

  Color _getRatingColor() {
    switch (_rating.toInt()) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return Colors.lightGreen;
      case 5: return Colors.green;
      default: return Colors.grey;
    }
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
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}