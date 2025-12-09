// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../widgets/loading_animation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/theme_provider.dart';
import '../providers/news_provider.dart';
import '../services/financial_data_service.dart';
import '../models/article.dart';
import '../widgets/category_selector.dart';
import 'news_detail_screen.dart';
import 'profile_screen.dart';
import '../auth/login_screen.dart';
import 'quiz_screen.dart';
import 'mp_ranking_screen.dart';
import 'party_rankings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  late final List<String> _categories;
  
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
      "kultur",
    ];
    _tabController = TabController(length: _categories.length, vsync: this);
    
    // Listen to tab changes and fetch news for the selected category
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final category = _categories[_tabController.index];
        Provider.of<NewsProvider>(context, listen: false).fetchNews(category);
      }
    });
    
    // Fetch initial news and financial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NewsProvider>(context, listen: false).fetchNews('gundem');
      _fetchFinancialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _refreshData() async {
    final newsProvider = Provider.of<NewsProvider>(context, listen: false);
    final currentCategory = newsProvider.currentCategory;
    await Future.wait([
      newsProvider.fetchNews(currentCategory),
      _fetchFinancialData(),
    ]);
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
      case 'özel dosyalar':
        return 'Özel Dosyalar';  
      case 'kose yazilari':
        return 'kose yazilari';  
      default:
        return categoryName.toUpperCase();
    }
  }

  // removed ticker (show currencies inside Drawer instead)

  Widget _smallCurrencySummary(ThemeData theme, List<dynamic> currencies, String code) {
    try {
      final c = currencies.firstWhere((e) => e.code == code);
      final raw = c.selling;
      double? value;
      try { value = double.parse(raw.replaceAll(',', '.')); } catch (_) { value = null; }
      final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
      final display = value != null ? formatter.format(value) : '₺$raw';
      return Row(
        children: [
          Text('$code:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(display, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
        ],
      );
    } catch (_) {
      return Text(code, style: theme.textTheme.bodySmall);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildSidePanel(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menü',
          ),
        ),
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
          // Milletvekili Sıralaması butonu
          IconButton(
            tooltip: 'Siyasi Performans Sıralaması',
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MpRankingScreen()),
              );
            },
          ),
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
        bottom: TabBar(
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
        child: Container(
          // modern subtle gradient background for the entire screen
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A), // slate-900 like deep tone
                Color(0xFF0B1220).withOpacity(0.9),
                Theme.of(context).colorScheme.surface.withOpacity(0.02),
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
          child: Consumer<NewsProvider>(
            builder: (context, newsProvider, child) {
              return Column(
                children: [
                  Expanded(
                    child: newsProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: _categories.map((String categoryName) {
                              final articles = newsProvider.currentCategory == categoryName 
                                  ? newsProvider.articles 
                                  : [];
                              if (articles.isEmpty && !newsProvider.isLoading) {
                                return const Center(child: Text("Bu kategoride haber bulunamadı."));
                              }
                              
                              return RefreshIndicator(
                                onRefresh: () => newsProvider.fetchNews(categoryName),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: articles.length,
                                  itemBuilder: (context, index) {
                                    final article = articles[index];
                                    final formattedDate = _formatDate(article.pubDate);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.45),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
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
                                                        color: Theme.of(context).colorScheme.surface.withOpacity(0.04),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        article.sourceName ?? 'Bilinmeyen',
                                                        style: TextStyle(
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurface,
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
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontSize: 14,
                                                      height: 1.4,
                                                    ),
                                                    maxLines: 3,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                
                                                const SizedBox(height: 8),
                                                // Haber görseli (eğer varsa)
                                                if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      height: 160,
                                                      child: CachedNetworkImage(
                                                        imageUrl: article.imageUrl!,
                                                        fit: BoxFit.cover,
                                                        placeholder: (context, url) => Container(
                                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                          child: const Center(child: CircularProgressIndicator()),
                                                        ),
                                                        errorWidget: (context, url, error) => Container(
                                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                          child: Center(
                                                            child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    width: double.infinity,
                                                    height: 160,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      size: 48,
                                                    ),
                                                  ),

                                          const SizedBox(height: 12),
                                          
                                          // Tarih ve Analiz Butonu
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                              if (formattedDate.isNotEmpty)
                                                Text(
                                                  formattedDate,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant, 
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
              );
            },
          ),
        ),
      ),
    );
  }

  // Drawer / Side panel that opens from left
  Widget _buildSidePanel(BuildContext context) {
    final theme = Theme.of(context);
    final currencyWidgets = <Widget>[];
    if (_isFinancialDataLoading) {
      currencyWidgets.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
  child: Center(child: LoadingAnimation(width: 48, height: 48)),
      ));
    } else if (_financialData == null) {
      currencyWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Finansal veriler alınamadı', style: theme.textTheme.bodySmall),
      ));
    } else {
      for (var c in _financialData!.currencies) {
        currencyWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      child: Text(c.code.substring(0, c.code.length > 2 ? 2 : c.code.length), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    // make sure long names don't push the price out
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.code, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                          Text(c.name, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
                child: Builder(builder: (_) {
                  final raw = c.selling;
                  double? value;
                  try {
                    value = double.parse(raw.replaceAll(',', '.'));
                  } catch (_) {
                    value = null;
                  }
                  final display = value != null ? '₺${value.toStringAsFixed(3)}' : '₺$raw';
                  return Text(
                    display,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                }),
              ),
            ],
          ),
        ));
      }
      // BTC (USDT) display
      if (_financialData!.btcUsdtPrice != null) {
        currencyWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      child: Text('BTC', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BTC/USDT', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                          Text('Kripto', style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
                child: Text(
                  _financialData!.btcUsdtPrice!.toStringAsFixed(2),
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ));
      }

      // Gram altın gösterimi
      if (_financialData!.goldGramPrice != null) {
        currencyWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.secondary.withOpacity(0.12),
                      child: Text('₺', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gram Altın', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                          Text('Altın', style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
                child: Text(
                  '₺${_financialData!.goldGramPrice!.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ));
      }
    }

    // categories list

    return Drawer(
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Giriş Yap header (tappable)
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.login, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Giriş Yap', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Hesabına giriş yap veya kayıt ol', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quiz link
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.quiz, color: theme.colorScheme.primary),
                title: Text('İnteraktif Quizler', style: theme.textTheme.titleMedium),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen()));
                },
              ),

              // Parti Bazlı Sıralama link
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.groups, color: theme.colorScheme.secondary),
                title: Text('Parti Performansı', style: theme.textTheme.titleMedium),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PartyRankingsScreen()));
                },
              ),


              // Currencies (ExpansionTile: title shows USD & EUR; expand to show all)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  collapsedBackgroundColor: Colors.transparent,
                  collapsedIconColor: theme.colorScheme.onSurfaceVariant,
                  iconColor: theme.colorScheme.onSurface,
                  title: Row(
                    children: [
                      if (_financialData != null && _financialData!.currencies.isNotEmpty) ...[
                        _smallCurrencySummary(theme, _financialData!.currencies, 'USD'),
                        const SizedBox(width: 12),
                        _smallCurrencySummary(theme, _financialData!.currencies, 'EUR'),
                      ] else ...[
                        Text('Kurlar', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ]
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                      child: Column(
                        children: currencyWidgets,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Categories list (Haber Başlıkları)
              Text('Haber Başlıkları', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final display = _getCategoryDisplayName(cat);
                    final newsProvider = Provider.of<NewsProvider>(context, listen: false);
                    final count = newsProvider.currentCategory == cat ? newsProvider.articles.length : 0;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        // switch to the corresponding tab
                        try { _tabController.animateTo(index); } catch (_) {}
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Text(display, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Text('$count', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
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