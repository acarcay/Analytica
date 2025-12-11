import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../widgets/loading_animation.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _paymentService = Provider.of<PaymentService>(context, listen: false);
    // Initialize connection if not already
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentService.oneTimeInit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for premium feel
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1E1E2C),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Consumer<PaymentService>(
              builder: (context, paymentService, child) {
                if (paymentService.isLoading) {
                  return const Center(child: LoadingAnimation());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.workspace_premium, size: 60, color: Color(0xFFFFD700)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        "Analytica Premium'a Geçin",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Sınırsız analiz, reklamsız deneyim ve özel raporlar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Features List
                      _buildFeatureRow("Sınırsız AI Haber Analizi"),
                      _buildFeatureRow("Reklamsız Deneyim"),
                      _buildFeatureRow("Detaylı Vekil Raporları"),
                      _buildFeatureRow("Erken Erişim Özellikleri"),
                      
                      const SizedBox(height: 48),

                      // Products
                      if (paymentService.isPremium) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 40),
                              SizedBox(height: 12),
                              Text(
                                "Premium Üyeliğiniz Aktif",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ] else if (paymentService.products.isEmpty) ...[
                         // Mock UI if no products found (common in emulator)
                        _buildSubscriptionCard(
                          context, 
                          title: "Yıllık Plan", 
                          price: "₺899.99 / Yıl", 
                          description: "%40 Tasarruf Edin",
                          isBestValue: true,
                          onTap: () {}, // Mock
                        ),
                        const SizedBox(height: 16),
                        _buildSubscriptionCard(
                          context, 
                          title: "Aylık Plan", 
                          price: "₺99.99 / Ay", 
                          description: "İstediğin zaman iptal et",
                          onTap: () {}, // Mock
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Demo Modu: Ürünler Store'dan çekilemedi.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ] else ...[
                        ...paymentService.products.map((product) {
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 16),
                             child: _buildSubscriptionCard(
                               context,
                               title: product.title, // Usually contains app name too, might want to clean
                               price: product.price,
                               description: product.description,
                               onTap: () => paymentService.buyProduct(product),
                             ),
                           );
                        }),
                      ],

                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => paymentService.restorePurchases(),
                        child: const Text("Satın Alımları Geri Yükle", style: TextStyle(color: Colors.grey)),
                      ),
                      
                      const SizedBox(height: 24),
                       Row( // Legal Links
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(onPressed: () {}, child: const Text("Kullanım Koşulları", style: TextStyle(fontSize: 10, color: Colors.grey))),
                          const Text("•", style: TextStyle(color: Colors.grey)),
                          TextButton(onPressed: () {}, child: const Text("Gizlilik Politikası", style: TextStyle(fontSize: 10, color: Colors.grey))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, {
    required String title,
    required String price,
    required String description,
    bool isBestValue = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C3E),
          borderRadius: BorderRadius.circular(16),
          border: isBestValue ? Border.all(color: const Color(0xFFFFD700), width: 2) :Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text("EN POPÜLER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
