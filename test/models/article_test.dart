// test/models/article_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:analytica/models/article.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Article', () {
    group('fromCollectApi', () {
      test('should parse CollectAPI JSON correctly', () {
        // Arrange
        final json = {
          'name': 'Ekonomide Büyük Gelişme',
          'description': 'Türkiye ekonomisi yüzde 5 büyüdü.',
          'url': 'https://example.com/news/1',
          'source': 'Anadolu Ajansı',
          'image': 'https://example.com/image.jpg',
        };
        
        // Act
        final article = Article.fromCollectApi(json, 'ekonomi');
        
        // Assert
        expect(article.title, equals('Ekonomide Büyük Gelişme'));
        expect(article.description, equals('Türkiye ekonomisi yüzde 5 büyüdü.'));
        expect(article.link, equals('https://example.com/news/1'));
        expect(article.sourceName, equals('Anadolu Ajansı'));
        expect(article.imageUrl, equals('https://example.com/image.jpg'));
        expect(article.category, equals('ekonomi'));
        expect(article.pubDate, isNotNull);
      });

      test('should handle null fields gracefully', () {
        // Arrange
        final json = <String, dynamic>{
          'name': null,
          'description': null,
          'url': null,
        };
        
        // Act
        final article = Article.fromCollectApi(json, 'diger');
        
        // Assert
        expect(article.title, isNull);
        expect(article.description, isNull);
        expect(article.link, isNull);
        expect(article.category, equals('diger'));
      });
    });

    group('fromFirestore', () {
      test('should parse Firestore document correctly', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        final testDate = DateTime(2024, 5, 20);
        final savedDate = DateTime(2024, 5, 21);
        
        await fakeFirestore.collection('articles').doc('art_001').set({
          'title': 'Meclis Toplantısı',
          'description': 'TBMM bugün toplandı.',
          'link': 'https://example.com/meclis',
          'sourceName': 'NTV',
          'pubDate': testDate,
          'category': 'politika',
          'imageUrl': 'https://example.com/meclis.jpg',
          'analysisResult': 'Olumlu',
          'savedAt': savedDate,
          'userId': 'user_123',
        });
        
        final doc = await fakeFirestore.collection('articles').doc('art_001').get();
        
        // Act
        final article = Article.fromFirestore(doc);
        
        // Assert
        expect(article.id, equals('art_001'));
        expect(article.title, equals('Meclis Toplantısı'));
        expect(article.description, equals('TBMM bugün toplandı.'));
        expect(article.sourceName, equals('NTV'));
        expect(article.category, equals('politika'));
        expect(article.analysisResult, equals('Olumlu'));
        expect(article.userId, equals('user_123'));
      });

      test('should handle missing fields', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('articles').doc('art_002').set({
          'title': 'Minimal Article',
        });
        
        final doc = await fakeFirestore.collection('articles').doc('art_002').get();
        
        // Act
        final article = Article.fromFirestore(doc);
        
        // Assert
        expect(article.id, equals('art_002'));
        expect(article.title, equals('Minimal Article'));
        expect(article.description, isNull);
        expect(article.link, isNull);
        expect(article.imageUrl, isNull);
      });
    });

    group('toFirestore', () {
      test('should convert Article to Firestore map', () {
        // Arrange
        final article = Article(
          id: 'art_001',
          title: 'Test Başlık',
          description: 'Test açıklama',
          link: 'https://example.com/test',
          sourceName: 'Test Kaynak',
          pubDate: DateTime(2024, 6, 1),
          category: 'teknoloji',
          imageUrl: 'https://example.com/test.jpg',
          analysisResult: 'Nötr',
          userId: 'user_456',
        );
        
        // Act
        final map = article.toFirestore();
        
        // Assert
        expect(map['title'], equals('Test Başlık'));
        expect(map['description'], equals('Test açıklama'));
        expect(map['link'], equals('https://example.com/test'));
        expect(map['sourceName'], equals('Test Kaynak'));
        expect(map['category'], equals('teknoloji'));
        expect(map['imageUrl'], equals('https://example.com/test.jpg'));
        expect(map['analysisResult'], equals('Nötr'));
        expect(map['userId'], equals('user_456'));
        expect(map['savedAt'], isNotNull);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        // Arrange
        final original = Article(
          id: 'art_001',
          title: 'Original Title',
          description: 'Original description',
          category: 'dunya',
        );
        
        // Act
        final copy = original.copyWith(
          title: 'Updated Title',
          analysisResult: 'Pozitif',
        );
        
        // Assert
        expect(copy.id, equals('art_001'));
        expect(copy.title, equals('Updated Title'));
        expect(copy.description, equals('Original description'));
        expect(copy.category, equals('dunya'));
        expect(copy.analysisResult, equals('Pozitif'));
        // Original unchanged
        expect(original.title, equals('Original Title'));
        expect(original.analysisResult, isNull);
      });
    });
  });

  group('ArticleCategory', () {
    test('should have all expected categories', () {
      expect(ArticleCategory.values, containsAll([
        ArticleCategory.ekonomi,
        ArticleCategory.teknoloji,
        ArticleCategory.spor,
        ArticleCategory.saglik,
        ArticleCategory.egitim,
        ArticleCategory.politika,
        ArticleCategory.dunya,
        ArticleCategory.kultur,
        ArticleCategory.diger,
      ]));
    });

    test('should have correct number of categories', () {
      expect(ArticleCategory.values.length, equals(9));
    });
  });
}
