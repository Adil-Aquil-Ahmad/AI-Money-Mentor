import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../layout/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../components/common/gradient_background.dart';
import '../../components/common/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePass = true;
  bool _isLoading = false;

  bool _isGoogleLoading = false;
  bool _isHoverSubmit = false;
  bool _isHoverGoogle = false;

  void _submit() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCred;
      if (_isSignUp) {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }
      
      bool isNewUser = userCred.additionalUserInfo?.isNewUser ?? _isSignUp;

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/',
          arguments: isNewUser ? 1 : 0,
        );
      }
    } catch (e, stack) {
      debugPrint('Login Error: $e\n$stack');
      if (mounted) {
        final msg = e is FirebaseAuthException ? (e.message ?? 'Authentication failed') : 'An unexpected error occurred: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        UserCredential userCred = await FirebaseAuth.instance.signInWithPopup(provider);
        bool isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/',
            arguments: isNewUser ? 1 : 0,
          );
        }
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
          bool isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/',
              arguments: isNewUser ? 1 : 0,
            );
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Google Sign-In Error: $e\n$stack');
      if (mounted) {
        final msg = e is FirebaseAuthException ? (e.message ?? 'Google Sign-In failed') : 'Google Sign-In error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: GradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isMobile 
                ? _buildMobileLayout(isDark) 
                : _buildDesktopLayout(isDark),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppTheme.toggleTheme(),
        backgroundColor: AppColors.getGlassBg(isDark, 0.1),
        elevation: 0,
        child: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          color: AppColors.getTextPrimary(isDark),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      // Set a subtle glow based on theme
      glowColor: isDark ? AppColors.primary : AppColors.lightPrimary,
      child: Container(
        width: 900,
        height: 600,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            // Left branding pane
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.getBorder(isDark)),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.getBrandPrimary(isDark).withOpacity(0.05),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(isDark),
                    const SizedBox(height: 32),
                    Text(
                      'Master Your\nFinancial Future',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(isDark),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Join Money Mentor to track your portfolio, run simulation scenarios, and achieve your FIRE goals with AI insights.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextTertiary(isDark),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right auth pane
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
                child: _buildAuthForm(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      glowColor: isDark ? AppColors.primary : AppColors.lightPrimary,
      child: Container(
        width: 400,
        child: Column(
          children: [
            _buildLogo(isDark),
            const SizedBox(height: 32),
            Text(
              'Master Your Wealth',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to access your portfolio',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 32),
            _buildAuthForm(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: AppColors.getBrandGradient(isDark),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.getBrandPrimary(isDark).withOpacity(0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: [
              AppColors.getTextPrimary(isDark), 
              AppColors.getTextTertiary(isDark)
            ],
          ).createShader(b),
          child: Text(
            'Money Mentor',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isSignUp ? 'Create Account' : 'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailCtrl,
          label: 'Email Address',
          icon: Icons.email_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passCtrl,
          label: 'Password',
          icon: Icons.lock_outline,
          isDark: isDark,
          isPassword: true,
        ),
        if (!_isSignUp) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppColors.getBrandPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 24),
        
        // Primary Action Button
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHoverSubmit = true),
          onExit: (_) => setState(() => _isHoverSubmit = false),
          child: GestureDetector(
            onTap: _submit,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: _isHoverSubmit ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: AppColors.getBrandGradient(isDark),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.getBrandPrimary(isDark).withOpacity(_isHoverSubmit ? 0.6 : 0.3),
                      blurRadius: _isHoverSubmit ? 16 : 10,
                      offset: Offset(0, _isHoverSubmit ? 6 : 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Sign Up' : 'Sign In',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Toggle Sign In / Sign Up
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isSignUp ? 'Already have an account?' : 'New to Chrysos?',
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                });
              },
              child: Text(
                _isSignUp ? 'Sign In' : 'Create Account',
                style: TextStyle(
                  color: AppColors.getBrandPrimary(isDark),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.getBorder(isDark))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Or continue with', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
            ),
            Expanded(child: Divider(color: AppColors.getBorder(isDark))),
          ],
        ),
        const SizedBox(height: 24),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHoverGoogle = true),
          onExit: (_) => setState(() => _isHoverGoogle = false),
          child: GestureDetector(
            onTap: _signInWithGoogle,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: _isHoverGoogle ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: _isHoverGoogle 
                      ? AppColors.getGlassBg(isDark, 0.1) 
                      : AppColors.getGlassBg(isDark, 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isHoverGoogle 
                        ? AppColors.getBorder(isDark, 0.3) 
                        : AppColors.getBorder(isDark),
                  ),
                ),
                child: Center(
                  child: _isGoogleLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata, color: AppColors.getTextPrimary(isDark), size: 36),
                            const SizedBox(width: 8),
                            Text(
                              'Sign in with Google',
                              style: TextStyle(
                                color: AppColors.getTextPrimary(isDark),
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
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getGlassBg(isDark, 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark, 0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePass,
        style: TextStyle(color: AppColors.getTextPrimary(isDark)),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: AppColors.getTextTertiary(isDark)),
          prefixIcon: Icon(icon, color: AppColors.getTextTertiary(isDark), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.getTextTertiary(isDark),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
