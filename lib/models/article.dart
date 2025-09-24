// lib/models/article.dart

import 'package:webfeed_plus/webfeed_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ArticleCategory {
  ekonomi,
  teknoloji,
  spor,
  saglik,
  egitim,
  politika,
  dunya,
  kultur,
  diger
}

class Article {
  final String? id;
  final String? title;
  final String? description;
  final String? link;
  final String? sourceName;
  final DateTime? pubDate;
  final String? category;
  final String? imageUrl;
  final String? analysisResult;
  final DateTime? savedAt;
  final String? userId;

  Article({
    this.id,
    this.title,
    this.description,
    this.link,
    this.sourceName,
    this.pubDate,
    this.category,
    this.imageUrl,
    this.analysisResult,
    this.savedAt,
    this.userId,
  });

  factory Article.fromRssItem(RssItem item, String sourceName, {String? category}) {
    return Article(
      title: item.title,
      description: item.description,
      link: item.link,
      pubDate: item.pubDate,
      sourceName: sourceName,
      category: category,
    );
  }

  factory Article.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Article(
      id: doc.id,
      title: data['title'],
      description: data['description'],
      link: data['link'],
      sourceName: data['sourceName'],
      pubDate: data['pubDate']?.toDate(),
      category: data['category'],
      imageUrl: data['imageUrl'],
      analysisResult: data['analysisResult'],
      savedAt: data['savedAt']?.toDate(),
      userId: data['userId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'link': link,
      'sourceName': sourceName,
      'pubDate': pubDate,
      'category': category,
      'imageUrl': imageUrl,
      'analysisResult': analysisResult,
      'savedAt': savedAt ?? DateTime.now(),
      'userId': userId,
    };
  }

  Article copyWith({
    String? id,
    String? title,
    String? description,
    String? link,
    String? sourceName,
    DateTime? pubDate,
    String? category,
    String? imageUrl,
    String? analysisResult,
    DateTime? savedAt,
    String? userId,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      link: link ?? this.link,
      sourceName: sourceName ?? this.sourceName,
      pubDate: pubDate ?? this.pubDate,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      analysisResult: analysisResult ?? this.analysisResult,
      savedAt: savedAt ?? this.savedAt,
      userId: userId ?? this.userId,
    );
  }
}