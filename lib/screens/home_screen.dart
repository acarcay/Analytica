// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

import '../services/financial_data_service.dart';
import '../models/article.dart';
import '../widgets/category_selector.dart';
import 'news_detail_screen.dart';
import 'profile_screen.dart';

// FeedSource sınıfı
class FeedSource {
  final String category;
  final String url;
  FeedSource({required this.category, required this.url});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<FeedSource> _allFeeds = [
    // Gündem Kategorisi - Çalışan RSS'ler
    FeedSource(category: "gundem", url: "https://www.haberturk.com/rss/gundem.xml"),
    FeedSource(category: "gundem", url: "https://www.cumhuriyet.com.tr/rss/1.xml"),
    FeedSource(category: "gundem", url: "https://www.aa.com.tr/tr/rss/default?cat=guncel"),
    FeedSource(category: "gundem", url: "https://www.trthaber.com/rss/gundem.rss"),
    
    // Ekonomi Kategorisi - Çalışan RSS'ler
    FeedSource(category: "ekonomi", url: "https://www.haberturk.com/rss/ekonomi.xml"),
    FeedSource(category: "ekonomi", url: "https://www.aa.com.tr/tr/rss/default?cat=ekonomi"),
    FeedSource(category: "ekonomi", url: "https://www.cumhuriyet.com.tr/rss/2.xml"),
    FeedSource(category: "ekonomi", url: "https://www.trthaber.com/rss/ekonomi.rss"),

    // Teknoloji Kategorisi - Çalışan RSS'ler
    FeedSource(category: "teknoloji", url: "https://www.webtekno.com/rss.xml"),
    FeedSource(category: "teknoloji", url: "https://www.haberturk.com/rss/teknoloji.xml"),
    
    // Spor Kategorisi - Çalışan RSS'ler
    FeedSource(category: "spor", url: "https://www.haberturk.com/rss/spor.xml"),
    FeedSource(category: "spor", url: "https://www.trthaber.com/rss/spor.rss"),
    FeedSource(category: "spor", url: "https://www.cumhuriyet.com.tr/rss/4.xml"),
    FeedSource(category: "spor", url: "https://www.aa.com.tr/tr/rss/default?cat=spor"),
    
    // Politika Kategorisi - Çalışan RSS'ler
    FeedSource(category: "politika", url: "https://www.cumhuriyet.com.tr/rss/3.xml"),
    FeedSource(category: "politika", url: "https://www.trthaber.com/rss/politika.rss"),
    FeedSource(category: "politika", url: "https://www.aa.com.tr/tr/rss/default?cat=politika"),
    
    // Sağlık Kategorisi - Çalışan RSS'ler
    FeedSource(category: "saglik", url: "https://www.trthaber.com/rss/saglik.rss"),
    
    // Eğitim Kategorisi - Çalışan RSS'ler
    FeedSource(category: "egitim", url: "https://www.haberturk.com/rss/egitim.xml"),
    
    // Dünya Kategorisi - Çalışan RSS'ler
    FeedSource(category: "dunya", url: "https://www.haberturk.com/rss/dunya.xml"),
    FeedSource(category: "dunya", url: "https://www.trthaber.com/rss/dunya.rss"),
    FeedSource(category: "dunya", url: "https://www.aa.com.tr/tr/rss/default?cat=dunya"),
    
    // Kültür Kategorisi - Çalışan RSS'ler
    FeedSource(category: "kultur", url: "https://www.haberturk.com/rss/kultur-sanat.xml"),
  ];

  late final List<String> _categories;
  List<Article> _allArticles = [];
  bool _isLoading = true;
  
  FinancialData? _financialData;
  bool _isFinancialDataLoading = true;

  @override
  void initState() {
    super.initState();
    // Kategorileri düzenli sırada oluştur
    _categories = [
      "gundem",
      "ekonomi", 
      "politika",
      "teknoloji",
      "spor",
      "saglik",
      "egitim",
      "dunya",
      "kultur"
    ];
    _tabController = TabController(length: _categories.length, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _refreshData() async {
    await Future.wait([
      _fetchAllNews(),
      _fetchFinancialData(),
    ]);
  }

  Future<void> _fetchAllNews() async {
     List<Article> fetchedArticles = [];
     Set<String> seenArticles = {}; // Duplicate kontrolü için
     Map<String, int> categoryCounts = {}; // Kategori sayacı
    
    await Future.wait(_allFeeds.map((feedSource) async {
      try {
        final response = await http.get(
          Uri.parse(feedSource.url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes);
          
          // XML içeriğini temizle
          final cleanBody = _cleanXmlContent(decodedBody);
          
          final feed = RssFeed.parse(cleanBody);
          final sourceName = _extractSourceName(feed.title ?? feedSource.url);
          
          if (feed.items != null && feed.items!.isNotEmpty) {
            for (var item in feed.items!) {
              // Haber içeriğini analiz et ve kategori doğrula
              final actualCategory = _determineCategory(item, feedSource.category);
              
              final article = Article.fromRssItem(item, sourceName, category: actualCategory);
              
              // Duplicate kontrolü - başlık ve link kombinasyonu
              final articleKey = '${article.title?.toLowerCase().trim()}_${article.link?.toLowerCase().trim()}';
              
              // Sadece geçerli ve benzersiz haberleri ekle
              if (_isValidArticle(article) && !seenArticles.contains(articleKey)) {
                // Kategori sayısını kontrol et (maksimum 50 haber per kategori)
                final currentCount = categoryCounts[actualCategory] ?? 0;
                if (currentCount < 50) {
                  seenArticles.add(articleKey);
                  categoryCounts[actualCategory] = currentCount + 1;
                  
                  final titleForPrint = article.title ?? '';
                  final shortTitle = titleForPrint.length > 30 ? titleForPrint.substring(0, 30) : titleForPrint;
                  print('Haber [${actualCategory}]: $shortTitle...');
                  
                  fetchedArticles.add(article);
                }
              }
            }
          }
        } else {
          print("HTTP Hatası: ${response.statusCode} - ${feedSource.url}");
        }
      } catch (e) {
        print("RSS Hatası: ${feedSource.url} - $e");
      }
    }));
    
    // Tarihe göre sırala (en yeni önce)
    fetchedArticles.sort((a, b) => b.pubDate?.compareTo(a.pubDate ?? DateTime(0)) ?? 0);
    
    print('Toplam ${fetchedArticles.length} haber yüklendi');
    print('Kategori dağılımı: $categoryCounts');
    
    if (mounted) {
      setState(() {
        _allArticles = fetchedArticles;
        _isLoading = false;
      });
    }
  }

  // XML içeriğini temizle
  String _cleanXmlContent(String xmlContent) {
    // BOM karakterlerini kaldır
    String cleaned = xmlContent.replaceAll('\uFEFF', '');
    
    // Boş satırları ve fazla boşlukları temizle
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // XML header'ı kontrol et
    if (!cleaned.startsWith('<?xml') && !cleaned.startsWith('<rss') && !cleaned.startsWith('<feed')) {
      // XML header ekle
      cleaned = '<?xml version="1.0" encoding="UTF-8"?>$cleaned';
    }
    
    return cleaned;
  }

  // Kaynak adını çıkar
  String _extractSourceName(String title) {
    if (title.isEmpty) return 'Bilinmeyen';
    
    // Yaygın kaynak adlarını ayıkla
    final commonSources = ['Habertürk', 'Sözcü', 'Cumhuriyet', 'AA', 'TRT Haber', 'Webtekno', 'Chip'];
    
    for (final source in commonSources) {
      if (title.toLowerCase().contains(source.toLowerCase())) {
        return source;
      }
    }
    
    // İlk kelimeyi al
    return title.split(' ').first;
  }

  // Haber kategorisini belirle
  String _determineCategory(RssItem item, String feedCategory) {
    final title = item.title?.toLowerCase() ?? '';
    final description = item.description?.toLowerCase() ?? '';
    final content = '$title $description';
    
    // Spor anahtar kelimeleri
    final sporKeywords = ['futbol', 'basketbol', 'voleybol', 'tenis', 'spor', 'maç', 'gol', 'takım', 'oyuncu', 'şampiyon', 'lig', 'turnuva', 'atletizm', 'yüzme', 'jimnastik'];
    
    // Politika anahtar kelimeleri
    final politikaKeywords = ['seçim', 'milletvekili', 'başkan', 'bakan', 'hükümet', 'meclis', 'siyaset', 'parti', 'politik', 'demokrat', 'cumhuriyet', 'cumhurbaşkanı', 'başbakan'];
    
    // Ekonomi anahtar kelimeleri
    final ekonomiKeywords = ['ekonomi', 'borsa', 'dolar', 'euro', 'enflasyon', 'faiz', 'yatırım', 'kredi', 'bankacılık', 'finans', 'para', 'maliye', 'vergi', 'ihracat', 'ithalat'];
    
    // Teknoloji anahtar kelimeleri
    final teknolojiKeywords = ['teknoloji', 'yapay zeka', 'bilgisayar', 'telefon', 'internet', 'yazılım', 'donanım', 'apple', 'google', 'microsoft', 'android', 'ios', 'uygulama'];
    
    // Sağlık anahtar kelimeleri
    final saglikKeywords = ['sağlık', 'hastane', 'doktor', 'hastalık', 'tedavi', 'ilaç', 'aşı', 'tıp', 'ameliyat', 'kanser', 'kalp', 'beyin', 'psikoloji'];
    
    // Eğitim anahtar kelimeleri
    final egitimKeywords = ['eğitim', 'okul', 'üniversite', 'öğrenci', 'öğretmen', 'ders', 'sınav', 'mezun', 'öğrenim', 'bilim', 'araştırma', 'akademik'];
    
    // Kategori belirleme
    if (sporKeywords.any((keyword) => content.contains(keyword))) {
      return 'spor';
    }
    if (politikaKeywords.any((keyword) => content.contains(keyword))) {
      return 'politika';
    }
    if (ekonomiKeywords.any((keyword) => content.contains(keyword))) {
      return 'ekonomi';
    }
    if (teknolojiKeywords.any((keyword) => content.contains(keyword))) {
      return 'teknoloji';
    }
    if (saglikKeywords.any((keyword) => content.contains(keyword))) {
      return 'saglik';
    }
    if (egitimKeywords.any((keyword) => content.contains(keyword))) {
      return 'egitim';
    }
    
    // Eğer hiçbiri eşleşmezse, feed kategorisini kullan
    return feedCategory;
  }

  // Geçerli haber kontrolü
  bool _isValidArticle(Article article) {
    // Başlık ve açıklama kontrolü
    if (article.title == null || article.title!.trim().isEmpty) return false;
    if (article.description == null || article.description!.trim().isEmpty) return false;
    
    // Minimum uzunluk kontrolü
    if (article.title!.length < 10) return false;
    if (article.description!.length < 20) return false;
    
    // Maksimum uzunluk kontrolü (çok uzun başlıklar spam olabilir)
    if (article.title!.length > 200) return false;
    if (article.description!.length > 1000) return false;
    
    // Spam ve geçersiz içerik kontrolü
    final spamKeywords = [
      'reklam', 'promosyon', 'kampanya', 'indirim', 'satış', 'fırsat',
      'kazan', 'ödül', 'hediye', 'ücretsiz', 'bedava', 'bonus',
      'poker', 'casino', 'bahis', 'lottery', 'şans oyunu'
    ];
    final titleLower = article.title!.toLowerCase();
    final descLower = article.description!.toLowerCase();
    
    // Başlıkta spam kontrolü
    if (spamKeywords.any((keyword) => titleLower.contains(keyword))) return false;
    
    // Açıklamada spam kontrolü
    if (spamKeywords.any((keyword) => descLower.contains(keyword))) return false;
    
    // Tekrarlayan karakter kontrolü
    if (_hasRepeatingCharacters(article.title!)) return false;
    
    // Link kontrolü
    if (article.link == null || article.link!.trim().isEmpty) return false;
    final uri = Uri.tryParse(article.link!);
    if (uri == null || !uri.isAbsolute) return false;
    
    return true;
  }

  // Tekrarlayan karakter kontrolü
  bool _hasRepeatingCharacters(String text) {
    final chars = text.toLowerCase().split('');
    for (int i = 0; i < chars.length - 3; i++) {
      if (chars[i] == chars[i + 1] && 
          chars[i] == chars[i + 2] && 
          chars[i] == chars[i + 3]) {
        return true;
      }
    }
    return false;
  }
  
  Future<void> _fetchFinancialData() async {
    if (!mounted) return;
    setState(() { _isFinancialDataLoading = true; });
    try {
      final data = await FinancialDataService().fetchFinancialData();
      if (mounted) {
        setState(() {
          _financialData = data;
          _isFinancialDataLoading = false;
        });
      }
    } catch (e) {
       if (mounted) {
         setState(() { 
           _financialData = null;
           _isFinancialDataLoading = false; 
          });
       }
    }
  }

  List<Article> _getArticlesForCategory(String category) {
    return _allArticles.where((article) => article.category == category).toList();
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(date);
  }

  String _getCategoryDisplayName(String categoryName) {
    switch (categoryName) {
      case 'gundem':
        return 'Gündem';
      case 'ekonomi':
        return 'Ekonomi';
      case 'politika':
        return 'Politika';
      case 'teknoloji':
        return 'Teknoloji';
      case 'spor':
        return 'Spor';
      case 'saglik':
        return 'Sağlık';
      case 'egitim':
        return 'Eğitim';
      case 'dunya':
        return 'Dünya';
      case 'kultur':
        return 'Kültür';
      default:
        return categoryName.toUpperCase();
    }
  }

  Widget _buildTicker() {
    if (_isFinancialDataLoading) {
      return const SizedBox(height: 40, child: Center(child: LinearProgressIndicator()));
    }
    if (_financialData == null) {
      return Container(
        height: 40,
        color: Theme.of(context).colorScheme.errorContainer,
        child: Center(
          child: Text(
            "Finansal veriler yüklenemedi.",
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
        ),
      );
    }
    
    final items = [
      ..._financialData!.currencies.map((c) => ' ${c.code}: ₺${c.selling} '),
      ' BTC: ₺${NumberFormat("#,##0", "tr_TR").format(_financialData!.btcPrice)} '
    ];

    return _AutoScrollTicker(items: items);
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
        title: Text(
          'Analytica',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
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
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
        ],
        bottom: _isLoading ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: _categories.map((String categoryName) => Tab(
            text: _getCategoryDisplayName(categoryName),
          )).toList(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTicker(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: _categories.map((String categoryName) {
                        final articles = _getArticlesForCategory(categoryName);
                        if (articles.isEmpty && !_isLoading) {
                          return const Center(child: Text("Bu kategoride haber bulunamadı."));
                        }
                        
                        return RefreshIndicator(
                          onRefresh: _refreshData,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: articles.length,
                            itemBuilder: (context, index) {
                              final article = articles[index];
                              final formattedDate = _formatDate(article.pubDate);
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.grey.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => NewsDetailScreen(rssArticle: article)));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Kategori ve Kaynak Bilgisi
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      getCategoryIcon(article.category ?? 'diger'),
                                                      size: 14,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      getCategoryDisplayName(article.category ?? 'diger'),
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  article.sourceName ?? 'Bilinmeyen',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // Haber Başlığı
                                          Text(
                                            article.title ?? 'Başlık bulunamadı',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 16,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          
                                          // Haber Açıklaması
                                          if (article.description != null)
                                            Text(
                                              article.description!,
                                              style: TextStyle(
                                                color: Colors.grey.shade700, 
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          
                                          const SizedBox(height: 12),
                                          
                                          // Tarih ve Analiz Butonu
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              if (formattedDate.isNotEmpty)
                                                Text(
                                                  formattedDate,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500, 
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.analytics_rounded,
                                                      size: 12,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Analiz Et',
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoScrollTicker extends StatefulWidget {
  final List<String> items;
  const _AutoScrollTicker({required this.items});

  @override
  State<_AutoScrollTicker> createState() => _AutoScrollTickerState();
}

class _AutoScrollTickerState extends State<_AutoScrollTicker> with SingleTickerProviderStateMixin {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  Future<void> _start() async {
    // Sürekli sağa doğru akış. Sona gelince başa dön.
    while (mounted) {
      if (!_controller.hasClients) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }
      final max = _controller.position.maxScrollExtent;
      // Eğer kaydırılacak fazla içerik yoksa kısa bekle ve tekrar dene
      if (max < 50) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      try {
        await _controller.animateTo(
          max,
          duration: const Duration(seconds: 30),
          curve: Curves.linear,
        );
        if (!mounted) return;
        _controller.jumpTo(0);
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Akıcılığı artırmak için öğeleri iki kez tekrarla
    final repeated = [...widget.items, ...widget.items];
    return Container(
      height: 40,
      color: colorScheme.secondaryContainer,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, i) {
          final text = repeated[i % repeated.length];
          return Text(
            text,
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 24),
        itemCount: repeated.length,
      ),
    );
  }
}