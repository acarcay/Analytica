import 'package:flutter/material.dart';
import '../models/article.dart';

class CategorySelector extends StatefulWidget {
  final String? selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  String? _selectedCategory;

  final Map<ArticleCategory, String> _categoryNames = {
    ArticleCategory.ekonomi: 'Ekonomi',
    ArticleCategory.teknoloji: 'Teknoloji',
    ArticleCategory.spor: 'Spor',
    ArticleCategory.saglik: 'Sağlık',
    ArticleCategory.egitim: 'Eğitim',
    ArticleCategory.politika: 'Politika',
    ArticleCategory.dunya: 'Dünya',
    ArticleCategory.kultur: 'Kültür',
    ArticleCategory.diger: 'Diğer',
  };

  final Map<ArticleCategory, IconData> _categoryIcons = {
    ArticleCategory.ekonomi: Icons.attach_money,
    ArticleCategory.teknoloji: Icons.computer,
    ArticleCategory.spor: Icons.sports,
    ArticleCategory.saglik: Icons.health_and_safety,
    ArticleCategory.egitim: Icons.school,
    ArticleCategory.politika: Icons.account_balance,
    ArticleCategory.dunya: Icons.public,
    ArticleCategory.kultur: Icons.theater_comedy,
    ArticleCategory.diger: Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kategori Seçin'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
          ),
          itemCount: ArticleCategory.values.length,
          itemBuilder: (context, index) {
            final category = ArticleCategory.values[index];
            final categoryName = _categoryNames[category]!;
            final isSelected = _selectedCategory == category.name;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category.name;
                });
                widget.onCategorySelected(category.name);
                Navigator.of(context).pop();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _categoryIcons[category],
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        categoryName,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
      ],
    );
  }
}

// Kategori adını Türkçe'ye çeviren yardımcı fonksiyon
String getCategoryDisplayName(String categoryName) {
  switch (categoryName) {
    case 'ekonomi':
      return 'Ekonomi';
    case 'teknoloji':
      return 'Teknoloji';
    case 'spor':
      return 'Spor';
    case 'saglik':
      return 'Sağlık';
    case 'egitim':
      return 'Eğitim';
    case 'politika':
      return 'Politika';
    case 'dunya':
      return 'Dünya';
    case 'kultur':
      return 'Kültür';
    case 'diger':
      return 'Diğer';
    default:
      return 'Diğer';
  }
}

// Kategori ikonunu döndüren yardımcı fonksiyon
IconData getCategoryIcon(String categoryName) {
  switch (categoryName) {
    case 'ekonomi':
      return Icons.attach_money;
    case 'teknoloji':
      return Icons.computer;
    case 'spor':
      return Icons.sports;
    case 'saglik':
      return Icons.health_and_safety;
    case 'egitim':
      return Icons.school;
    case 'politika':
      return Icons.account_balance;
    case 'dunya':
      return Icons.public;
    case 'kultur':
      return Icons.theater_comedy;
    case 'diger':
      return Icons.category;
    default:
      return Icons.category;
  }
}
