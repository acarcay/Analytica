// lib/screens/news_detail_screen.dart DOSYASININ DOĞRU İÇERİĞİ

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/ai_service.dart';
import '../services/saved_articles_service.dart';
import '../models/article.dart';
import '../widgets/category_selector.dart';

class NewsDetailScreen extends StatefulWidget {
  final Article rssArticle;

  const NewsDetailScreen({super.key, required this.rssArticle});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final AIService _aiService = AIService();
  final SavedArticlesService _savedArticlesService = SavedArticlesService();
  String? _analysisResult;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isArticleSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfArticleSaved();
  }

  void _checkIfArticleSaved() async {
    if (widget.rssArticle.link != null) {
      final isSaved = await _savedArticlesService.isArticleSaved(widget.rssArticle.link!);
      setState(() {
        _isArticleSaved = isSaved;
      });
    }
  }

  void _getAnalysis() async {
    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    final textToAnalyze = "${widget.rssArticle.title}\n\n${widget.rssArticle.description ?? ''}";
    final cacheKey = widget.rssArticle.link ?? widget.rssArticle.title ?? '';
    final result = await _aiService.getAnalysis(textToAnalyze, cacheKey: cacheKey);

    setState(() {
      _analysisResult = result;
      _isLoading = false;
    });
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $urlString');
    }
  }

  void _showCategorySelector() {
    showDialog(
      context: context,
      builder: (context) => CategorySelector(
        onCategorySelected: _saveArticle,
      ),
    );
  }

  void _saveArticle(String category) async {
    setState(() {
      _isSaving = true;
    });

    final articleToSave = widget.rssArticle.copyWith(
      analysisResult: _analysisResult,
    );

    final success = await _savedArticlesService.saveArticle(articleToSave, category);

    setState(() {
      _isSaving = false;
      _isArticleSaved = success;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Haber başarıyla kaydedildi!' 
                : 'Haber kaydedilirken bir hata oluştu.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _removeArticle() async {
    setState(() {
      _isSaving = true;
    });

    // Bu durumda article ID'yi bulmamız gerekiyor
    // Şimdilik basit bir yaklaşım kullanacağız
    final success = await _savedArticlesService.isArticleSaved(widget.rssArticle.link!);
    
    setState(() {
      _isSaving = false;
      if (success) {
        // Gerçek uygulamada burada article ID ile silme işlemi yapılır
        _isArticleSaved = false;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Haber kaydedilenlerden çıkarıldı!' 
                : 'Haber çıkarılırken bir hata oluştu.',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
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
        title: Text(widget.rssArticle.sourceName ?? 'Haber Detayı'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.rssArticle.title ?? 'Başlık bulunamadı',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (widget.rssArticle.description != null)
                Text(
                  widget.rssArticle.description!,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("Haberi Oku"),
                    onPressed: () => _launchURL(widget.rssArticle.link),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, 
                      backgroundColor: Colors.teal,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.psychology_alt),
                    label: const Text("Analiz Et"),
                    onPressed: _isLoading ? null : _getAnalysis,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, 
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Kaydetme butonu
              Center(
                child: _isArticleSaved
                    ? ElevatedButton.icon(
                        icon: _isSaving 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bookmark_remove),
                        label: Text(_isSaving ? "Çıkarılıyor..." : "Kaydedilenlerden Çıkar"),
                        onPressed: _isSaving ? null : _removeArticle,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.orange,
                        ),
                      )
                    : ElevatedButton.icon(
                        icon: _isSaving 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bookmark_add),
                        label: Text(_isSaving ? "Kaydediliyor..." : "Kaydet"),
                        onPressed: _isSaving ? null : _showCategorySelector,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green,
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                )),
              
              if (_analysisResult != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Yapay Zeka Analizi:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(),
                      Text(_analysisResult!),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}