import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../services/notification_permission_service.dart';
import '../../library/data/book_report_repository.dart';
import '../../library/domain/book_report.dart';
import '../../subscription/services/subscription_status_service.dart';
import '../../../config/version.dart';

// ─── Providers ───────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Bildirim tercihleri için geçici (sadece oturum içi) state.
/// Gerçek kaynak Supabase'deki `profiles.notification_preferences`.
/// Bu provider sadece ekranda anında güncelleme (optimistic UI) için kullanılıyor.
final notificationSettingsProvider =
    StateProvider<Map<String, bool>>((ref) => {});

final fontSizeProvider = StateProvider<String>((ref) => 'Orta');

/// Sistem bildirim izni durumu (yenilemek için invalidate edin).
/// Web/desktop gibi izin API'si olmayan platformlarda [PermissionStatus.granted] kabul edilir.
final notificationPermissionStatusProvider =
    FutureProvider<PermissionStatus>((ref) async {
  try {
    return await NotificationPermissionService.status;
  } catch (_) {
    return PermissionStatus.granted;
  }
});

// ═════════════════════════════════════════════════════
// ANA AYARLAR EKRANI
// ═════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final appVersionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              'Ayarlar',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // ─── Profil Kartı ────────────────────────
            profileAsync.when(
              data: (profile) => _ProfileCard(
                username: profile?.username ?? 'Kullanıcı',
                email:
                    ref.read(authRepositoryProvider).currentUser?.email ?? '',
                avatarUrl: profile?.avatarUrl,
                isDark: isDark,
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ProfileEditPage(profile: profile),
                  ),
                ),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 28),

            // ─── Hesap ──────────────────────────────
            _SectionTitle(title: 'Hesap'),
            const SizedBox(height: 8),
            _SettingsGroup(
              isDark: isDark,
              items: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Profil Bilgileri',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ProfileEditPage(
                        profile: profileAsync.valueOrNull,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Güvenlik',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _SecurityPage()),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Bildirimler',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _NotificationsPage()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Görünüm ────────────────────────────
            _SectionTitle(title: 'Görünüm'),
            const SizedBox(height: 8),
            _SettingsGroup(
              isDark: isDark,
              items: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  label: 'Tema',
                  showChevron: false,
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ThemeChip(
                          icon: Icons.light_mode_rounded,
                          label: 'Aydınlık',
                          isSelected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .state = ThemeMode.light,
                        ),
                        _ThemeChip(
                          icon: Icons.dark_mode_rounded,
                          label: 'Karanlık',
                          isSelected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .state = ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.language_rounded,
                  label: 'Dil',
                  subtitle: 'Türkçe',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _LanguagePage()),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.text_fields_rounded,
                  label: 'Font Boyutu',
                  subtitle: ref.watch(fontSizeProvider),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _FontSizePage()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Geliştirici (sadece is_developer kullanıcılar) ───
            if (profileAsync.valueOrNull?.isDeveloper == true) ...[
              _SectionTitle(title: 'Geliştirici'),
              const SizedBox(height: 8),
              _SettingsGroup(
                isDark: isDark,
                items: [
                  _SettingsTile(
                    icon: Icons.flag_outlined,
                    label: 'Kitap şikayetleri',
                    subtitle: 'Şikayetleri görüntüle ve okundu işaretle',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _DeveloperReportsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ─── Hakkında ────────────────────────────
            _SectionTitle(title: 'Hakkında'),
            const SizedBox(height: 8),
            _SettingsGroup(
              isDark: isDark,
              items: [
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Yardım & SSS',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _HelpPage()),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  label: 'Kullanım Şartları',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _LegalPage(
                        title: 'Kullanım Şartları',
                        content: _termsText,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Gizlilik Politikası',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _LegalPage(
                        title: 'Gizlilik Politikası',
                        content: _privacyText,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Uygulama Sürümü',
                  subtitle: appVersionAsync.when(
                    data: (v) => 'v$v',
                    loading: () => 'Yükleniyor...',
                    error: (_, __) => 'Bilinmiyor',
                  ),
                  showChevron: false,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ─── Çıkış Yap ─────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Çıkış Yap'),
                      content: const Text(
                          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('İptal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          child: const Text('Çıkış Yap'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.invalidate(isProProvider);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Çıkış Yap',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// ALT SAYFALAR (TAM EKRAN)
// ═════════════════════════════════════════════════════

// ─── Profil Düzenleme Sayfası ─────────────────────────

class _ProfileEditPage extends ConsumerStatefulWidget {
  const _ProfileEditPage({this.profile});
  final dynamic profile;

  @override
  ConsumerState<_ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<_ProfileEditPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  late List<Map<String, dynamic>> _links;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _usernameController = TextEditingController(text: p?.username ?? '');
    _bioController = TextEditingController(text: p?.bio ?? '');
    _avatarUrl = p?.avatarUrl;
    _links = List<Map<String, dynamic>>.from(
      (p?.links as List<dynamic>?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          <Map<String, dynamic>>[],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await image.readAsBytes();
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) return;

      final url = await ref.read(authRepositoryProvider).uploadAvatar(
            userId: userId,
            filePath: image.name,
            fileBytes: bytes,
          );

      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar yüklenemedi: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _addLink() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_link_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Yeni Link Ekle'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Başlık',
                  hintText: 'Ör: Twitter, Instagram, Web Sitesi',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Başlık gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: urlController,
                style: theme.textTheme.bodyLarge,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'URL gerekli';
                  }
                  if (!value.trim().startsWith('http://') &&
                      !value.trim().startsWith('https://')) {
                    return 'Geçerli bir URL girin (http:// veya https://)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final title = titleController.text.trim();
                final url = urlController.text.trim();
                setState(() {
                  _links.add({'title': title, 'url': url});
                });
                Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Ekle'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeLink(int index) {
    setState(() => _links.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            id: userId,
            username: _usernameController.text.trim(),
            bio: _bioController.text.trim(),
            links: _links,
            avatarUrl: _avatarUrl,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil guncellendi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authRepositoryProvider).currentUser?.email ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Düzenle'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Kaydet'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ─── Avatar Bölümü (Hero Style) ──────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  children: [
                    // Avatar Container
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: ClipOval(
                              child: _avatarBytes != null
                                  ? Image.memory(
                                      _avatarBytes!,
                                      fit: BoxFit.cover,
                                      width: 132,
                                      height: 132,
                                    )
                                  : _avatarUrl != null
                                      ? Image.network(
                                          _avatarUrl!,
                                          fit: BoxFit.cover,
                                          width: 132,
                                          height: 132,
                                          errorBuilder: (_, __, ___) =>
                                              _buildAvatarPlaceholder(),
                                        )
                                      : _buildAvatarPlaceholder(),
                            ),
                          ),
                          // Camera Button
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade900
                                      : Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _uploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fotoğrafı değiştirmek için dokunun',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Form Alanları ────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Kişisel Bilgiler Card ─────────────
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Kişisel Bilgiler',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Kullanıcı Adı
                          TextFormField(
                            controller: _usernameController,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              labelText: 'Kullanıcı Adı',
                              hintText: 'Kullanıcı adınızı girin',
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.02),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kullanıcı adı boş olamaz';
                              }
                              if (value.trim().length < 3) {
                                return 'En az 3 karakter olmalı';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // E-posta (salt okunur)
                          TextFormField(
                            initialValue: email,
                            enabled: false,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            decoration: InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.black.withValues(alpha: 0.01),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.04),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Hakkımda Card ─────────────────────
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Hakkımda',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _bioController,
                            maxLines: 5,
                            maxLength: 300,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Kendinizden bahsedin...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.02),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Linkler Card ───────────────────────
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.link_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sosyal Medya & Linkler',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _addLink,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Ekle'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_links.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.link_off_rounded,
                                      size: 32,
                                      color: AppColors.primary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Henüz link eklenmemiş',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sosyal medya hesaplarınızı ekleyin',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...List.generate(_links.length, (index) {
                              final link = _links[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.primary.withValues(alpha: 0.15),
                                            AppColors.secondary.withValues(alpha: 0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getLinkIcon(link['title'] ?? ''),
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            link['title'] ?? '',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            link['url'] ?? '',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: AppColors.primary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: AppColors.error.withValues(alpha: 0.7),
                                      ),
                                      onPressed: () => _removeLink(index),
                                      tooltip: 'Sil',
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.secondary.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _usernameController.text.isNotEmpty
              ? _usernameController.text[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  IconData _getLinkIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('twitter') || lower.contains('x.com')) {
      return Icons.alternate_email;
    }
    if (lower.contains('instagram')) return Icons.camera_alt_outlined;
    if (lower.contains('youtube')) return Icons.play_circle_outline;
    if (lower.contains('github')) return Icons.code;
    if (lower.contains('linkedin')) return Icons.business_center_outlined;
    if (lower.contains('web') || lower.contains('site')) {
      return Icons.language;
    }
    return Icons.link;
  }
}

// ─── Güvenlik Sayfası ────────────────────────────────

class _SecurityPage extends StatefulWidget {
  const _SecurityPage();

  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPw.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifre başarıyla değiştirildi ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Güvenlik')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Güvenliğiniz için şifrenizi düzenli olarak değiştirin.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Mevcut şifre
            Text('Mevcut Şifre',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _currentPw,
              obscureText: !_showCurrent,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showCurrent = !_showCurrent),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Bu alan zorunlu' : null,
            ),
            const SizedBox(height: 20),

            // Yeni şifre
            Text('Yeni Şifre',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPw,
              obscureText: !_showNew,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon:
                      Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) {
                if (v == null || v.length < 6) return 'En az 6 karakter';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Tekrar
            Text('Yeni Şifre (Tekrar)',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPw,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) {
                if (v != _newPw.text) return 'Şifreler eşleşmiyor';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Kaydet
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _changePassword,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Şifreyi Güncelle',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bildirimler Sayfası ─────────────────────────────

class _NotificationsPage extends ConsumerWidget {
  const _NotificationsPage();

  void _toggle(
    WidgetRef ref,
    Map<String, bool> current,
    String key,
    bool value,
  ) {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    final updated = {...current, key: value};

    // Anında UI güncelle (optimistic update)
    ref.read(notificationSettingsProvider.notifier).state = updated;

    // Supabase'e kaydet
    ref.read(authRepositoryProvider).updateNotificationPreferences(
          userId: userId,
          preferences: updated,
        );
    // Profil cache'ini güncelle ki diğer ekranlar güncel tercihleri görsün
    ref.invalidate(currentProfileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil bulunamadı'));
          }

          final backendPrefs = profile.notificationPreferences;
          final localOverrides = ref.watch(notificationSettingsProvider);

          bool resolve(String key, bool fallback) {
            // Önce local override (kullanıcının bu oturumda yaptığı değişiklik)
            if (localOverrides.containsKey(key)) {
              return localOverrides[key] ?? fallback;
            }
            // Sonra Supabase'den gelen değer
            final backendValue = backendPrefs[key];
            if (backendValue is bool) return backendValue;
            // Hiçbiri yoksa varsayılan
            return fallback;
          }

          final prefs = <String, bool>{
            'newChapter': resolve('newChapter', true),
            'comments': resolve('comments', true),
            'bookLike': resolve('bookLike', true),
            'reviews': resolve('reviews', true),
            'promotions': resolve('promotions', false),
            'weeklyDigest': resolve('weeklyDigest', true),
          };

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _SystemNotificationPermissionCard(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hangi bildirimleri almak istediğinizi seçin.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _NotificationTile(
                icon: Icons.menu_book_rounded,
                title: 'Yeni Bölüm',
                subtitle: 'Takip ettiğin kitaplara yeni bölüm eklendiğinde',
                value: prefs['newChapter'] ?? true,
                onChanged: (v) => _toggle(ref, prefs, 'newChapter', v),
              ),
              _NotificationTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Yorumlar',
                subtitle: 'Kitaplarına yorum yapıldığında',
                value: prefs['comments'] ?? true,
                onChanged: (v) => _toggle(ref, prefs, 'comments', v),
              ),
              _NotificationTile(
                icon: Icons.favorite_rounded,
                title: 'Beğeniler',
                subtitle: 'Kitapların beğenildiğinde',
                value: prefs['bookLike'] ?? true,
                onChanged: (v) => _toggle(ref, prefs, 'bookLike', v),
              ),
              _NotificationTile(
                icon: Icons.star_rounded,
                title: 'Değerlendirmeler',
                subtitle: 'Kitaplarına puan veya inceleme eklendiğinde',
                value: prefs['reviews'] ?? true,
                onChanged: (v) => _toggle(ref, prefs, 'reviews', v),
              ),
              _NotificationTile(
                icon: Icons.local_offer_outlined,
                title: 'Promosyonlar',
                subtitle: 'Kampanya ve indirimlerden haberdar ol',
                value: prefs['promotions'] ?? false,
                onChanged: (v) => _toggle(ref, prefs, 'promotions', v),
              ),
              _NotificationTile(
                icon: Icons.summarize_outlined,
                title: 'Haftalık Özet',
                subtitle: 'Her hafta okuma özetini al',
                value: prefs['weeklyDigest'] ?? true,
                onChanged: (v) => _toggle(ref, prefs, 'weeklyDigest', v),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sistem (cihaz) bildirim izni kartı: durum + izin ver / ayarlara git.
class _SystemNotificationPermissionCard extends ConsumerWidget {
  const _SystemNotificationPermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(notificationPermissionStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return statusAsync.when(
      loading: () => _permissionCard(
        context,
        isDark: isDark,
        icon: Icons.notifications_outlined,
        iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        title: 'Bildirim izni kontrol ediliyor...',
        body: null,
        actions: const [],
      ),
      error: (_, __) => _permissionCard(
        context,
        isDark: isDark,
        icon: Icons.notifications_off_outlined,
        iconColor: AppColors.warning,
        title: 'Bildirim izni bilinemedi',
        body: 'Cihaz ayarlarından bildirimlere izin verebilirsiniz.',
        actions: [
          _PermissionButton(
            label: 'Ayarlara git',
            onPressed: () async {
              await NotificationPermissionService.openSettings();
              ref.invalidate(notificationPermissionStatusProvider);
            },
          ),
        ],
      ),
      data: (status) {
        if (status.isGranted) {
          return _permissionCard(
            context,
            isDark: isDark,
            icon: Icons.notifications_active_rounded,
            iconColor: AppColors.success,
            title: 'Bildirimler açık',
            body: 'Bu cihazda bildirim alacaksınız.',
            actions: const [],
          );
        }
        final isPermanentlyDenied = status.isPermanentlyDenied;
        return _permissionCard(
          context,
          isDark: isDark,
          icon: Icons.notifications_off_rounded,
          iconColor: isPermanentlyDenied ? AppColors.warning : AppColors.primary,
          title: isPermanentlyDenied
              ? 'Bildirimler kapalı'
              : 'Bildirimlere izin verin',
          body: isPermanentlyDenied
              ? 'Bildirim almak için uygulama ayarlarından izin açın.'
              : 'Yeni bölüm, beğeni ve yorum gibi bildirimleri almak için izin verin.',
          actions: [
            if (isPermanentlyDenied)
              _PermissionButton(
                label: 'Ayarlara git',
                onPressed: () async {
                  await NotificationPermissionService.openSettings();
                  ref.invalidate(notificationPermissionStatusProvider);
                },
              )
            else
              _PermissionButton(
                label: 'İzin ver',
                onPressed: () async {
                  await NotificationPermissionService.request();
                  ref.invalidate(notificationPermissionStatusProvider);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _permissionCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? body,
    required List<Widget> actions,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionButton extends StatelessWidget {
  const _PermissionButton({
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.settings_rounded, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Dil Sayfası ─────────────────────────────────────

class _LanguagePage extends StatefulWidget {
  const _LanguagePage();

  @override
  State<_LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<_LanguagePage> {
  static const _languages = [
    {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
  ];

  String _selected = 'tr';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dil Seçimi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: () {
                final langName = _languages
                    .firstWhere((l) => l['code'] == _selected)['name'];
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dil ayarlandı: $langName'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Uygula'),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = lang['code'] == _selected;

          return InkWell(
            onTap: () => setState(() => _selected = lang['code']!),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(lang['flag']!,
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      lang['name']!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Font Boyutu Sayfası ─────────────────────────────

class _FontSizePage extends ConsumerWidget {
  const _FontSizePage();

  static const _options = ['Küçük', 'Orta', 'Büyük', 'Çok Büyük'];

  static double _value(String label) {
    switch (label) {
      case 'Küçük':
        return 13;
      case 'Orta':
        return 16;
      case 'Büyük':
        return 19;
      case 'Çok Büyük':
        return 22;
      default:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(fontSizeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Font Boyutu')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Önizleme
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.text_fields_rounded,
                    color: AppColors.primary, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Vellum ile keşfetmenin tadını çıkarın.',
                  style: TextStyle(fontSize: _value(current), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Seçilen: $current',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ..._options.map((option) {
            final isSelected = option == current;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () =>
                    ref.read(fontSizeProvider.notifier).state = option,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Aa',
                        style: TextStyle(
                          fontSize: _value(option),
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected ? AppColors.primary : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Yardım & SSS Sayfası ───────────────────────────

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  static const _faqItems = [
    {
      'q': 'Vellum nedir?',
      'a':
          'Vellum, yazarların bölüm bazlı içerik yayınladığı ve okuyucuların ücretsiz keşfettiği dijital bir kitap platformudur.',
    },
    {
      'q': 'Nasıl yazar olurum?',
      'a':
          'Vellum Pro aboneliğine geçerek yazarlık özelliklerini aktifleştirebilirsiniz. Abonelik sekmesinden planları inceleyebilirsiniz.',
    },
    {
      'q': 'Abonelik nasıl çalışır?',
      'a':
          'Aylık veya yıllık plan seçerek abone olabilirsiniz. Abonelik süresince sınırsız kitap oluşturma ve yayınlama hakkına sahip olursunuz.',
    },
    {
      'q': 'Aboneliğimi nasıl iptal ederim?',
      'a':
          'Abonelik sekmesinden veya uygulama mağazanızın abonelik yönetimi bölümünden aboneliğinizi iptal edebilirsiniz.',
    },
    {
      'q': 'Hesabımı nasıl silerim?',
      'a':
          'Ayarlar → Güvenlik bölümünden destek ekibimizle iletişime geçerek hesap silme talebi oluşturabilirsiniz.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Yardım & SSS')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sıkça sorulan sorular ve cevapları',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_faqItems.length, (index) {
            final item = _faqItems[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  radius: 18,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  item['q']!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    item['a']!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Yasal Metin Sayfası ─────────────────────────────

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// ORTAK WİDGET'LAR
// ═════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.isDark,
    required this.onEdit,
  });

  final String username;
  final String email;
  final String? avatarUrl;
  final bool isDark;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          username.isNotEmpty
                              ? username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        username.isNotEmpty
                            ? username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items, required this.isDark});
  final List<_SettingsTile> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron && onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── İçerik Metinleri ────────────────────────────────

const _termsText = '''
Vellum Kullanım Şartları

Son Güncelleme: 15 Şubat 2026

1. Genel Hükümler
Vellum uygulamasını kullanarak aşağıdaki şartları kabul etmiş sayılırsınız. Uygulama, dijital içerik yayınlama ve tüketim platformu olarak hizmet vermektedir.

2. Kullanıcı Hesapları
• Hesap oluşturmak için 18 yaşını doldurmuş olmanız gerekmektedir.
• Hesap bilgilerinizin güvenliğinden siz sorumlusunuz.
• Her kullanıcı yalnızca bir hesap açabilir.

3. İçerik Politikası
• Yayınlanan içerikler telif haklarına uygun olmalıdır.
• Yasadışı, müstehcen veya nefret söylemi içeren içerikler yasaktır.
• Platform, uygunsuz içerikleri kaldırma hakkını saklı tutar.

4. Abonelik ve Ödeme
• Vellum Pro aboneliği aylık veya yıllık olarak satın alınabilir.
• Abonelik iptali dönem sonunda geçerli olur.
• Ödeme işlemleri güvenli ödeme sağlayıcıları üzerinden gerçekleştirilir.

5. Fikri Mülkiyet
• Yazarlar, yayınladıkları içeriklerin telif haklarına sahiptir.
• Platform, içeriklerin tanıtımı için sınırlı kullanım hakkına sahiptir.

6. Sorumluluk Sınırları
• Platform, kullanıcılar arası anlaşmazlıklardan sorumlu değildir.
• Teknik arızalardan kaynaklanan veri kayıpları için sorumluluk kabul edilmez.

7. İletişim
Sorularınız için destek@vellum.app adresine yazabilirsiniz.
''';

const _privacyText = '''
Vellum Gizlilik Politikası

Son Güncelleme: 15 Şubat 2026

1. Toplanan Veriler
• Kimlik bilgileri: E-posta, kullanıcı adı
• Kullanım verileri: Okuma geçmişi, tercihler
• Abonelik bilgileri: Plan türü, dönem bilgisi (kart bilgileri saklanmaz)

2. Veri Kullanımı
Toplanan veriler aşağıdaki amaçlarla kullanılır:
• Hesap yönetimi ve kimlik doğrulama
• İçerik önerileri ve kişiselleştirme
• Abonelik işlemlerinin yürütülmesi
• Platform güvenliğinin sağlanması

3. Veri Paylaşımı
• Verileriniz üçüncü taraflarla pazarlama amacıyla paylaşılmaz.
• Yasal zorunluluk halinde yetkili makamlarla paylaşılabilir.
• Ödeme işlemleri için güvenli ödeme sağlayıcıları kullanılır.

4. Çerezler
• Oturum yönetimi için gerekli çerezler kullanılır.
• Analitik çerezler, deneyiminizi iyileştirmek için kullanılır.

5. Veri Güvenliği
• Tüm veriler şifrelenerek saklanır.
• Düzenli güvenlik denetimleri yapılır.
• SSL/TLS protokolü ile iletişim güvenliği sağlanır.

6. Kullanıcı Hakları
• Verilerinize erişim talep edebilirsiniz.
• Verilerinizin silinmesini isteyebilirsiniz.
• Veri taşınabilirliği hakkınız bulunmaktadır.

7. İletişim
Gizlilik ile ilgili sorularınız için gizlilik@vellum.app adresine yazabilirsiniz.
''';

// ─── Geliştirici: Kitap şikayetleri sayfası ─────────

class _DeveloperReportsPage extends ConsumerWidget {
  const _DeveloperReportsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(bookReportsListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitap şikayetleri'),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Yüklenemedi: $err', textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz şikayet yok',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportCard(
                report: report,
                isDark: isDark,
                currentUserId: currentUserId ?? '',
                onMarkRead: () async {
                  await ref.read(bookReportRepositoryProvider).markAsRead(
                        reportId: report.id,
                        readByUserId: currentUserId!,
                        reporterUserId: report.reporterUserId,
                      );
                  ref.invalidate(bookReportsListProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.isDark,
    required this.currentUserId,
    required this.onMarkRead,
  });

  final BookReport report;
  final bool isDark;
  final String currentUserId;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: report.isRead
              ? (isDark ? Colors.white12 : Colors.black12)
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kitap ID: ${report.bookId}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!report.isRead)
                  FilledButton.tonal(
                    onPressed: onMarkRead,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Okundu'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'İncelendi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Şikayetçi: ${report.reporterUserId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              report.message,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(report.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
