import 'package:flutter/material.dart';
import 'home_screen.dart'; // Article sınıfını kullanabilmek için

class NewsDetailScreen extends StatelessWidget {
  final Article article;

  const NewsDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          article.sourceName,
        ), // App bar'da haber kaynağının adını yazdıralım
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // İçerik ekrana sığmazsa kaydırma özelliği ekler
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Haberin resmi varsa göster, yoksa gösterme
              if (article.urlToImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    article.urlToImage!,
                    // Resim yüklenirken hata olursa diye bir yedek ikon
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image_not_supported, size: 100);
                    },
                  ),
                ),

              const SizedBox(height: 16), // Boşluk
              // Haberin başlığı
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10), // Boşluk
              // Haberin açıklaması varsa göster
              if (article.description != null)
                Text(
                  article.description!,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
