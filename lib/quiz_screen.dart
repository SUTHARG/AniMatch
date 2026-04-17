import 'package:flutter/material.dart';
import 'anime.dart';           // ← was 'lib/models/anime.dart'
import 'jikan_service.dart';   // ← was '../services/jikan_service.dart'
import 'firebase_service.dart';// ← was '../services/firebase_service.dart'
import 'results_screen.dart';
import 'floating_notification.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final JikanService _jikan = JikanService();
  final FirebaseService _firebase = FirebaseService();

  int _currentStep = 0;
  bool _isLoading = false;

  // Answers
  String? _selectedMood;
  final List<String> _selectedGenres = [];
  String? _selectedEpisodeRange;
  String? _selectedStatus;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Quiz steps data
  static const _moods = [
    {'value': 'dark', 'label': 'Dark & Intense', 'emoji': '🌑', 'sub': 'Thriller, Horror, Psychological'},
    {'value': 'funny', 'label': 'Fun & Lighthearted', 'emoji': '😂', 'sub': 'Comedy, Parody, School'},
    {'value': 'romantic', 'label': 'Romantic & Emotional', 'emoji': '💕', 'sub': 'Romance, Drama, Slice of life'},
    {'value': 'action', 'label': 'Action-packed', 'emoji': '⚡', 'sub': 'Battles, Powers, Fights'},
    {'value': 'chill', 'label': 'Relaxing & Chill', 'emoji': '🌸', 'sub': 'Slice of Life, Iyashikei'},
    {'value': 'adventure', 'label': 'Epic Adventure', 'emoji': '🗺️', 'sub': 'Fantasy, Isekai, Journey'},
    {'value': 'mystery', 'label': 'Mystery & Suspense', 'emoji': '🕵️', 'sub': 'Detective, Mind-bending'},
    {'value': 'battles', 'label': 'Epic Battles', 'emoji': '🗡️', 'sub': 'Martial Arts, Swordplay'},
    {'value': 'cozy', 'label': 'Cozy & Warm', 'emoji': '☕', 'sub': 'Comforting, Healing'},
    {'value': 'gore', 'label': 'Horror & Gore', 'emoji': '🩸', 'sub': 'Terrifying, Bloody, Intense'},
    {'value': 'sports', 'label': 'Sports & Hype', 'emoji': '🏆', 'sub': 'Action, Teamwork, Fire'},
    {'value': 'sad', 'label': 'Sad & Melancholy', 'emoji': '💧', 'sub': 'Emotional, Tear-jerker'},
  ];

  static const _genres = [
    'Action', 'Adventure', 'Cars', 'Comedy', 'Dementia',
    'Demons', 'Drama', 'Ecchi', 'Fantasy', 'Game',
    'Harem', 'Historical', 'Horror', 'Isekai', 'Josei',
    'Kids', 'Magic', 'Martial Arts', 'Mecha', 'Military',
    'Music', 'Mystery', 'Parody', 'Police', 'Psychological',
    'Romance', 'Samurai', 'School', 'Sci-Fi', 'Seinen',
    'Shoujo', 'Shoujo Ai', 'Shounen', 'Shounen Ai',
    'Slice of Life', 'Space', 'Sports', 'Super Power',
    'Supernatural', 'Thriller', 'Vampire',
  ];

  static const _episodeRanges = [
    {'value': 'short', 'label': 'Short', 'sub': 'Under 13 episodes', 'emoji': '⚡'},
    {'value': 'medium', 'label': 'Medium', 'sub': '13 - 50 episodes', 'emoji': '📺'},
    {'value': 'long', 'label': 'Long', 'sub': '50+ episodes', 'emoji': '🔥'},
    {'value': 'any', 'label': 'Any length', 'sub': "I don't mind", 'emoji': '🎲'},
  ];

  static const _statuses = [
    {'value': 'completed', 'label': 'Completed', 'sub': 'Fully released', 'emoji': '✅'},
    {'value': 'ongoing', 'label': 'Ongoing', 'sub': 'Currently airing', 'emoji': '📡'},
    {'value': 'any', 'label': 'Either', 'sub': "Doesn't matter", 'emoji': '🎯'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_canProceed()) return;
    _animController.reset();
    setState(() => _currentStep++);
    _animController.forward();
  }

  void _prevStep() {
    if (_currentStep == 0) return;
    _animController.reset();
    setState(() => _currentStep--);
    _animController.forward();
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedMood != null;
      case 1:
        return _selectedGenres.isNotEmpty;
      case 2:
        return _selectedEpisodeRange != null;
      case 3:
        return _selectedStatus != null;
      default:
        return true;
    }
  }

  Future<void> _getRecommendations() async {
    setState(() => _isLoading = true);

    final answers = QuizAnswers(
      mood: _selectedMood!,
      genres: _selectedGenres,
      episodeRange: _selectedEpisodeRange!,
      status: _selectedStatus!,
    );

    // Save to Firebase (non-blocking)
    _firebase.saveQuizAnswers(answers).catchError((_) {});

    try {
      final results = await _jikan.getRecommendations(answers);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            anime: results,
            quizAnswers: answers,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      FloatingNotification.show(
        context,
        title: 'Quiz Error',
        message: 'Could not load your recommendations. Please try again.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Find Your Anime'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress bar
          _ProgressBar(step: _currentStep, total: 4),
          const SizedBox(height: 8),

          // Step label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Step ${_currentStep + 1} of 4',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Animated content
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStep(),
                ),
              ),
            ),
          ),

          // Bottom button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: _buildBottomButton(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _MoodStep(
          moods: _moods,
          selected: _selectedMood,
          onSelect: (v) => setState(() => _selectedMood = v),
        );
      case 1:
        return _GenreStep(
          genres: _genres,
          selected: _selectedGenres,
          onToggle: (g) => setState(() {
            _selectedGenres.contains(g)
                ? _selectedGenres.remove(g)
                : _selectedGenres.add(g);
          }),
        );
      case 2:
        return _OptionStep(
          question: 'How long do you want it?',
          subtitle: 'Pick a series length',
          options: _episodeRanges,
          selected: _selectedEpisodeRange,
          onSelect: (v) => setState(() => _selectedEpisodeRange = v),
        );
      case 3:
        return _OptionStep(
          question: 'Completed or ongoing?',
          subtitle: 'Do you prefer finished series?',
          options: _statuses,
          selected: _selectedStatus,
          onSelect: (v) => setState(() => _selectedStatus = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButton(ColorScheme colorScheme) {
    final isLast = _currentStep == 3;
    final enabled = _canProceed() && !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: enabled
            ? (isLast ? _getRecommendations : _nextStep)
            : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                isLast ? '✨  Show my recommendations' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ── Progress Bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (step + 1) / total,
          minHeight: 5,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
      ),
    );
  }
}

// ── Step 1: Mood ──────────────────────────────────────────────────────────────

class _MoodStep extends StatelessWidget {
  final List<Map<String, String>> moods;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _MoodStep(
      {required this.moods, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What\'s your mood?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 4),
        Text('Pick the vibe you\'re feeling right now',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: moods.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (_, i) {
            final mood = moods[i];
            final isSelected = selected == mood['value'];
            return _SelectCard(
              emoji: mood['emoji']!,
              label: mood['label']!,
              sub: mood['sub']!,
              isSelected: isSelected,
              onTap: () => onSelect(mood['value']!),
            );
          },
        ),
      ],
    );
  }
}

// ── Step 2: Genre ─────────────────────────────────────────────────────────────

class _GenreStep extends StatelessWidget {
  final List<String> genres;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  const _GenreStep(
      {required this.genres, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick your genres',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 4),
        Text('Select one or more (tap to toggle)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: genres.map((g) {
            final isSelected = selected.contains(g);
            return FilterChip(
              label: Text(g),
              selected: isSelected,
              onSelected: (_) => onToggle(g),
              showCheckmark: false,
              selectedColor: colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            );
          }).toList(),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${selected.length} selected',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Steps 3 & 4: Generic Option ───────────────────────────────────────────────

class _OptionStep extends StatelessWidget {
  final String question;
  final String subtitle;
  final List<Map<String, String>> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _OptionStep({
    required this.question,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 4),
        Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 20),
        ...options.map((opt) {
          final isSelected = selected == opt['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectCard(
              emoji: opt['emoji']!,
              label: opt['label']!,
              sub: opt['sub']!,
              isSelected: isSelected,
              onTap: () => onSelect(opt['value']!),
              fullWidth: true,
            ),
          );
        }),
      ],
    );
  }
}

// ── Reusable selection card ───────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String sub;
  final bool isSelected;
  final VoidCallback onTap;
  final bool fullWidth;

  const _SelectCard({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.isSelected,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withOpacity(0.75)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
