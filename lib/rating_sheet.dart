import 'package:flutter/material.dart';
import 'firebase_service.dart';

/// Shows a bottom sheet to rate and review an anime.
Future<void> showRatingSheet(
    BuildContext context, {
      required int malId,
      required String animeTitle,
      double? currentRating,
      String? currentReview,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RatingSheet(
      malId: malId,
      animeTitle: animeTitle,
      currentRating: currentRating,
      currentReview: currentReview,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  final int malId;
  final String animeTitle;
  final double? currentRating;
  final String? currentReview;
  const _RatingSheet({
    required this.malId,
    required this.animeTitle,
    this.currentRating,
    this.currentReview,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final FirebaseService _firebase = FirebaseService();
  final TextEditingController _reviewController = TextEditingController();
  double _rating = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.currentRating ?? 0;
    _reviewController.text = widget.currentReview ?? '';
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String _ratingLabel(double r) {
    if (r == 0)  return 'Tap to rate';
    if (r <= 2)  return 'Awful 😖';
    if (r <= 4)  return 'Bad 😕';
    if (r <= 6)  return 'Okay 😐';
    if (r <= 7)  return 'Good 🙂';
    if (r <= 8)  return 'Great 😊';
    if (r <= 9)  return 'Excellent 🤩';
    return 'Masterpiece 🏆';
  }

  Color _ratingColor(double r) {
    if (r == 0) return Colors.grey;
    if (r <= 4) return Colors.red;
    if (r <= 6) return Colors.orange;
    if (r <= 8) return Colors.green;
    return const Color(0xFF6C5CE7);
  }

  Future<void> _save() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _firebase.saveRatingAndReview(
        widget.malId,
        rating: _rating,
        review: _reviewController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Rate & Review',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.animeTitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),

            // Rating label
            Center(
              child: Column(
                children: [
                  Text(
                    _rating == 0 ? '—' : _rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _ratingColor(_rating),
                    ),
                  ),
                  Text(
                    _ratingLabel(_rating),
                    style: TextStyle(
                      fontSize: 16,
                      color: _ratingColor(_rating),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Star slider (1-10)
            Row(
              children: [
                const Text('1', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 0,
                    max: 10,
                    divisions: 20, // 0.5 steps
                    activeColor: _ratingColor(_rating),
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                const Text('10', style: TextStyle(fontSize: 12)),
              ],
            ),

            // Star display
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(10, (i) {
                  final filled = i < _rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? Colors.amber : colorScheme.outlineVariant,
                    size: 22,
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Review text field
            TextField(
              controller: _reviewController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Write your thoughts... (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                    : const Text('Save Rating',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}