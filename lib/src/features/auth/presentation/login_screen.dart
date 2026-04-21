import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
import '../../../app.dart';
import '../data/auth_repository.dart';
import '../../subscription/services/subscription_status_service.dart';

enum _AuthEntryStage { methodChoice, emailForm }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _kOnboardingName = 'onboarding_display_name';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _acceptedTerms = false;
  String? _errorMessage;
  _AuthEntryStage _entryStage = _AuthEntryStage.methodChoice;
  String? _onboardingName;

  @override
  void initState() {
    super.initState();
    _loadOnboardingName();
  }

  Future<void> _loadOnboardingName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingName = prefs.getString(_kOnboardingName)?.trim();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bool didSignUp = !_isLogin;
    // Signup sonrası oturum çok hızlı açılınca router yarışa girip kullanıcıyı
    // home'a gönderebiliyor. Bu bayrak redirect'i `/signup-setup`a sabitler.
    ref.read(signupSetupPendingProvider.notifier).state = didSignUp;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (_isLogin) {
        await authRepo.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        if (!_acceptedTerms) {
          setState(() {
            _errorMessage = _auth(
              'auth.accept_terms_required',
              'Kayıt olabilmek için kullanım şartlarını kabul etmelisiniz.',
            );
          });
          return;
        }

        await authRepo.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
        );
      }

      // Giriş/kayıt sonrası abonelik durumunu temizle ve yeniden kontrol et
      ref.invalidate(isProProvider);

      if (mounted) {
        context.go(didSignUp ? '/signup-setup' : '/splash');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _authErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_ensureTermsAcceptedIfSigningUp()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // OAuth login'de signup-setup zorlamasına düşmemek için geçici bayrağı
    // temizleyelim.
    ref.read(signupSetupPendingProvider.notifier).state = false;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogleOAuth();
      // Navigasyon/router redirect ile otomatik yapılır.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithFacebook() async {
    if (!_ensureTermsAcceptedIfSigningUp()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // OAuth login'de signup-setup zorlamasına düşmemek için geçici bayrağı
    // temizleyelim.
    ref.read(signupSetupPendingProvider.notifier).state = false;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithFacebookOAuth();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (!_ensureTermsAcceptedIfSigningUp()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    ref.read(signupSetupPendingProvider.notifier).state = false;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithAppleOAuth();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _acceptedTerms = false;
      _entryStage = _AuthEntryStage.emailForm;
    });
  }

  void _openEmailFlow({bool login = true}) {
    setState(() {
      _isLogin = login;
      _errorMessage = null;
      _entryStage = _AuthEntryStage.emailForm;
    });
  }

  void _backToMethodChoice() {
    setState(() {
      _errorMessage = null;
      _entryStage = _AuthEntryStage.methodChoice;
    });
  }

  bool _ensureTermsAcceptedIfSigningUp() {
    if (_isLogin || _acceptedTerms) return true;
    setState(() {
      _errorMessage = _auth(
        'auth.accept_terms_required',
        'Kayıt olabilmek için kullanım şartlarını kabul etmelisiniz.',
      );
    });
    return false;
  }

  Future<void> _showLegalDialog() async {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translate('settings.terms')),
        content: SizedBox(
          width: 380,
          height: maxHeight,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('settings.terms'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  translate('settings.terms_content'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                Text(
                  translate('settings.privacy'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  translate('settings.privacy_content'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(translate('common.close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: _buildBackgroundGradient(context),
        ),
        child: SafeArea(
          child: isMobile
              ? _buildMobileLayout(context)
              : _buildDesktopLayout(context),
        ),
      ),
    );
  }

  LinearGradient _buildBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              const Color(0xFF0D0D1A),
              const Color(0xFF12102A),
              const Color(0xFF0D0D1A),
            ]
          : [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.primary.withValues(alpha: 0.02),
              Colors.white,
            ],
    );
  }

  /// Çeviri bulunamazsa anahtar yerine anlamlı metin gösterir (auth.* anahtarları için).
  String _auth(String key, String fallback) {
    try {
      final t = translate(key);
      if (t.isEmpty || t == key) return fallback;
      return t;
    } catch (_) {
      return fallback;
    }
  }

  String _authErrorMessage(Object error) {
    final raw = error.toString();
    final msg = raw.toLowerCase();

    bool containsAll(List<String> parts) =>
        parts.every((p) => msg.contains(p.toLowerCase()));

    // Supabase/Auth yaygın mesaj kalıpları.
    if (containsAll(['invalid', 'login']) ||
        (msg.contains('invalid') && msg.contains('credentials')) ||
        msg.contains('wrong password') ||
        msg.contains('invalid password')) {
      return _auth(
        'auth.error_wrong_password',
        'E-posta veya şifre hatalı. Lütfen tekrar deneyin.',
      );
    }

    if (msg.contains('already registered') ||
        msg.contains('user already') ||
        (msg.contains('duplicate') && msg.contains('email')) ||
        msg.contains('email already')) {
      return _auth(
        'auth.error_email_already_used',
        'Bu e-posta ile zaten bir hesap var.',
      );
    }

    if (msg.contains('invalid') && msg.contains('email')) {
      return _auth(
        'auth.error_email_invalid',
        'Geçerli bir e-posta girin.',
      );
    }

    if (msg.contains('password') &&
        (msg.contains('at least') ||
            msg.contains('weak') ||
            msg.contains('require') ||
            msg.contains('min'))) {
      return _auth(
        'auth.error_password_weak',
        'Şifreniz güvenlik gereksinimlerini karşılamıyor.',
      );
    }

    if (msg.contains('email not confirmed') ||
        msg.contains('not confirmed') ||
        msg.contains('verify your email') ||
        msg.contains('confirm your email')) {
      return _auth(
        'auth.error_email_not_confirmed',
        'E-postanızı doğrulamanız gerekiyor. Lütfen gelen kutunuzu kontrol edin.',
      );
    }

    return _auth('auth.error_generic', 'Bir hata oluştu. Lütfen tekrar deneyin.');
  }

  String _buildHelloWithName() {
    final name = (_onboardingName ?? '').trim();
    final helloRaw = _auth('auth.hello_title', 'Hello');
    final hello = helloRaw.replaceAll(RegExp(r'[\s,;:]+$'), '');
    if (name.isEmpty) return helloRaw;
    return '$hello, $name';
  }

  Widget _buildMobileLayout(BuildContext context) {
    if (_entryStage == _AuthEntryStage.methodChoice) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top -
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          children: [
            _buildHeaderSection(context, compact: true),
            const Spacer(),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
              ),
              child: _buildFormCard(context),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top -
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          children: [
            _buildHeaderSection(context, compact: true),
            const SizedBox(height: 76),
            _buildFormCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, {bool compact = false}) {
    final theme = Theme.of(context);
    final isLogin = _isLogin;
    final hasName = (_onboardingName ?? '').isNotEmpty;

    return Padding(
      // Üst boşluğu daha da artır: tüm içerik ekranın ortasına doğru insin.
      padding: EdgeInsets.fromLTRB(28, compact ? 88 : 116, 28, compact ? 32 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isLogin
                ? (hasName
                    ? _buildHelloWithName()
                    : _auth('auth.hello_title', 'Merhaba,'))
                : _auth('auth.welcome_title', 'Hoş geldin,'),
            style: GoogleFonts.inter(
              fontSize: compact ? 36 : 42,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -0.7,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isLogin
                ? _auth('auth.welcome_back', 'Tekrar Hoş Geldin')
                : _auth('auth.signup_title', 'Kayıt Ol'),
            style: GoogleFonts.inter(
              fontSize: compact ? 42 : 48,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.8,
              height: 1.05,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isLogin
                ? _auth('auth.login_subtitle', 'E‑posta ve şifrenle devam et.')
                : _auth('auth.signup_subtitle',
                    'Hesabını oluştur, hikâyelerini dünyayla paylaş.'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.02),
                  Colors.white,
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: _buildHeaderSection(context, compact: false),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildFormCard(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoBox({
    required double size,
    required double borderRadius,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/image/vellum_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.auto_stories_rounded,
            color: AppColors.primary,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    final showApple = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (_entryStage == _AuthEntryStage.methodChoice) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MethodChoiceButton(
              text: 'Google',
              onTap: _isLoading ? null : _signInWithGoogle,
              leading: SvgPicture.asset(
                'assets/image/google_login.svg',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(height: 14),
            _MethodChoiceButton(
              text: 'Facebook',
              onTap: _isLoading ? null : _signInWithFacebook,
              leading: const Icon(Icons.facebook_rounded, size: 24),
            ),
            const SizedBox(height: 14),
            if (showApple)
              _MethodChoiceButton(
                text: 'Apple',
                onTap: _isLoading ? null : _signInWithApple,
                leading: const Icon(Icons.apple_rounded, size: 24),
              ),
            if (!_isLogin) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _showLegalDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Text(
                        _auth('auth.accept_terms', 'Kullanım şartlarını kabul ediyorum'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 42),
            Text(
              _auth('auth.or', 'veya'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openEmailFlow(login: true),
              child: Text(_auth('auth.email_continue', 'e-posta ile devam edin')),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 18),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _backToMethodChoice,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(translate('common.back')),
            ),
          ),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: !_isLogin
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StyledTextField(
                            controller: _usernameController,
                            label: _auth('auth.username', 'Kullanıcı Adı'),
                            hint: _auth('auth.username', 'Kullanıcı Adı'),
                            icon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _auth('auth.username_required', 'Kullanıcı adı gerekli');
                              }
                              if (value.trim().length < 3) {
                                return _auth('auth.username_min', 'En az 3 karakter olmalı');
                              }
                              return null;
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                _StyledTextField(
                  controller: _emailController,
                  label: _auth('auth.email', 'E-posta'),
                  hint: _auth('auth.email_hint', 'E-posta adresinizi girin'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _auth('auth.email_required', 'E-posta gerekli');
                    }
                    if (!value.contains('@')) {
                      return _auth('auth.email_invalid', 'Geçerli bir e-posta girin');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _StyledTextField(
                  controller: _passwordController,
                  label: _auth('auth.password', 'Şifre'),
                  hint: _auth('auth.password_hint', 'Şifrenizi girin'),
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _auth('auth.password_required', 'Şifre gerekli');
                    }
                    if (value.length < 6) {
                      return _auth('auth.password_min', 'En az 6 karakter olmalı');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    onChanged: (v) =>
                        setState(() => _acceptedTerms = v ?? false),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _showLegalDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Text(
                      _auth('auth.accept_terms', 'Kullanım şartlarını kabul ediyorum'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ],
          if (_isLogin) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () =>
                      setState(() => _rememberMe = !_rememberMe),
                  child: Text(
                    _auth('auth.remember_me', 'Beni hatırla'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isLogin
                          ? _auth('auth.login', 'Giriş Yap')
                          : _auth('auth.signup', 'Kayıt Ol'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _auth('auth.or', 'veya'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                  child: Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      thickness: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _auth('auth.ok_login_with', 'Diğer giriş seçenekleri'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showApple) ...[
                    _SocialCircleIcon(
                      icon: Icons.apple_rounded,
                      onTap: () {
                        if (_isLoading) return;
                        _signInWithApple();
                      },
                    ),
                    const SizedBox(width: 14),
                  ],
                  _SocialCircleIcon(
                    icon: Icons.g_mobiledata_rounded,
                    assetSvg: 'assets/image/google_login.svg',
                    onTap: () {
                      _signInWithGoogle();
                    },
                  ),
                  const SizedBox(width: 14),
                  _SocialCircleIcon(
                    icon: Icons.facebook_rounded,
                    onTap: () {
                      _signInWithFacebook();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _toggleMode,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  children: [
                    TextSpan(
                      text: _isLogin
                          ? _auth('auth.no_account', 'Hesabınız yok mu? ')
                          : _auth('auth.have_account', 'Zaten hesabınız var mı? '),
                    ),
                    TextSpan(
                      text: _isLogin
                          ? _auth('auth.signup_link', 'Kayıt Olun')
                          : _auth('auth.login_link', 'Giriş Yapın'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialCircleIcon extends StatelessWidget {
  const _SocialCircleIcon({
    required this.icon,
    required this.onTap,
    this.assetSvg,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? assetSvg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: assetSvg != null
              ? SvgPicture.asset(
                  assetSvg!,
                  width: 28,
                  height: 28,
                )
              : Icon(
                  icon,
                  size: 30,
                  color: theme.colorScheme.onSurface,
                ),
        ),
      ),
    );
  }
}

class _MethodChoiceButton extends StatelessWidget {
  const _MethodChoiceButton({
    required this.text,
    required this.onTap,
    required this.leading,
  });

  final String text;
  final VoidCallback? onTap;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 0,
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

// ─── Styled TextField ────────────────────────────────

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffixIcon,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 10,
            ),
            border: const UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

