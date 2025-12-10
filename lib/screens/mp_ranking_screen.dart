import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mp_model.dart';

class MpRankingScreen extends StatelessWidget {
  const MpRankingScreen({super.key});

  Color _getScoreColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 5.0) return Colors.orange;
    return Colors.red;
  }

  Color _getPartyColor(String party) {
    switch (party.toUpperCase()) {
      case 'AKP': return const Color(0xFFF7931E);
      case 'CHP': return const Color(0xFFE30A17);
      case 'MHP': return const Color(0xFFE30A17);
      case 'İYİ': case 'IYI': return const Color(0xFF00AEEF);
      case 'HDP': case 'DEM': return const Color(0xFF8B5CF6);
      case 'DEVA': return const Color(0xFF0EA5E9);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Vekil Performansı',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mps')
            .orderBy('current_score', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Veri bulunamadı"));
          }

          final mps = snapshot.data!.docs.map((doc) => MpModel.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mps.length,
            itemBuilder: (context, index) {
              final mp = mps[index];
              final scoreColor = _getScoreColor(mp.currentScore);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: scoreColor.withValues(alpha: 0.1),
                    child: Text(
                      "#${index + 1}",
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    mp.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getPartyColor(mp.party),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(mp.party),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mp.currentScore.toStringAsFixed(1),
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Puanlama Sistemi"),
        content: const Text(
          "Puanlar vekilin meclis faaliyetleri, kanun teklifleri ve kamuoyu etkisi analiz edilerek hesaplanmıştır.\n\n"
          "🟢 8.0+: Yüksek\n"
          "🟠 5.0-7.9: Orta\n"
          "🔴 <5.0: Düşük"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam")),
        ],
      ),
    );
  }
}
