import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'stats_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebase = FirebaseService();
  Map<String, dynamic> _stats = {};
  bool _loadingStats = true;

  // Preset anime avatars (emoji-based, no copyright issues)
  static const _avatars = [
    '🧑‍🦱', '👩‍🦰', '🧑‍🦳', '👨‍🦲', '🧕', '🧔',
    '🥷', '🧙', '🧝', '🧚', '🧜', '🦊',
    '🐉', '⚔️', '🌸', '🎭', '🌙', '⭐',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _firebase.getUserStats();
    if (mounted) setState(() { _stats = stats; _loadingStats = false; });
  }

  Future<void> _pickAvatar(String current) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _AvatarPickerDialog(current: current),
    );
    if (picked != null) {
      // Store in SharedPreferences or Firestore as needed
      // For simplicity, just rebuild
      setState(() {});
    }
  }

  String _formatMinutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    if (h < 24) return '${h}h';
    return '${h ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (user == null) {
          return _NotLoggedInProfile();
        }

        final name = user.displayName?.isNotEmpty == true
            ? user.displayName!
            : 'Anime Fan';
        final email = user.email ?? '';
        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with gradient
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Avatar circle
                          GestureDetector(
                            onTap: () => _pickAvatar(initials),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor:
                              colorScheme.primary.withOpacity(0.3),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(email,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white),
                    onPressed: () => _firebase.signOut(),
                    tooltip: 'Log out',
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Quick stats row
                    _loadingStats
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                      children: [
                        _QuickStat(
                          value: '${_stats['totalAnime'] ?? 0}',
                          label: 'Anime',
                          icon: '🎌',
                        ),
                        _QuickStat(
                          value:
                          '${_stats['totalEpisodes'] ?? 0}',
                          label: 'Episodes',
                          icon: '📺',
                        ),
                        _QuickStat(
                          value: _formatMinutes(
                              _stats['minutesWatched'] as int? ?? 0),
                          label: 'Watched',
                          icon: '⏱️',
                        ),
                        _QuickStat(
                          value: (_stats['avgRating'] as double? ?? 0) == 0
                              ? '—'
                              : (_stats['avgRating'] as double)
                              .toStringAsFixed(1),
                          label: 'Avg score',
                          icon: '⭐',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Menu items
                    Text('Account',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 8),

                    _MenuItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Full Stats',
                      subtitle: 'Detailed breakdown of your activity',
                      color: const Color(0xFF6C5CE7),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StatsScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.edit_rounded,
                      label: 'Edit Display Name',
                      subtitle: user.displayName ?? 'Not set',
                      color: Colors.blue,
                      onTap: () => _editName(context, user.displayName ?? ''),
                    ),
                    const SizedBox(height: 16),

                    Text('App',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 8),

                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'About AniMatch',
                      subtitle: 'Version 1.0.0',
                      color: Colors.grey,
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _firebase.signOut(),
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.red),
                        label: const Text('Log out',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side:
                          const BorderSide(color: Colors.red, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Your name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _firebase.updateDisplayName(result);
      setState(() {});
    }
  }
}

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  const _QuickStat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon, required this.label,
    required this.subtitle, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _AvatarPickerDialog extends StatelessWidget {
  final String current;
  static const _avatars = [
    '🧑‍🦱','👩‍🦰','🧑‍🦳','👨‍🦲','🧕','🧔',
    '🥷','🧙','🧝','🧚','🧜','🦊',
    '🐉','⚔️','🌸','🎭','🌙','⭐',
  ];
  const _AvatarPickerDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick an avatar'),
      content: SizedBox(
        width: 300,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8,
          ),
          itemCount: _avatars.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.pop(context, _avatars[i]),
            child: Text(_avatars[i],
                style: const TextStyle(fontSize: 28),
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _NotLoggedInProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👤', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Log in to see your profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Log in / Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}