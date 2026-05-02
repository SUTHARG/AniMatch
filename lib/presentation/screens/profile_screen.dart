import 'dart:ui';
import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/presentation/screens/login_screen.dart';
import 'package:animatch/presentation/screens/stats_screen.dart';
import 'package:animatch/core/utils/image_utils.dart';
import 'package:animatch/core/utils/snackbar_utils.dart' as snacks;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebase = FirebaseService();

  Future<void> _pickAvatar(String current) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _AvatarPickerDialog(current: current),
    );
    if (picked != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _firebase.updateAvatar(uid, picked);
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (user == null) {
          return _NotLoggedInProfile();
        }

        final name = user.displayName?.isNotEmpty == true
            ? user.displayName!
            : 'Anime Fan';
        final email = user.email ?? '';
        final avatar = user.photoURL;
        final hasImage = avatar != null && avatar.startsWith('http');
        final hasEmoji = avatar != null && !avatar.startsWith('http') && avatar.isNotEmpty;
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
                                Colors.amber.withValues(alpha: 0.3),
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
                                Colors.white.withValues(alpha: 0.05),
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                                height:
                                    32), // Compensate for status bar manually for better control
                            // Avatar circle with Glow
                            GestureDetector(
                              onTap: () => _pickAvatar(initials),
                              child: Hero(
                                tag: 'profile_avatar',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color:
                                            Colors.amber.withValues(alpha: 0.5),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.amber
                                              .withValues(alpha: 0.2),
                                          blurRadius: 20,
                                          spreadRadius: 2),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white10,
                                    backgroundImage: hasImage ? NetworkImage(avatar) : null,
                                    child: hasImage
                                        ? null
                                        : Text(
                                            hasEmoji ? avatar : initials,
                                            style: TextStyle(
                                                fontSize: hasEmoji ? 40 : 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(email,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white70),
                    onPressed: () {},
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Anime Stats Section
                    Text('Anime Statistics',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 12),
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _firebase.getUserStatsStream(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? {};
                        return _StatsCard(
                          icon: '🎌',
                          title: 'Anime',
                          stats: [
                            _MiniStat(
                                label: 'Total',
                                value: '${stats['totalAnime'] ?? 0}'),
                            _MiniStat(
                                label: 'Episodes',
                                value: '${stats['totalEpisodes'] ?? 0}'),
                            _MiniStat(
                                label: 'Avg Score',
                                value: (stats['avgRating'] as double? ?? 0) == 0
                                    ? '—'
                                    : (stats['avgRating'] as double)
                                        .toStringAsFixed(1)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Manga Stats Section
                    Text('Manga Statistics',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 12),
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _firebase.getUserMangaStatsStream(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? {};
                        return _StatsCard(
                          icon: '📖',
                          title: 'Manga',
                          stats: [
                            _MiniStat(
                                label: 'Total',
                                value: '${stats['totalManga'] ?? 0}'),
                            _MiniStat(
                                label: 'Chapters',
                                value: '${stats['totalChapters'] ?? 0}'),
                            _MiniStat(
                                label: 'Avg Score',
                                value: (stats['avgRating'] as double? ?? 0) == 0
                                    ? '—'
                                    : (stats['avgRating'] as double)
                                        .toStringAsFixed(1)),
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
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StatsScreen())),
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
                        icon:
                            const Icon(Icons.logout_rounded, color: Colors.red),
                        label: const Text('Log out',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1),
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _firebase.updateDisplayName(uid, result);
        setState(() {});
      }
    }
  }
}

class _StatsCard extends StatelessWidget {
  final String icon;
  final String title;
  final List<_MiniStat> stats;
  const _StatsCard(
      {required this.icon, required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white70)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: stats
                .map((s) => Expanded(
                      child: Column(
                        children: [
                          Text(s.value,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(s.label,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white54)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniStat {
  final String label;
  final String value;
  _MiniStat({required this.label, required this.value});
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
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
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

class _AvatarPickerDialog extends StatelessWidget {
  final String current;
  static const _avatars = [
    '🧑‍🦱',
    '👩‍🦰',
    '🧑‍🦳',
    '👨‍🦲',
    '🧕',
    '🧔',
    '🥷',
    '🧙',
    '🧝',
    '🧚',
    '🧜',
    '🦊',
    '🐉',
    '⚔️',
    '🌸',
    '🎭',
    '🌙',
    '⭐',
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
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
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
          Positioned.fill(
            child: ImageUtils.safeBackground(
              'assets/images/login_bg.png',
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
                    colors: [Colors.black.withValues(alpha: 0.3), Colors.black],
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
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/final_app_logo.png',
                          height: 90,
                          width: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Join the World of Anime',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Sign In with Email',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12)),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await FirebaseService().signInWithGoogle();
                        } on FirebaseAuthException catch (e) {
                          if (!context.mounted) return;
                          final isNetworkFailure =
                              e.code == 'network-request-failed';
                          snacks.showError(
                            context,
                            isNetworkFailure
                                ? 'Internet required. Please connect to continue.'
                                : 'Google Sign-In failed',
                            actionLabel: isNetworkFailure ? 'Retry' : null,
                            onAction: isNetworkFailure
                                  ? () {
                                      unawaited(FirebaseService()
                                          .signInWithGoogle());
                                    }
                                : null,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            snacks.showError(context, 'Google Sign-In failed');
                          }
                        }
                      },
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                        height: 24,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.login_rounded,
                            color: Colors.white),
                      ),
                      label: const Text('Continue with Google',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
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
