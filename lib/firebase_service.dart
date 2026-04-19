import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'media_base.dart';
import 'anime.dart';

enum ReadStatus {
  reading,
  completed,
  onHold,
  dropped,
  planToRead;

  String get label {
    switch (this) {
      case ReadStatus.reading:    return 'Reading';
      case ReadStatus.completed:  return 'Completed';
      case ReadStatus.onHold:     return 'On Hold';
      case ReadStatus.dropped:    return 'Dropped';
      case ReadStatus.planToRead: return 'Plan to Read';
    }
  }

  String get emoji {
    switch (this) {
      case ReadStatus.reading:    return '📖';
      case ReadStatus.completed:  return '✅';
      case ReadStatus.onHold:     return '⏸️';
      case ReadStatus.dropped:    return '🗑️';
      case ReadStatus.planToRead: return '📋';
    }
  }

  String get value => name;

  static ReadStatus fromString(String? s) {
    return ReadStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ReadStatus.planToRead,
    );
  }
}

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth ──────────────────────────────
  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> registerWithEmail(String email, String password, {String? displayName}) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null && displayName != null) {
        await updateDisplayName(cred.user!.uid, displayName);
      }
      return cred;
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '630393329450-snc00v3ch5rbe23jdiq7ln2qgjj9r4oo.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('CRITICAL Google Sign-In error: $e');
      if (e is PlatformException) {
        debugPrint('Error Details: ${e.details}');
        debugPrint('Error Message: ${e.message}');
      }
      return null;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  Future<void> updateDisplayName(String uid, String name) async {
    await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
    await _db.collection('users').doc(uid).set({
      'displayName': name,
    }, SetOptions(merge: true));
  }

  // ── App Mode ─────────────────────────
  Future<void> saveAppMode(String uid, String mode) async {
    await _db.collection('users').doc(uid).set({
      'appMode': mode,
    }, SetOptions(merge: true));
  }

  Future<String?> getAppMode(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['appMode'] as String?;
  }

  // ── Watchlist (Anime) ─────────────────
  Future<void> addToWatchlist(String uid, Map<String, dynamic> animeData) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('watchlist')
        .doc(animeData['malId'].toString())
        .set(animeData);
  }

  Future<void> removeFromWatchlist(String uid, int malId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('watchlist')
        .doc(malId.toString())
        .delete();
  }

  Future<void> updateWatchStatus(String uid, int malId, String status) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('watchlist')
        .doc(malId.toString())
        .update({'status': status});
  }

  Future<void> updateMangaWatchStatus(String uid, int malId, String status) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('mangaWatchlist')
        .doc(malId.toString())
        .update({'status': status});
  }

  Future<void> updateEpisodeProgress(String uid, int malId, int episode) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('watchlist')
        .doc(malId.toString())
        .update({'episodeProgress': episode});
  }

  Future<void> saveRating(String uid, int malId, double rating, String review, {bool isManga = false}) async {
    final collection = isManga ? 'mangaWatchlist' : 'watchlist';
    await _db
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(malId.toString())
        .update({
      'rating': rating,
      'review': review,
    });
  }

  Stream<List<Map<String, dynamic>>> watchlistStream({String? uid, WatchStatus? filter}) {
    final effectiveUid = uid ?? currentUser?.uid;
    if (effectiveUid == null) return Stream.value([]);
    
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .doc(effectiveUid)
        .collection('watchlist');

    if (filter != null) {
      query = query.where('status', isEqualTo: filter.name);
    }
    
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => doc.data()).toList());
  }

  // ── Manga Watchlist ───────────────────
  Future<void> addToMangaWatchlist(String uid, Map<String, dynamic> mangaData) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('mangaWatchlist')
        .doc(mangaData['malId'].toString())
        .set(mangaData);
  }

  Future<void> removeFromMangaWatchlist(String uid, int malId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('mangaWatchlist')
        .doc(malId.toString())
        .delete();
  }

  Future<void> updateChapterProgress(String uid, int malId, int progress) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('mangaWatchlist')
        .doc(malId.toString())
        .update({'chapterProgress': progress});
  }

  // ── History ────────────────────────────
  Future<void> addToHistory(String uid, MediaBase media) async {
    final Map<String, dynamic> data = {
      'malId': media.malId,
      'title': media.displayTitle,
      'imageUrl': media.displayImageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _db
        .collection('users')
        .doc(uid)
        .collection('history')
        .doc(media.malId.toString())
        .set(data);
  }

  // ── Entry Retrieval ───────────────────
  Future<Map<String, dynamic>?> getWatchlistEntry(String uid, int malId, {bool isManga = false}) async {
    final collection = isManga ? 'mangaWatchlist' : 'watchlist';
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(malId.toString())
        .get();
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>?> getRatingAndReview(String uid, int malId, {bool isManga = false}) async {
    return await getWatchlistEntry(uid, malId, isManga: isManga);
  }

  Stream<List<Map<String, dynamic>>> mangaWatchlistStream({String? uid, ReadStatus? filter}) {
    final effectiveUid = uid ?? currentUser?.uid;
    if (effectiveUid == null) return Stream.value([]);
    
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .doc(effectiveUid)
        .collection('mangaWatchlist');

    if (filter != null) {
      query = query.where('status', isEqualTo: filter.name);
    }
    
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => doc.data()).toList());
  }

  Future<bool> toggleWatchlist(String uid, Map<String, dynamic> animeData) async {
    final malId = animeData['malId'];
    final doc = _db.collection('users').doc(uid).collection('watchlist').doc(malId.toString());
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
      return false; // Removed
    } else {
      await doc.set(animeData);
      return true; // Added
    }
  }

  Future<bool> toggleMangaWatchlist(String uid, Map<String, dynamic> mangaData) async {
    final malId = mangaData['malId'];
    final doc = _db.collection('users').doc(uid).collection('mangaWatchlist').doc(malId.toString());
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
      return false; // Removed
    } else {
      await doc.set(mangaData);
      return true; // Added
    }
  }

  Future<bool> isInWatchlist(String uid, int malId) async {
    final doc = await _db.collection('users').doc(uid).collection('watchlist').doc(malId.toString()).get();
    return doc.exists;
  }

  Future<bool> isInMangaWatchlist(String uid, int malId) async {
    final doc = await _db.collection('users').doc(uid).collection('mangaWatchlist').doc(malId.toString()).get();
    return doc.exists;
  }

  Stream<Map<String, dynamic>> getUserStatsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value({});
    return watchlistStream(uid: uid).map((items) {
      int totalAnime = items.length;
      int totalEpisodes = 0;
      double totalRating = 0;
      int ratingsCount = 0;
      Map<String, int> genres = {};
      Map<String, int> statuses = {
        'watching': 0,
        'completed': 0,
        'onHold': 0,
        'dropped': 0,
        'planToWatch': 0,
      };

      for (var data in items) {
        final episodes = (data['episodeProgress'] as int? ?? 0);
        totalEpisodes += episodes;
        
        final rating = (data['rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          totalRating += rating;
          ratingsCount++;
        }

        final status = data['status'] as String?;
        if (status != null && statuses.containsKey(status)) {
          statuses[status] = statuses[status]! + 1;
        }

        final List<dynamic>? genreList = data['genres'];
        if (genreList != null) {
          for (var g in genreList) {
            genres[g.toString()] = (genres[g.toString()] ?? 0) + 1;
          }
        }
      }

      final topGenres = genres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalAnime': totalAnime,
        'totalEpisodes': totalEpisodes,
        'minutesWatched': totalEpisodes * 24,
        'avgRating': ratingsCount > 0 ? totalRating / ratingsCount : 0.0,
        'ratingsGiven': ratingsCount,
        ...statuses,
        'topGenres': topGenres.take(5).map((e) => e.key).toList(),
      };
    });
  }

  Stream<Map<String, dynamic>> getUserMangaStatsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value({});
    return mangaWatchlistStream(uid: uid).map((items) {
      int totalManga = items.length;
      int totalChapters = 0;
      int totalVolumes = 0;
      double totalRating = 0;
      int ratingsCount = 0;
      Map<String, int> genres = {};
      Map<String, int> statuses = {
        'reading': 0,
        'completed': 0,
        'onHold': 0,
        'dropped': 0,
        'planToRead': 0,
      };

      for (var data in items) {
        totalChapters += (data['chapterProgress'] as int? ?? 0);
        totalVolumes += (data['volumes'] as int? ?? 0);
        
        final rating = (data['rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          totalRating += rating;
          ratingsCount++;
        }

        final status = data['status'] as String?;
        if (status != null && statuses.containsKey(status)) {
          statuses[status] = statuses[status]! + 1;
        }

        final List<dynamic>? genreList = data['genres'];
        if (genreList != null) {
          for (var g in genreList) {
            genres[g.toString()] = (genres[g.toString()] ?? 0) + 1;
          }
        }
      }

      final topGenres = genres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalManga': totalManga,
        'totalChapters': totalChapters,
        'totalVolumes': totalVolumes,
        'avgRating': ratingsCount > 0 ? totalRating / ratingsCount : 0.0,
        'ratingsGiven': ratingsCount,
        ...statuses,
        'topGenres': topGenres.take(5).map((e) => e.key).toList(),
      };
    });
  }

  Future<void> saveQuizAnswers(String uid, QuizAnswers answers) async {
    await _db.collection('users').doc(uid).collection('quizHistory').add({
      'mood': answers.mood,
      'genres': answers.genres,
      'episodeRange': answers.episodeRange,
      'status': answers.status,
      'typeParam': answers.typeParam,
      'isManga': answers.isManga,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Search History ────────────────────
  Future<void> addSearchTerm(String uid, String term) async {
    final sanitizedTerm = term.trim();
    if (sanitizedTerm.isEmpty) return;

    // Use a sanitized ID to prevent duplicates and handle illegal characters like '/'
    final docId = sanitizedTerm.toLowerCase().replaceAll('/', '_');
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('searchHistory')
        .doc(docId)
        .set({
      'term': sanitizedTerm, // Store original display term
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<String>> getRecentSearchesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('searchHistory')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => doc.data()['term'] as String?)
            .whereType<String>() // Only take valid strings
            .toList());
  }


  Future<void> clearSearchHistory(String uid) async {
    final snap = await _db.collection('users').doc(uid).collection('searchHistory').get();
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Streaming Cache ───────────────────
  Future<void> cacheStreamingLinks(String uid, int malId, List<dynamic> links) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('streamingCache')
        .doc(malId.toString())
        .set({
      'links': links,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<dynamic>?> getCachedStreamingLinks(String uid, int malId) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('streamingCache')
        .doc(malId.toString())
        .get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final Timestamp timestamp = data['timestamp'];
    if (DateTime.now().difference(timestamp.toDate()).inDays > 7) return null;
    
    return data['links'] as List<dynamic>?;
  }
}

