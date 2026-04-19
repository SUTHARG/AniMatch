import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'media_base.dart';
import 'manga.dart';
import 'utils/snackbar_utils.dart' as snacks;

/// Shows a bottom sheet to pick / change watch or read status.
/// Returns the chosen status enum or null if dismissed.
Future<dynamic> showMediaStatusSheet(
    BuildContext context, {
      required MediaBase media,
      bool isManga = false,
      dynamic currentStatus,
    }) {
  return showModalBottomSheet<dynamic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MediaStatusSheet(
      media: media,
      isManga: isManga,
      currentStatus: currentStatus,
    ),
  );
}

class _MediaStatusSheet extends StatefulWidget {
  final MediaBase media;
  final bool isManga;
  final dynamic currentStatus;
  const _MediaStatusSheet({required this.media, required this.isManga, this.currentStatus});

  @override
  State<_MediaStatusSheet> createState() => _MediaStatusSheetState();
}

class _MediaStatusSheetState extends State<_MediaStatusSheet> {
  final FirebaseService _firebase = FirebaseService();
  dynamic _selected;
  bool _saving = false;

  late final List<_StatusOption> _options;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
    
    if (widget.isManga) {
      _options = [
        const _StatusOption(
          readStatus: ReadStatus.reading,
          color: Color(0xFF4CAF50),
          icon: Icons.menu_book_rounded,
          description: 'Currently reading this',
        ),
        const _StatusOption(
          readStatus: ReadStatus.planToRead,
          color: Color(0xFF2196F3),
          icon: Icons.bookmark_add_rounded,
          description: 'Added to your reading list',
        ),
        const _StatusOption(
          readStatus: ReadStatus.completed,
          color: Color(0xFF9C27B0),
          icon: Icons.check_circle_rounded,
          description: 'Finished reading',
        ),
        const _StatusOption(
          readStatus: ReadStatus.onHold,
          color: Color(0xFFFF9800),
          icon: Icons.pause_circle_filled_rounded,
          description: 'Taking a break',
        ),
        const _StatusOption(
          readStatus: ReadStatus.dropped,
          color: Color(0xFFF44336),
          icon: Icons.cancel_rounded,
          description: 'Stopped reading',
        ),
      ];
    } else {
      _options = [
        const _StatusOption(
          watchStatus: WatchStatus.watching,
          color: Color(0xFF4CAF50),
          icon: Icons.play_circle_filled_rounded,
          description: 'Currently watching this',
        ),
        const _StatusOption(
          watchStatus: WatchStatus.planToWatch,
          color: Color(0xFF2196F3),
          icon: Icons.bookmark_add_rounded,
          description: 'Added to your queue',
        ),
        const _StatusOption(
          watchStatus: WatchStatus.completed,
          color: Color(0xFF9C27B0),
          icon: Icons.check_circle_rounded,
          description: 'Finished watching',
        ),
        const _StatusOption(
          watchStatus: WatchStatus.onHold,
          color: Color(0xFFFF9800),
          icon: Icons.pause_circle_filled_rounded,
          description: 'Taking a break',
        ),
        const _StatusOption(
          watchStatus: WatchStatus.dropped,
          color: Color(0xFFF44336),
          icon: Icons.cancel_rounded,
          description: 'Stopped watching',
        ),
      ];
    }
  }

  Future<void> _save(dynamic status) async {
    final uid = _uid;
    if (uid == null) {
      snacks.showError(context, 'Please sign in to save');
      Navigator.pop(context);
      return;
    }

    setState(() { _selected = status; _saving = true; });

    try {
      if (widget.isManga) {
        final alreadyIn = await _firebase.isInMangaWatchlist(uid, widget.media.malId);
        if (alreadyIn) {
          await _firebase.updateMangaWatchStatus(uid, widget.media.malId, (status as ReadStatus).name);
        } else {
          final Map<String, dynamic> data = {
            'malId': widget.media.malId,
            'title': widget.media.displayTitle,
            'imageUrl': widget.media.displayImageUrl,
            'score': widget.media.score,
            'status': (status as ReadStatus).name,
            'type': 'manga',
            'chapters': widget.media.chapters,
            'volumes': (widget.media as Manga).volumes,
          };
          await _firebase.addToMangaWatchlist(uid, data);
        }
      } else {
        final alreadyIn = await _firebase.isInWatchlist(uid, widget.media.malId);
        if (alreadyIn) {
          await _firebase.updateWatchStatus(uid, widget.media.malId, (status as WatchStatus).name);
        } else {
          final Map<String, dynamic> data = {
            'malId': widget.media.malId,
            'title': widget.media.displayTitle,
            'imageUrl': widget.media.displayImageUrl,
            'score': widget.media.score,
            'status': (status as WatchStatus).name,
            'type': 'anime',
            'episodes': widget.media.episodes,
          };
          await _firebase.addToWatchlist(uid, data);
        }
      }
      if (mounted) Navigator.pop(context, status);
    } catch (e) {
      if (mounted) {
        snacks.showError(context, 'Could not update your watchlist. Try again.');
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _remove() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      if (widget.isManga) {
        await _firebase.removeFromMangaWatchlist(uid, widget.media.malId);
      } else {
        await _firebase.removeFromWatchlist(uid, widget.media.malId);
      }
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
            widget.media.displayTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.isManga ? 'Select reading status' : 'Select watch status',
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
                final status = widget.isManga ? opt.readStatus : opt.watchStatus;
                final isSelected = _selected == status;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StatusTile(
                    option: opt,
                    isSelected: isSelected,
                    isManga: widget.isManga,
                    onTap: () => _save(status),
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
  final WatchStatus? watchStatus;
  final ReadStatus? readStatus;
  final Color color;
  final IconData icon;
  final String description;
  const _StatusOption({
    this.watchStatus,
    this.readStatus,
    required this.color,
    required this.icon,
    required this.description,
  });

  String get label => watchStatus?.label ?? readStatus?.label ?? '';
}

class _StatusTile extends StatelessWidget {
  final _StatusOption option;
  final bool isSelected;
  final bool isManga;
  final VoidCallback onTap;
  const _StatusTile({
    required this.option,
    required this.isSelected,
    required this.isManga,
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
              ? option.color.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                color: option.color.withValues(alpha: 0.15),
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
                    option.label,
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
