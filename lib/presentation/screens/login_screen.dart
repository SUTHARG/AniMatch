import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/core/utils/snackbar_utils.dart' as snacks;
import 'package:animatch/core/utils/image_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _firebase = FirebaseService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    ));

    _animController.forward();
  }

  Future<void> _submit() async {
    // Validate form fields first
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _firebase.signInWithEmail(email, password);
        if (mounted) {
          _showSuccess('Welcome back! 🎉');
          Navigator.pop(context);
        }
      } else {
        final name = _nameController.text.trim();
        await _firebase.registerWithEmail(email, password, displayName: name);
        if (mounted) {
          _showSuccess('Account created! Welcome 🎉');
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      // Map Firebase error codes to friendly messages
      final message = _friendlyError(e.code);
      _showError(message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
      debugPrint('Auth error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-credential':
        return 'Email or password is incorrect. Check your credentials.';
      case 'sign_in_failed':
      case '10':
        return 'Developer Error (10). Ensure Support Email is set in Firebase Console and SHA-1 matches.';
      case 'unsupported-platform':
        return 'Firebase is not configured for this platform (Windows).';
      default:
        return 'Authentication failed ($code). Please check your project settings.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    snacks.showError(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    snacks.showSuccess(context, message);
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Cinematic Background
          Positioned.fill(
            child: ImageUtils.safeBackground(
              'assets/images/login_bg.png',
            ),
          ),
          
          // Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),

          // Safe Area for content
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Hero Icon with Glow
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.primary.withValues(alpha: 0.15),
                                          blurRadius: 40,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Image.asset(
                                        'assets/images/final_app_logo.png',
                                        height: 110,
                                        width: 110,
                                        fit: BoxFit.contain, // Changed to contain to show the full logo
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Title & Description
                                Text(
                                  _isLogin ? 'Welcome back' : 'Create account',
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isLogin
                                      ? 'Log in to sync your anime watchlist'
                                      : 'Start discovering and saving your favorite anime',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 48),

                                // Fields
                                if (!_isLogin) ...[
                                  _GlassField(
                                    controller: _nameController,
                                    label: 'Display name',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) {
                                      if (!_isLogin && (v == null || v.trim().isEmpty)) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                _GlassField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter email';
                                    if (!v.contains('@')) return 'Invalid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                _GlassField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  isPassword: true,
                                  onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter password';
                                    if (!_isLogin && v.length < 6) return 'Too short';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 40),

                                // Submit Button
                                SizedBox(
                                  height: 56,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [Colors.amber, Colors.orange.shade800],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withValues(alpha: 0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                            )
                                          : Text(
                                              _isLogin ? 'Log in' : 'Sign up',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Toggle
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLogin ? "Don't have an account? " : 'Already have an account? ',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading ? null : () {
                                        setState(() => _isLogin = !_isLogin);
                                        _animController.reset();
                                        _animController.forward();
                                      },
                                      child: Text(
                                        _isLogin ? 'Sign up' : 'Log in',
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR CONTINUE WITH',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: Colors.white38,
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Social Logins
                                _PremiumSocialButton(
                                  onPressed: _isLoading ? null : _googleSignIn,
                                  isLoading: _isLoading,
                                  label: 'Continue with Google',
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final cred = await _firebase.signInWithGoogle();
      if (cred != null && mounted) {
        _showSuccess('Logged in as ${cred.user?.displayName ?? 'User'} 🎉');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } catch (e) {
      _showError('Google login failed. Please ensure Google Sign-In is enabled in Firebase.');
      debugPrint('Google Sign-In error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _PremiumSocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const _PremiumSocialButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.white.withValues(alpha: 0.06),
              child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(20, 20),
                        painter: _GoogleLogoPainter(),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.22;

    final Paint bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    final Paint greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    final Paint yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    final Paint redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = strokeWidth;

    final Rect rect = Rect.fromCircle(center: Offset(w/2, h/2), radius: (w - strokeWidth) / 2);

    // Blue section (Right part and the horizontal bar)
    canvas.drawArc(rect, -0.7, 0.7 + 0.5, false, bluePaint);
    canvas.drawLine(Offset(w/2, h/2), Offset(w, h/2), bluePaint);

    // Green section (Bottom)
    canvas.drawArc(rect, 0.5, 1.8, false, greenPaint);

    // Yellow section (Left)
    canvas.drawArc(rect, 0.5 + 1.8, 0.9, false, yellowPaint);

    // Red section (Top)
    canvas.drawArc(rect, 0.5 + 1.8 + 0.9, 1.8, false, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final bool isPassword;
  final TextInputType? keyboardType;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.isPassword = false,
    this.keyboardType,
    this.onToggleVisibility,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.amber, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
