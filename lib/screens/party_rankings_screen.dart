import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mp_model.dart';

class PartyRankingsScreen extends StatefulWidget {
  const PartyRankingsScreen({super.key});

  @override
  State<PartyRankingsScreen> createState() => _PartyRankingsScreenState();
}

class _PartyRankingsScreenState extends State<PartyRankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _parties = [
    {'name': 'AKP', 'color': Color(0xFFF7931E)},
    {'name': 'CHP', 'color': Color(0xFFE30A17)},
    {'name': 'MHP', 'color': Color(0xFFBB1E23)},
    {'name': 'DEM', 'color': Color(0xFF8B5CF6)}, // Shortened for cleaner UI
    {'name': 'İYİ', 'color': Color(0xFF00AEEF)},
    {'name': 'Diğer', 'color': Color(0xFF6B7280)},
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Parti Sıralaması', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: _parties.map((party) {
            final color = party['color'] as Color;
            return Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: color),
                    const SizedBox(width: 8),
                    Text(
                      party['name'] as String,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
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

class _PartyMpList extends StatelessWidget {
  final String partyName;
  final Color partyColor;

  const _PartyMpList({required this.partyName, required this.partyColor});

  Query<Map<String, dynamic>> _getQuery() {
    final collection = FirebaseFirestore.instance.collection('mps');
    if (partyName == 'Diğer') {
      return collection.where('party', whereNotIn: ['AKP', 'CHP', 'MHP', 'DEM PARTİ', 'İYİ Parti', 'YENİ YOL']);
    }
    // Handle specific mapping if needed, assuming simple equality for now or 'DEM' mapping
    String queryName = partyName;
    if (partyName == 'DEM') queryName = 'DEM PARTİ';
    if (partyName == 'İYİ') queryName = 'İYİ Parti';

    return collection.where('party', isEqualTo: queryName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return StreamBuilder<QuerySnapshot>(
      stream: _getQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.person_off, size: 60, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                 const SizedBox(height: 16),
                 Text("Milletvekili bulunamadı", style: TextStyle(color: theme.colorScheme.outline)),
               ],
             ),
           );
        }

        final mps = snapshot.data!.docs.map((doc) => MpModel.fromFirestore(doc)).toList();
        // Sort by score locally since Firestore lacks complex secondary ordering without index
        mps.sort((a, b) => b.currentScore.compareTo(a.currentScore));

        final top5 = mps.take(5).toList();
        final bottom5 = mps.length > 5 ? mps.reversed.take(5).toList() : <MpModel>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatHeader(context, mps),
            const SizedBox(height: 24),
            
            Text("En Başarılı 5", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 12),
            ...top5.map((mp) => _buildMpCard(context, mp, true)),

            if (bottom5.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text("Gelişim Beklenenler", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 12),
              ...bottom5.map((mp) => _buildMpCard(context, mp, false)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatHeader(BuildContext context, List<MpModel> mps) {
    if (mps.isEmpty) return const SizedBox.shrink();
    final avg = mps.map((m) => m.currentScore).reduce((a, b) => a + b) / mps.length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: partyColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: partyColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(context, "${mps.length}", "Vekil"),
          _statItem(context, avg.toStringAsFixed(1), "Ort. Puan"),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: partyColor)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildMpCard(BuildContext context, MpModel mp, bool isTop) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
         color: colorScheme.surfaceContainerLow,
         borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTop ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
          child: Icon(isTop ? Icons.trending_up : Icons.trending_down, color: isTop ? Colors.green : Colors.orange, size: 20),
        ),
        title: Text(mp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(mp.constituency ?? '', style: const TextStyle(fontSize: 12)),
        trailing: Text(
          mp.currentScore.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 16, 
            color: isTop ? Colors.green : Colors.orange
          ),
        ),
      ),
    );
  }
}
