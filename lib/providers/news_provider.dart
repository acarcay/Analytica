// lib/providers/news_provider.dart

import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/news_service.dart';
import '../utils/logging.dart';

class NewsProvider with ChangeNotifier {
  final NewsService _newsService = NewsService();

  List<Article> _articles = [];
  bool _isLoading = false;
  String _currentCategory = 'general';
  String? _error;

  // Getters
  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String get currentCategory => _currentCategory;
  String? get error => _error;

  /// Fetch news for the given category
  Future<void> fetchNews(String category) async {
    // Don't refetch if already loading or same category
    if (_isLoading && _currentCategory == category) {
      AppLog.d('NewsProvider: Already loading $category, skipping');
      return;
    }

    _isLoading = true;
    _error = null;
    _currentCategory = category;
    notifyListeners();

    try {
      AppLog.d('NewsProvider: Fetching news for category: $category');
      final fetchedArticles = await _newsService.fetchNews(category);
      
      _articles = fetchedArticles;
      _error = null;
      AppLog.d('NewsProvider: Successfully fetched ${fetchedArticles.length} articles');
    } catch (e) {
      _error = 'Haberler yüklenirken bir hata oluştu: $e';
      AppLog.e('NewsProvider: Error fetching news: $e');
      _articles = []; // Clear articles on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear articles and reset state
  void clear() {
    _articles = [];
    _currentCategory = 'general';
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

