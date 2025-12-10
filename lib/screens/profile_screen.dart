import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';

import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/saved_articles_service.dart';
import '../models/article.dart';
import '../widgets/category_selector.dart';
import 'news_detail_screen.dart';
import '../widgets/loading_animation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final SavedArticlesService _savedArticlesService = SavedArticlesService();
  late TabController _tabController;
  
  List<Article> _savedArticles = [];

  bool _isLoading = false;
  final AuthService _authService = AuthService();
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedArticles() async {
    setState(() { _isLoading = true; });

    try {
      final articles = await _savedArticlesService.getSavedArticles();
      setState(() {
        _savedArticles = articles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _removeArticle(Article article) async {
    if (article.id != null) {
      final success = await _savedArticlesService.removeArticle(article.id!);
      if (success) {
        await _loadSavedArticles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Haber silindi'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() { _localPhotoPath = file.path; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final url = await _authService.uploadProfilePhoto(uid, file);
      if (!mounted) return;
      if (url != null) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı güncellendi'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Oturum açılmadı")));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.surface,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.05),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60), // Status bar padding
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage: user!.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : (_localPhotoPath != null ? FileImage(File(_localPhotoPath!)) as ImageProvider : null),
                              child: (user!.photoURL == null && _localPhotoPath == null)
                                  ? Icon(Icons.person, size: 50, color: colorScheme.onPrimaryContainer)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: colorScheme.primary,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                onTap: _pickAvatarFromGallery,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(Icons.camera_alt, size: 16, color: colorScheme.onPrimary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Name & Email
                      Text(
                        user!.displayName ?? (user!.isAnonymous ? 'Misafir Kullanıcı' : 'İsimsiz'),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user!.email ?? 'Anonim Hesap',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Hesap"),
                  Tab(text: "Kaydedilenler"),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Çıkış Yap',
                  onPressed: _signOut,
                ),
              ],
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: HESAP AYARLARI
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'Görünüm'),
                  const SizedBox(height: 10),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildSettingsTile(
                        context,
                        icon: Theme.of(context).brightness == Brightness.dark 
                            ? Icons.dark_mode 
                            : Icons.light_mode,
                        title: 'Karanlık Mod',
                        trailing: Switch(
                          value: Theme.of(context).brightness == Brightness.dark,
                          onChanged: (value) {
                             final provider = context.read<ThemeProvider>();
                             provider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Uygulama'),
                  const SizedBox(height: 10),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildSettingsTile(
                        context,
                        icon: Icons.notifications_outlined,
                        title: 'Bildirimler',
                        showDivider: true,
                        onTap: () {},
                      ),
                      _buildSettingsTile(
                        context,
                        icon: Icons.language,
                        title: 'Dil / Language',
                        subtitle: 'Türkçe',
                        showDivider: true,
                         onTap: () {},
                      ),
                      _buildSettingsTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        title: 'Gizlilik Politikası',
                         onTap: () {},
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  if (user!.isAnonymous)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: colorScheme.onSecondaryContainer),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Hesabınızı kaybetmemek için kayıt olun.",
                              style: TextStyle(color: colorScheme.onSecondaryContainer),
                            ),
                          ),
                          TextButton(
                            onPressed: _signOut, // Login ekranına atar
                            child: const Text("Kayıt Ol"),
                          )
                        ],
                      ),
                    ),
                    
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      "v1.0.0",
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // TAB 2: KAYDEDİLENLER
            _isLoading 
              ? Center(child: LoadingAnimation(width: 50, height: 50))
              : _savedArticles.isEmpty 
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _savedArticles.length,
                      itemBuilder: (context, index) {
                        return _buildArticleCard(context, _savedArticles[index]);
                      },
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showDivider = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: trailing ?? const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        if (showDivider)
          Divider(
            height: 1, 
            indent: 56, 
            endIndent: 16, 
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_outline, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            "Henüz Haber Kaydetmediniz",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Beğendiğiniz haberleri burada bulabilirsiniz.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
               color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, Article article) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewsDetailScreen(rssArticle: article),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Kategori Ikonu
              Container(
                 width: 48,
                 height: 48,
                 decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.tertiaryContainer,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Icon(
                   getCategoryIcon(article.category ?? 'diger'),
                   color: Theme.of(context).colorScheme.onTertiaryContainer,
                 ),
              ),
              const SizedBox(width: 16),
              // Icerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title ?? 'Başlık Yok',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                         Text(
                           article.sourceName ?? 'Bilinmeyen',
                           style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                         ),
                         const SizedBox(width: 8),
                         Icon(Icons.circle, size: 4, color: Theme.of(context).colorScheme.outline),
                         const SizedBox(width: 8),
                         Text(
                           article.category != null ? getCategoryDisplayName(article.category!) : '',
                           style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                         ),
                      ],
                    ),
                  ],
                ),
              ),
              // Silme Butonu
              IconButton(
                icon: const Icon(Icons.bookmark_remove_outlined),
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _removeArticle(article),
              ),
            ],
          ),
        ),
      ),
    );
  }
}