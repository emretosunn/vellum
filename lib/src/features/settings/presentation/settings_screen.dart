import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';

// ─── Providers ───────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final notificationSettingsProvider =
    StateProvider<Map<String, bool>>((ref) => {
          'newChapter': true,
          'comments': true,
          'promotions': false,
          'weeklyDigest': true,
        });

final fontSizeProvider = StateProvider<String>((ref) => 'Orta');

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
                isDark: isDark,
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ProfilePage(
                      currentUsername: profile?.username ?? '',
                    ),
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
                      builder: (_) => _ProfilePage(
                        currentUsername:
                            profileAsync.valueOrNull?.username ?? '',
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
                  subtitle: 'v1.0.0',
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

// ─── Profil Sayfası ──────────────────────────────────

class _ProfilePage extends ConsumerStatefulWidget {
  const _ProfilePage({required this.currentUsername});
  final String currentUsername;

  @override
  ConsumerState<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<_ProfilePage> {
  late final TextEditingController _usernameController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil güncellendi ✓'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Bilgileri'),
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
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Kaydet'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar büyük
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  widget.currentUsername.isNotEmpty
                      ? widget.currentUsername[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Kullanıcı adı
            Text('Kullanıcı Adı',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.alternate_email),
                hintText: 'Kullanıcı adınız',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kullanıcı adı boş olamaz';
                }
                if (value.trim().length < 3) return 'En az 3 karakter olmalı';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // E-posta (salt okunur)
            Text('E-posta',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: email,
              enabled: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _toggle(WidgetRef ref, Map<String, dynamic> current, String key, bool value) {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    final updated = {...current, key: value};
    // Yerel state'i güncelle
    ref.read(notificationSettingsProvider.notifier).state =
        updated.map((k, v) => MapEntry(k, v as bool));
    // Supabase'e kaydet
    ref.read(authRepositoryProvider).updateNotificationPreferences(
          userId: userId,
          preferences: updated,
        );
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

          final prefs = profile.notificationPreferences;

          return ListView(
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
                    Icon(Icons.notifications_active_outlined,
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
                  'İnkToken ile keşfetmenin tadını çıkarın.',
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
      'q': 'InkToken nedir?',
      'a':
          'InkToken, yazarların bölüm bazlı içerik yayınladığı ve okuyucuların token ile ödeme yaptığı dijital bir kitap platformudur.',
    },
    {
      'q': 'Nasıl yazar olurum?',
      'a':
          'Dashboard ekranında "Yazar Ol" butonuna tıklayarak yazar profilinizi aktifleştirebilirsiniz.',
    },
    {
      'q': 'Token nasıl satın alırım?',
      'a':
          'Cüzdan sekmesindeki "Token Satın Al" butonuyla kredi kartı veya mobil ödeme ile token satın alabilirsiniz.',
    },
    {
      'q': 'Kazançlarımı nasıl çekerim?',
      'a':
          'Yazar panelinizdeki Cüzdan bölümden en az 50 TL biriktirdiğinizde banka hesabınıza çekim talep edebilirsiniz.',
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
    required this.isDark,
    required this.onEdit,
  });

  final String username;
  final String email;
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
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
InkToken Kullanım Şartları

Son Güncelleme: 15 Şubat 2026

1. Genel Hükümler
InkToken uygulamasını kullanarak aşağıdaki şartları kabul etmiş sayılırsınız. Uygulama, dijital içerik yayınlama ve tüketim platformu olarak hizmet vermektedir.

2. Kullanıcı Hesapları
• Hesap oluşturmak için 18 yaşını doldurmuş olmanız gerekmektedir.
• Hesap bilgilerinizin güvenliğinden siz sorumlusunuz.
• Her kullanıcı yalnızca bir hesap açabilir.

3. İçerik Politikası
• Yayınlanan içerikler telif haklarına uygun olmalıdır.
• Yasadışı, müstehcen veya nefret söylemi içeren içerikler yasaktır.
• Platform, uygunsuz içerikleri kaldırma hakkını saklı tutar.

4. Token ve Ödeme
• Tokenlar uygulama içi satın alımlarla edinilir.
• Satın alınan tokenlar iade edilemez.
• Yazar kazançları, minimum eşik tutarına ulaştığında çekilebilir.

5. Fikri Mülkiyet
• Yazarlar, yayınladıkları içeriklerin telif haklarına sahiptir.
• Platform, içeriklerin tanıtımı için sınırlı kullanım hakkına sahiptir.

6. Sorumluluk Sınırları
• Platform, kullanıcılar arası anlaşmazlıklardan sorumlu değildir.
• Teknik arızalardan kaynaklanan veri kayıpları için sorumluluk kabul edilmez.

7. İletişim
Sorularınız için destek@inktoken.com adresine yazabilirsiniz.
''';

const _privacyText = '''
InkToken Gizlilik Politikası

Son Güncelleme: 15 Şubat 2026

1. Toplanan Veriler
• Kimlik bilgileri: E-posta, kullanıcı adı
• Kullanım verileri: Okuma geçmişi, tercihler
• Ödeme bilgileri: İşlem geçmişi (kart bilgileri saklanmaz)

2. Veri Kullanımı
Toplanan veriler aşağıdaki amaçlarla kullanılır:
• Hesap yönetimi ve kimlik doğrulama
• İçerik önerileri ve kişiselleştirme
• Ödeme işlemlerinin yürütülmesi
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
Gizlilik ile ilgili sorularınız için gizlilik@inktoken.com adresine yazabilirsiniz.
''';
