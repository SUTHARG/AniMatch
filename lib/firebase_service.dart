import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'anime.dart';           // ← was '../models/anime.dart'

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  bool get isLoggedIn => _auth.currentUser != null;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Watchlist ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _watchlistRef {
    if (_uid == null) throw Exception('User not logged in');
    return _db.collection('users').doc(_uid).collection('watchlist');
  }

  Future<void> addToWatchlist(Anime anime) async {
    await _watchlistRef.doc(anime.malId.toString()).set({
      'malId': anime.malId,
      'title': anime.displayTitle,
      'imageUrl': anime.imageUrl,
      'score': anime.score,
      'episodes': anime.episodes,
      'genres': anime.genres,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFromWatchlist(int malId) async {
    await _watchlistRef.doc(malId.toString()).delete();
  }

  Future<bool> isInWatchlist(int malId) async {
    final doc = await _watchlistRef.doc(malId.toString()).get();
    return doc.exists;
  }

  Stream<List<Map<String, dynamic>>> watchlistStream() {
    return _watchlistRef
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // ── User Preferences / Quiz History ──────────────────────────────────────

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

  Future<Map<String, dynamic>?> getLastQuizAnswers() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data()?['lastQuiz'] as Map<String, dynamic>?;
  }

  // ── Liked / Disliked anime (for future smart recommendations) ─────────────

  Future<void> markAnimeReaction(int malId, bool liked) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('reactions')
        .doc(malId.toString())
        .set({'malId': malId, 'liked': liked, 'at': FieldValue.serverTimestamp()});
  }
}
