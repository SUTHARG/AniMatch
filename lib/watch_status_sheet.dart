import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'anime.dart';
import 'floating_notification.dart';

/// Shows a bottom sheet to pick / change watch status.
/// Returns the chosen [WatchStatus] or null if dismissed.
Future<WatchStatus?> showWatchStatusSheet(
    BuildContext context, {
      required Anime anime,
      WatchStatus? currentStatus,
    }) {
  return showModalBottomSheet<WatchStatus>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WatchStatusSheet(
      anime: anime,
      currentStatus: currentStatus,
    ),
  );
}

class _WatchStatusSheet extends StatefulWidget {
  final Anime anime;
  final WatchStatus? currentStatus;
  const _WatchStatusSheet({required this.anime, this.currentStatus});

  @override
  State<_WatchStatusSheet> createState() => _WatchStatusSheetState();
}

class _WatchStatusSheetState extends State<_WatchStatusSheet> {
  final FirebaseService _firebase = FirebaseService();
  WatchStatus? _selected;
  bool _saving = false;

  // Config for each status option
  static const _options = [
    _StatusOption(
      status: WatchStatus.watching,
      color: Color(0xFF4CAF50),
      icon: Icons.play_circle_filled_rounded,
      description: 'Currently watching this',
    ),
    _StatusOption(
      status: WatchStatus.planToWatch,
      color: Color(0xFF2196F3),
      icon: Icons.bookmark_add_rounded,
      description: 'Added to your queue',
    ),
    _StatusOption(
      status: WatchStatus.completed,
      color: Color(0xFF9C27B0),
      icon: Icons.check_circle_rounded,
      description: 'Finished watching',
    ),
    _StatusOption(
      status: WatchStatus.onHold,
      color: Color(0xFFFF9800),
      icon: Icons.pause_circle_filled_rounded,
      description: 'Taking a break',
    ),
    _StatusOption(
      status: WatchStatus.dropped,
      color: Color(0xFFF44336),
      icon: Icons.cancel_rounded,
      description: 'Stopped watching',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
  }

  Future<void> _save(WatchStatus status) async {
    if (!_firebase.isLoggedIn) {
      Navigator.pop(context);
      return;
    }

    setState(() { _selected = status; _saving = true; });

    try {
      final alreadyIn = await _firebase.isInWatchlist(widget.anime.malId);
      if (alreadyIn) {
        await _firebase.updateWatchStatus(widget.anime.malId, status);
      } else {
        await _firebase.addToWatchlist(widget.anime, status: status);
      }
      if (mounted) Navigator.pop(context, status);
    } catch (e) {
      if (mounted) {
        FloatingNotification.show(
          context,
          title: 'Update Failed',
          message: 'Could not update your watchlist. Try again.',
          icon: Icons.sync_problem_rounded,
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      await _firebase.removeFromWatchlist(widget.anime.malId);
      if (mounted) Navigator.pop(context, null);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Anime title
          Text(
            widget.anime.displayTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Select watch status',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Status options
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Column(
              children: _options.map((opt) {
                final isSelected = _selected == opt.status;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StatusTile(
                    option: opt,
                    isSelected: isSelected,
                    onTap: () => _save(opt.status),
                  ),
                );
              }).toList(),
            ),

          // Remove from list (only if already added)
          if (widget.currentStatus != null && !_saving) ...[
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                label: const Text('Remove from list',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusOption {
  final WatchStatus status;
  final Color color;
  final IconData icon;
  final String description;
  const _StatusOption({
    required this.status,
    required this.color,
    required this.icon,
    required this.description,
  });
}

class _StatusTile extends StatelessWidget {
  final _StatusOption option;
  final bool isSelected;
  final VoidCallback onTap;
  const _StatusTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withOpacity(0.12)
              : colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? option.color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: option.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(option.icon, color: option.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.status.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected
                          ? option.color
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: option.color, size: 22),
          ],
        ),
      ),
    );
  }
}