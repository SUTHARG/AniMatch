import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'stats_screen.dart';
import 'image_utils.dart';

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

  // No longer needed: using real-time StreamBuilder in the UI

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
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Gradient Base
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.7, -0.6),
                              radius: 1.5,
                              colors: [
                                Colors.amber.withOpacity(0.3),
                                Colors.black,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Animated-like shimmer effect (Static for performance)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.05),
                                Colors.transparent,
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32), // Compensate for status bar manually for better control
                            // Avatar circle with Glow
                            GestureDetector(
                              onTap: () => _pickAvatar(initials),
                              child: Hero(
                                tag: 'profile_avatar',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                                    boxShadow: [
                                      BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white10,
                                    child: Text(
                                      initials,
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(email, style: const TextStyle(fontSize: 13, color: Colors.white54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                    onPressed: () {},
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _firebase.getUserStatsStream(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? {};
                        final loading = snapshot.connectionState == ConnectionState.waiting;
                        
                        if (loading && stats.isEmpty) {
                          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                        }

                        return Row(
                          children: [
                            _QuickStat(
                              value: '${stats['totalAnime'] ?? 0}',
                              label: 'Anime',
                              icon: '🎌',
                            ),
                            _QuickStat(
                              value: '${stats['totalEpisodes'] ?? 0}',
                              label: 'Episodes',
                              icon: '📺',
                            ),
                            _QuickStat(
                              value: _formatMinutes(stats['minutesWatched'] as int? ?? 0),
                              label: 'Watched',
                              icon: '⏱️',
                            ),
                            _QuickStat(
                              value: (stats['avgRating'] as double? ?? 0) == 0
                                  ? '—'
                                  : (stats['avgRating'] as double).toStringAsFixed(1),
                              label: 'Avg score',
                              icon: '⭐',
                            ),
                          ],
                        );
                      },
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
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Same Cinematic Background as Login for continuity
          Positioned.fill(
            child: Image.asset(
              ImageUtils.resolveAsset('assets/images/login_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.3), Colors.black],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Icon(Icons.account_circle_outlined, size: 80, color: Colors.white24),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Join the World of Anime',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sync your watchlist, track your progress, and get personalized recommendations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white60),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}