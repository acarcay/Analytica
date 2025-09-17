
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http paketini kullanabilmek için
import 'dart:convert'; // JSON verisini işlemek için
import 'news_detail_screen.dart';

// SINIF ADINI DÜZELTTİK: home_screen -> HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // SINIF ADINI DÜZELTTİK: _home_screen_state -> _HomeScreenState
  State<HomeScreen> createState() => _HomeScreenState();
}

// SINIF ADINI DÜZELTTİK: _home_screen_state -> _HomeScreenState
// ve State<home_screen> -> State<HomeScreen>
class _HomeScreenState extends State<HomeScreen> {
  // `late` kelimesi, bu değişkene ilk başta bir değer atamayacağımızı,
  // ama onu kullanmadan önce mutlaka bir değer atayacağımızı belirtir.
  late Future<List<Article>> futureArticles;

  @override
  void initState() {
    super.initState();
    // ekran ilk açıldığında haberleri çekme işlemini başlatıyoruz
    futureArticles = fetchArticles();
  }

  // bu fonksiyon NewsAPI'ye istek atıp haberleri çeker
  Future<List<Article>> fetchArticles() async {
    const apiKey =
        "675459ffe3e7441898d2465f1cb40b0c"; // <-- BURAYA KENDİ API ANAHTARINIZI YAPIŞTIRIN
    const url =
        'https://newsapi.org/v2/top-headlines?country=tr&apiKey=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // istek başarılıysa, gelen JSON verisini işliyoruz
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List articlesJson = jsonResponse['articles'];

        // JSON listesindeki her bir haberi `Article` objesine dönüştürüyoruz
        return articlesJson.map((json) => Article.fromJson(json)).toList();
      } else {
        // istek başarısızsa (örneğin API anahtarı yanlışsa)
        throw Exception(
          'Haberler yüklenemedi. Hata kodu: ${response.statusCode}',
        );
      }
    } catch (e) {
      // internet bağlantısı yoksa veya başka bir hata olursa
      throw Exception('Bir hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytica - Güncel Haberler'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        // FutureBuilder, `fetchArticles` fonksiyonu tamamlandığında
        // ekranı otomatik olarak güncelleyen çok kullanışlı bir widget'tır.
        child: FutureBuilder<List<Article>>(
          future: futureArticles,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Veri henüz gelmediyse, bir yükleniyor animasyonu göster
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              // Bir hata oluştuysa, hata mesajını göster
              return Text('${snapshot.error}');
            } else if (snapshot.hasData) {
              // Veri başarıyla geldiyse, haberleri bir liste olarak göster
              final articles = snapshot.data!;
              return ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: ListTile(
                      title: Text(article.title),
                      subtitle: Text(article.sourceName),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NewsDetailScreen(article: article),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            } else {
              // Veri yoksa (boş liste geldiyse)
              return const Text("Gösterilecek haber bulunamadı.");
            }
          },
        ),
      ),
    );
  }
}

// bu class, API'den gelen bir haberin yapısını temsil eder.
// bu, gelen karmaşık JSON verisini daha yönetilebilir hale getirir.
// SINIF ADINI DÜZELTTİK: article -> Article
class Article {
  final String title;
  final String sourceName;
  final String? description; // Açıklama (null olabilir)
  final String? urlToImage; // Resim URL'si (null olabilir)
  final String url; // Haberin orijinal linki

  Article({
    required this.title,
    required this.sourceName,
    this.description,
    this.urlToImage,
    required this.url,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? 'Başlık Bulunamadı',
      sourceName: json['source']?['name'] ?? 'Kaynak Bilinmiyor',
      description: json['description'], // Bu alanlar null gelebilir
      urlToImage: json['urlToImage'], // Bu yüzden null kontrolü yapmıyoruz
      url: json['url'] ?? '',
    );
  }
}
