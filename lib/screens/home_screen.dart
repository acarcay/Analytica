import 'package:flutter/material.dart';
import '../widgets/loading_animation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/news_provider.dart';
import '../services/financial_data_service.dart';
import '../models/article.dart';
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
    _categories = [
      "gundem", "ekonomi", "politika", "teknoloji", "spor",
      "saglik", "egitim", "dunya", "kultur"
    ];
    _tabController = TabController(length: _categories.length, vsync: this);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final category = _categories[_tabController.index];
        Provider.of<NewsProvider>(context, listen: false).fetchNews(category);
      }
    });
    
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
    return DateFormat('dd MMM, HH:mm', 'tr_TR').format(date);
  }

  String _getCategoryDisplayName(String categoryName) {
     const Map<String, String> displayNames = {
      'gundem': 'Gündem',
      'ekonomi': 'Ekonomi',
      'politika': 'Politika',
      'teknoloji': 'Teknoloji',
      'spor': 'Spor',
      'saglik': 'Sağlık',
      'egitim': 'Eğitim',
      'dunya': 'Dünya',
      'kultur': 'Kültür',
    };
    return displayNames[categoryName] ?? categoryName.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      drawer: _buildSidePanel(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: true,
              centerTitle: true,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Analytica',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorColor: colorScheme.primary,
                dividerColor: Colors.transparent,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                tabs: _categories.map((c) => Tab(text: _getCategoryDisplayName(c))).toList(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((category) {
            return Consumer<NewsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.articles.isEmpty) {
                   return Center(child: LoadingAnimation());
                }
                
                final articles = provider.currentCategory == category ? provider.articles : [];
                if (articles.isEmpty) {
                  return const Center(child: Text("Haber bulunamadı."));
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchNews(category),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildModernNewsCard(context, articles[index]);
                    },
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModernNewsCard(BuildContext context, Article article) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(rssArticle: article)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              if (article.imageUrl != null)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: colorScheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => Container(color: colorScheme.surfaceContainerHighest, child: Icon(Icons.image_not_supported, color: colorScheme.onSurfaceVariant)),
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge & Source
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                             _getCategoryDisplayName(article.category ?? 'Genel'),
                             style: TextStyle(
                               fontSize: 11,
                               fontWeight: FontWeight.bold,
                               color: colorScheme.primary,
                             ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          article.sourceName ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      article.title ?? '',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (article.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(article.pubDate),
                          style: TextStyle(fontSize: 12, color: colorScheme.outline),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: colorScheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceRow(BuildContext context, String code, String? price) {
    if (price == null) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          code == 'BTC' ? '\$$price' : '₺$price',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }

  // Helper to extract currency price safely
  String? _getCurrencyPrice(String code) {
    if (_financialData == null) return null;
    try {
      final currency = _financialData!.currencies.firstWhere((c) => c.code == code);
      return currency.selling;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSidePanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
               padding: const EdgeInsets.all(24),
               child: Row(
                 children: [
                   Icon(Icons.analytics, size: 32, color: colorScheme.primary),
                   const SizedBox(width: 12),
                   Text("Analytica", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                 ],
               ),
            ),
            const Divider(),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildDrawerItem(
                    context, 
                    icon: Icons.leaderboard, 
                    title: "Siyasi Sıralama", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MpRankingScreen())),
                  ),
                  _buildDrawerItem(
                    context, 
                    icon: Icons.groups, 
                    title: "Parti Performansı", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartyRankingsScreen())),
                  ),
                  _buildDrawerItem(
                    context, 
                    icon: Icons.quiz, 
                    title: "İnteraktif Quiz", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen())),
                  ),
                  const SizedBox(height: 24),
                  
                  // Financial Data Widget
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Piyasa Verileri", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (_isFinancialDataLoading)
                          Center(child: LoadingAnimation(width: 32, height: 32))
                        else if (_financialData != null) ...[
                          _buildFinanceRow(context, "USD", _getCurrencyPrice("USD")),
                          const SizedBox(height: 8),
                          _buildFinanceRow(context, "EUR", _getCurrencyPrice("EUR")),
                          const SizedBox(height: 8),
                          _buildFinanceRow(context, "ALTIN", _financialData!.goldGramPrice?.toStringAsFixed(0)),
                          const SizedBox(height: 8),
                          _buildFinanceRow(context, "BTC", _financialData!.btcUsdtPrice?.toStringAsFixed(0)),
                        ] else
                          const Text("Veri alınamadı"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {
                   Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text("Çıkış Yap"),
                style: OutlinedButton.styleFrom(
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
     return ListTile(
       leading: Container(
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
           borderRadius: BorderRadius.circular(8),
         ),
         child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
       ),
       title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
       trailing: const Icon(Icons.chevron_right, size: 16),
       onTap: onTap,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
     );
  }
}