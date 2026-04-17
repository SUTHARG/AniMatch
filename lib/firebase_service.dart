import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'anime.dart';

enum WatchStatus {
  watching,
  completed,
  onHold,
  dropped,
  planToWatch;

  String get label {
    switch (this) {
      case WatchStatus.watching:    return 'Watching';
      case WatchStatus.completed:   return 'Completed';
      case WatchStatus.onHold:      return 'On Hold';
      case WatchStatus.dropped:     return 'Dropped';
      case WatchStatus.planToWatch: return 'Plan to Watch';
    }
  }

  String get emoji {
    switch (this) {
      case WatchStatus.watching:    return '▶️';
      case WatchStatus.completed:   return '✅';
      case WatchStatus.onHold:      return '⏸️';
      case WatchStatus.dropped:     return '🗑️';
      case WatchStatus.planToWatch: return '📋';
    }
  }

  String get value => name;

  static WatchStatus fromString(String? s) {
    return WatchStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => WatchStatus.planToWatch,
    );
  }
}

class FirebaseService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? get _uid {
    try { return _auth.currentUser?.uid; } catch (_) { return null; }
  }

  bool get isLoggedIn {
    try { return _auth.currentUser != null; } catch (_) { return false; }
  }

  User? get currentUser => _auth.currentUser;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _ensureUserInitialized(User user) async {
    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'displayName': user.displayName,
      }, SetOptions(merge: true));
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (cred.user != null) await _ensureUserInitialized(cred.user!);
    return cred;
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (cred.user != null) await _ensureUserInitialized(cred.user!);
    return cred;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      if (cred.user != null) await _ensureUserInitialized(cred.user!);
      return cred;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<void> updateDisplayName(String name) =>
      _auth.currentUser!.updateDisplayName(name);

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Watchlist ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _watchlistRef {
    if (_uid == null) throw Exception('User not logged in');
    return _db.collection('users').doc(_uid).collection('watchlist');
  }

  Future<void> addToWatchlist(Anime anime,
      {WatchStatus status = WatchStatus.planToWatch}) async {
    await _watchlistRef.doc(anime.malId.toString()).set({
      'malId': anime.malId,
      'title': anime.displayTitle,
      'imageUrl': anime.imageUrl,
      'score': anime.score,
      'episodes': anime.episodes,
      'genres': anime.genres,
      'status': status.value,
      'episodeProgress': 0,
      'userRating': null,
      'userReview': null,
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWatchStatus(int malId, WatchStatus status) async {
    await _watchlistRef.doc(malId.toString()).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Episode Progress ──────────────────────────────────────────────────────

  Future<void> updateEpisodeProgress(int malId, int episode) async {
    await _watchlistRef.doc(malId.toString()).update({
      'episodeProgress': episode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Ratings & Reviews ─────────────────────────────────────────────────────

  Future<void> saveRatingAndReview(int malId,
      {required double rating, String? review}) async {
    await _watchlistRef.doc(malId.toString()).update({
      'userRating': rating,
      'userReview': review ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getRatingAndReview(int malId) async {
    try {
      final doc = await _watchlistRef.doc(malId.toString()).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return {
        'rating': data['userRating'],
        'review': data['userReview'],
      };
    } catch (_) { return null; }
  }

  // ── Watchlist queries ─────────────────────────────────────────────────────

  Future<WatchStatus?> getWatchStatus(int malId) async {
    try {
      final doc = await _watchlistRef.doc(malId.toString()).get();
      if (!doc.exists) return null;
      return WatchStatus.fromString(doc.data()?['status'] as String?);
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> getWatchlistEntry(int malId) async {
    try {
      final doc = await _watchlistRef.doc(malId.toString()).get();
      return doc.exists ? doc.data() : null;
    } catch (_) { return null; }
  }

  Future<bool> isInWatchlist(int malId) async {
    try {
      final doc = await _watchlistRef.doc(malId.toString()).get();
      return doc.exists;
    } catch (_) { return false; }
  }

  Future<void> removeFromWatchlist(int malId) async {
    await _watchlistRef.doc(malId.toString()).delete();
  }

  Stream<List<Map<String, dynamic>>> watchlistStream({WatchStatus? filter}) {
    Query<Map<String, dynamic>> query =
    _watchlistRef.orderBy('updatedAt', descending: true);
    return query.snapshots().map((snap) {
      final docs = snap.docs.map((d) => d.data()).toList();
      if (filter != null) {
        return docs.where((d) => d['status'] == filter.value).toList();
      }
      return docs;
    });
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> getUserStatsStream() {
    if (_uid == null) return Stream.value({});
    
    return _watchlistRef.snapshots().map((snap) {
      final docs = snap.docs.map((d) => d.data()).toList();

      int totalAnime = docs.length;
      int completed = docs.where((d) => d['status'] == 'completed').length;
      int watching  = docs.where((d) => d['status'] == 'watching').length;
      int dropped   = docs.where((d) => d['status'] == 'dropped').length;
      int planToWatch = docs.where((d) => d['status'] == 'planToWatch').length;
      int onHold    = docs.where((d) => d['status'] == 'onHold').length;

      int totalEpisodes = 0;
      for (final d in docs) {
        totalEpisodes += (d['episodeProgress'] as int? ?? 0);
      }

      final ratings = docs
          .map((d) => d['userRating'])
          .whereType<num>()
          .map((r) => r.toDouble())
          .toList();
      final avgRating = ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length;

      final genreCount = <String, int>{};
      for (final d in docs) {
        final genres = (d['genres'] as List<dynamic>? ?? []).cast<String>();
        for (final g in genres) {
          genreCount[g] = (genreCount[g] ?? 0) + 1;
        }
      }
      final sortedGenres = genreCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topGenres = sortedGenres.take(3).map((e) => e.key).toList();

      return {
        'totalAnime': totalAnime,
        'completed': completed,
        'watching': watching,
        'dropped': dropped,
        'planToWatch': planToWatch,
        'onHold': onHold,
        'totalEpisodes': totalEpisodes,
        'minutesWatched': totalEpisodes * 24,
        'avgRating': avgRating,
        'topGenres': topGenres,
        'ratingsGiven': ratings.length,
      };
    });
  }

  // ── Quiz History ──────────────────────────────────────────────────────────

  Future<void> saveQuizAnswers(QuizAnswers answers) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'lastQuiz': {
        'mood': answers.mood,
        'genres': answers.genres,
        'episodeRange': answers.episodeRange,
        'status': answers.status,
        'savedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // ── History (recently viewed) ─────────────────────────────────────────────

  Future<void> addToHistory(Anime anime) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('history')
        .doc(anime.malId.toString())
        .set({
      'malId': anime.malId,
      'title': anime.displayTitle,
      'imageUrl': anime.imageUrl,
      'viewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAnimeReaction(int malId, bool liked) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('reactions')
        .doc(malId.toString())
        .set({'malId': malId, 'liked': liked, 'at': FieldValue.serverTimestamp()});
  }

  // ── Streaming Cache ───────────────────────────────────────────────────────

  /// Persists [links] for [malId] under streamingCache/{malId} for [uid].
  /// Includes a server timestamp so the 7-day TTL can be enforced on read.
  Future<void> cacheStreamingLinks(
      String uid, int malId, List<dynamic> links) async {
    try {
      final doc = _db
          .collection('users')
          .doc(uid)
          .collection('streamingCache')
          .doc('$malId');
      await doc.set({
        'malId': malId,
        'links': links
            .map((l) => {'name': (l as dynamic).name, 'url': (l as dynamic).url})
            .toList(),
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Cache write failure is non-fatal — streaming data will be re-fetched
      // on the next detail screen open.
    }
  }

  /// Returns cached streaming links for [malId], or `null` if the entry does
  /// not exist or is older than 7 days.
  Future<List<dynamic>?> getCachedStreamingLinks(
      String uid, int malId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('streamingCache')
          .doc('$malId')
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;

      // Expire cache after 7 days
      final cachedAt = (data['cachedAt'] as Timestamp?)?.toDate();
      if (cachedAt == null ||
          DateTime.now().difference(cachedAt).inDays > 7) {
        return null;
      }

      return data['links'] as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Search History ────────────────────────────────────────────────────────

  Future<void> saveSearchQuery(String query) async {
    if (_uid == null || query.trim().isEmpty) return;
    final docRef = _db.collection('users').doc(_uid).collection('metadata').doc('search');
    
    // Add to array, ensuring uniqueness
    await docRef.set({
      'history': FieldValue.arrayUnion([query.trim()]),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Optional: Limit to last 15 items by checking size
    try {
      final doc = await docRef.get();
      if (doc.exists) {
        List<String> history = List<String>.from(doc.data()?['history'] ?? []);
        if (history.length > 15) {
          history = history.sublist(history.length - 15);
          await docRef.update({'history': history});
        }
      }
    } catch (_) {}
  }

  Stream<List<String>> getRecentSearchesStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_uid)
        .collection('metadata')
        .doc('search')
        .snapshots()
        .map((snap) {
          if (!snap.exists) return [];
          final history = List<String>.from(snap.data()?['history'] ?? []);
          return history.reversed.toList(); // Newest first
        });
  }

  Future<void> removeSearchQuery(String query) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('metadata')
        .doc('search')
        .update({
      'history': FieldValue.arrayRemove([query]),
    });
  }

  Future<void> clearSearchHistory() async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('metadata')
        .doc('search')
        .set({
      'history': [],
    }, SetOptions(merge: true));
  }
}