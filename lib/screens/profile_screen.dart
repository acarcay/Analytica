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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  // Mevcut kullanıcıyı almak için
  final User? user = FirebaseAuth.instance.currentUser;
  final SavedArticlesService _savedArticlesService = SavedArticlesService();
  late TabController _tabController;
  
  List<Article> _savedArticles = [];
  Map<String, int> _categoryStats = {};
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
    setState(() {
      _isLoading = true;
    });

    try {
      final articles = await _savedArticlesService.getSavedArticles();
      final stats = await _savedArticlesService.getCategoryStats();
      
      setState(() {
        _savedArticles = articles;
        _categoryStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeArticle(Article article) async {
    if (article.id != null) {
      final success = await _savedArticlesService.removeArticle(article.id!);
      if (success) {
        await _loadSavedArticles(); // Listeyi yenile
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Haber kaydedilenlerden çıkarıldı!'),
              backgroundColor: Colors.green,
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
      if (mounted && url != null) {
        setState(() {});
      }
    }
  }

  Future<void> _setPredefinedAvatar(String assetUrl) async {
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(assetUrl);
    if (mounted) setState(() {});
  }

  // Çıkış yapma fonksiyonu
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Çıkış yaptıktan sonra LoginScreen'e yönlendir ve geçmişi temizle
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Çıkış yaparken bir hata oluştu: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Profilim'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profil', icon: Icon(Icons.person)),
            Tab(text: 'Kaydedilenler', icon: Icon(Icons.bookmark)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tema Değiştir',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny_rounded
                  : Icons.nightlight_round,
            ),
            onPressed: () {
              final provider = context.read<ThemeProvider>();
              final isDark = Theme.of(context).brightness == Brightness.dark;
              provider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Kullanıcı bilgileri alınamadı. Lütfen tekrar giriş yapın."))
          : TabBarView(
              controller: _tabController,
              children: [
                // Profil Tab
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: user!.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : (_localPhotoPath != null ? FileImage(File(_localPhotoPath!)) as ImageProvider : null),
                          child: (user!.photoURL == null && _localPhotoPath == null)
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickAvatarFromGallery,
                              icon: const Icon(Icons.photo),
                              label: const Text('Galeriden Yükle'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _setPredefinedAvatar('https://i.pravatar.cc/150?img=3'),
                              icon: const Icon(Icons.account_circle),
                              label: const Text('Avatar 1'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _setPredefinedAvatar('https://i.pravatar.cc/150?img=5'),
                              icon: const Icon(Icons.account_circle),
                              label: const Text('Avatar 2'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // ANA KONTROL BURADA
                        if (user!.isAnonymous) ...[
                          const Text(
                            'Misafir Kullanıcı',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Uygulamayı misafir olarak kullanıyorsunuz.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Kullanıcı ID: ${user!.uid}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          // Normal kullanıcı ise bilgilerini göster
                          Text(
                            user!.displayName ?? 'İsim Belirtilmemiş',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user!.email ?? 'E-posta bulunamadı.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                          ),
                        ],

                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: Text(user!.isAnonymous ? 'Giriş Yap / Kayıt Ol' : 'Çıkış Yap'),
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Kaydedilenler Tab
                _buildSavedArticlesTab(),
              ],
            ),
    );
  }

  Widget _buildSavedArticlesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedArticles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz kaydedilmiş haber yok',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Haberleri analiz ettikten sonra kaydedebilirsiniz',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // İstatistikler
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İstatistikler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Toplam Kaydedilen: ${_savedArticles.length}'),
              const SizedBox(height: 8),
              if (_categoryStats.isNotEmpty) ...[
                const Text('Kategorilere Göre:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _categoryStats.entries.map((entry) {
                    return Chip(
                      label: Text('${getCategoryDisplayName(entry.key)}: ${entry.value}'),
                      avatar: Icon(getCategoryIcon(entry.key), size: 16),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        
        // Kaydedilen haberler listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _savedArticles.length,
            itemBuilder: (context, index) {
              final article = _savedArticles[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(getCategoryIcon(article.category ?? 'diger')),
                  title: Text(
                    article.title ?? 'Başlık yok',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (article.category != null)
                        Text(
                          getCategoryDisplayName(article.category!),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (article.sourceName != null)
                        Text(article.sourceName!),
                      if (article.savedAt != null)
                        Text(
                          'Kaydedildi: ${_formatDate(article.savedAt!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('Görüntüle'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Çıkar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'view') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewsDetailScreen(rssArticle: article),
                          ),
                        );
                      } else if (value == 'remove') {
                        _removeArticle(article);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsDetailScreen(rssArticle: article),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Bugün';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}