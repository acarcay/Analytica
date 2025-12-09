// lib/models/article.dart

import 'package:webfeed_plus/webfeed_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html/parser.dart' as html_parser;

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
    // Bazı RSS kaynakları (ör. ElipsHaber) <description> alanını boş bırakıp
    // içeriği <content:encoded> içinde veriyor. Bu durumda öncelikle
    // description'ı kontrol et, boşsa content alanını kullan.
    String? desc = item.description;
    if (desc == null || desc.trim().isEmpty) {
      // webfeed_plus içinde content alanı farklı şekilde expose edilebilir;
      // genel olarak item.content?.value veya item.content?.encoded denemesi yapılır.
      try {
        // ignore: avoid_dynamic_calls
        final dynamic content = (item as dynamic).content;
        if (content != null) {
          // common fields
          desc = content.value ?? content.encoded ?? content.toString();
        }
      } catch (_) {
        // fallback - hiçbir şey yapma
      }
    }

    // Görsel çıkarma: önce RSS içindeki enclosure/media alanlarına bak, yoksa
    // description veya content içindeki ilk <img> etiketinin src'sini al.
    String? imageUrl;
    try {
      // webfeed_plus RssItem genellikle 'enclosure' alanını expose eder
      // ignore: avoid_dynamic_calls
      final dynamic it = item as dynamic;
      try {
        imageUrl = it.enclosure?.url as String?;
      } catch (_) {
        // ignore
      }

      // Bazı beslemelerde media:content/media:thumbnail veya benzeri extension'lar olabilir
      if (imageUrl == null) {
        try {
          imageUrl = it.media?.thumbnails != null && it.media.thumbnails.isNotEmpty
              ? (it.media.thumbnails[0].url as String?)
              : null;
        } catch (_) {
          // ignore
        }
      }
    } catch (_) {
      // ignore dynamic errors
    }

    // HTML etiketlerini ve HTML entity'lerini temizle (ayrıca img src yakalamaya çalış)
    if (desc != null) {
      // İlk olarak description/content içinden <img> src yakalamaya çalış
      try {
        final fragment = html_parser.parseFragment(desc);
        final img = fragment.querySelector('img');
        if (img != null && imageUrl == null) {
          imageUrl = img.attributes['src'];
        }
      } catch (_) {}

      desc = desc.replaceAll(RegExp(r'<[^>]*>'), ' ');
      desc = desc.replaceAll(RegExp(r'&[^;]+;'), ' ');
      desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return Article(
      title: item.title,
      description: desc,
      link: item.link,
      imageUrl: imageUrl,
      pubDate: item.pubDate,
      sourceName: sourceName,
      category: category,
    );
  }

  factory Article.fromCollectApi(Map<String, dynamic> json, String category) {
    return Article(
      title: json['name'] as String?,
      description: json['description'] as String?,
      link: json['url'] as String?,
      sourceName: json['source'] as String?,
      imageUrl: json['image'] as String?,
      pubDate: DateTime.now(),
      category: category,
    );
  }

  /// NewsAPI.org cache'inden gelen haber verisi için factory
  factory Article.fromNewsApiCache(Map<String, dynamic> json) {
    DateTime? pubDate;
    final publishedAt = json['publishedAt'];
    if (publishedAt != null && publishedAt is String) {
      try {
        pubDate = DateTime.parse(publishedAt);
      } catch (_) {
        pubDate = DateTime.now();
      }
    }
    
    return Article(
      title: json['title'] as String?,
      description: json['description'] as String?,
      link: json['url'] as String?,
      sourceName: json['source'] as String?,
      imageUrl: json['imageUrl'] as String?,
      pubDate: pubDate,
      category: json['category'] as String?,
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