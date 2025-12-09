// lib/screens/party_rankings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mp_model.dart';

/// Parti bazlı milletvekili performans sıralaması.
/// Her partinin en başarılı ve en başarısız vekillerini gösterir.
class PartyRankingsScreen extends StatefulWidget {
  const PartyRankingsScreen({super.key});

  @override
  State<PartyRankingsScreen> createState() => _PartyRankingsScreenState();
}

class _PartyRankingsScreenState extends State<PartyRankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Parti listesi ve renkleri
  static const List<Map<String, dynamic>> _parties = [
    {'name': 'AKP', 'color': Color(0xFFF7931E), 'icon': Icons.star},
    {'name': 'CHP', 'color': Color(0xFFE30A17), 'icon': Icons.people},
    {'name': 'MHP', 'color': Color(0xFFBB1E23), 'icon': Icons.flag},
    {'name': 'DEM PARTİ', 'color': Color(0xFF8B5CF6), 'icon': Icons.nature_people},
    {'name': 'İYİ Parti', 'color': Color(0xFF00AEEF), 'icon': Icons.brightness_5},
    {'name': 'YENİ YOL', 'color': Color(0xFF22C55E), 'icon': Icons.trending_up},
    {'name': 'Diğer', 'color': Color(0xFF6B7280), 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _parties.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parti Bazlı Performans',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorWeight: 3,
          tabs: _parties.map((party) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: party['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(party['name'] as String),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _parties.map((party) {
          return _PartyMpList(
            partyName: party['name'] as String,
            partyColor: party['color'] as Color,
          );
        }).toList(),
      ),
    );
  }
}

/// Bir partinin en başarılı ve en başarısız vekillerini gösteren widget.
class _PartyMpList extends StatelessWidget {
  final String partyName;
  final Color partyColor;

  const _PartyMpList({
    required this.partyName,
    required this.partyColor,
  });

  Query<Map<String, dynamic>> _getQuery() {
    final collection = FirebaseFirestore.instance.collection('mps');
    
    if (partyName == 'Diğer') {
      // Diğer partiler için ana partileri hariç tut
      return collection.where('party', whereNotIn: [
        'AKP', 'CHP', 'MHP', 'DEM PARTİ', 'İYİ Parti', 'YENİ YOL'
      ]);
    }
    
    return collection.where('party', isEqualTo: partyName);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Hata: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '$partyName partisine ait vekil bulunamadı',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Vekilleri parse et ve puana göre sırala
        final mps = snapshot.data!.docs
            .map((doc) => MpModel.fromFirestore(doc))
            .toList();
        
        mps.sort((a, b) => b.currentScore.compareTo(a.currentScore));

        // En başarılı 5 ve en başarısız 5
        final topMps = mps.take(5).toList();
        final bottomMps = mps.length > 5 
            ? mps.reversed.take(5).toList().reversed.toList()
            : <MpModel>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İstatistik kartı
              _buildStatsCard(context, mps),
              const SizedBox(height: 24),
              
              // En Başarılı Vekiller
              _buildSectionTitle(
                context, 
                '🏆 En Başarılı Vekiller', 
                Colors.green,
              ),
              const SizedBox(height: 12),
              ...topMps.asMap().entries.map((entry) {
                return _buildMpCard(
                  context, 
                  entry.value, 
                  entry.key + 1, 
                  isTop: true,
                );
              }),
              
              if (bottomMps.isNotEmpty) ...[
                const SizedBox(height: 24),
                
                // En Başarısız Vekiller
                _buildSectionTitle(
                  context, 
                  '⚠️ En Düşük Performans', 
                  Colors.red,
                ),
                const SizedBox(height: 12),
                ...bottomMps.asMap().entries.map((entry) {
                  return _buildMpCard(
                    context, 
                    entry.value, 
                    mps.length - bottomMps.length + entry.key + 1,
                    isTop: false,
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(BuildContext context, List<MpModel> mps) {
    final totalMps = mps.length;
    final avgScore = mps.isEmpty 
        ? 0.0 
        : mps.map((m) => m.currentScore).reduce((a, b) => a + b) / mps.length;
    final passiveMps = mps.where((m) => m.currentScore < 10).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            partyColor.withOpacity(0.2),
            partyColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: partyColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Vekil', totalMps.toString(), Icons.people),
          _buildStatItem('Ort. Puan', avgScore.toStringAsFixed(1), Icons.score),
          _buildStatItem('Pasif', passiveMps.toString(), Icons.warning_amber),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: partyColor, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: partyColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildMpCard(BuildContext context, MpModel mp, int rank, {required bool isTop}) {
    final theme = Theme.of(context);
    final scoreColor = isTop ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTop 
              ? Colors.green.withOpacity(0.2) 
              : Colors.orange.withOpacity(0.2),
          child: Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isTop ? Colors.green : Colors.orange,
            ),
          ),
        ),
        title: Text(
          mp.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          mp.constituency ?? mp.party,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scoreColor.withOpacity(0.3)),
          ),
          child: Text(
            mp.currentScore.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scoreColor,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
