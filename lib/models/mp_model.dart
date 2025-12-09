// lib/models/mp_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Milletvekili (MP) veri modeli.
/// Python backend'in Firestore'a yazdığı snake_case alanları
/// Dart'ın camelCase convention'ına çevirir.
class MpModel {
  final String id;
  final String name;
  final String party;
  final double currentScore;
  final DateTime lastUpdated;
  
  // Opsiyonel alanlar
  final String? constituency;
  final int termCount;
  final int lawProposals;
  final String? profileImageUrl;

  MpModel({
    required this.id,
    required this.name,
    required this.party,
    required this.currentScore,
    required this.lastUpdated,
    this.constituency,
    this.termCount = 1,
    this.lawProposals = 0,
    this.profileImageUrl,
  });

  /// Firestore'dan gelen verileri parse et.
  /// Python backend snake_case kullanıyor (current_score, last_updated).
  /// Bu metod güvenli type casting yapar.
  factory MpModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // current_score int veya double gelebilir, güvenli cast
    double parseScore(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    // last_updated Timestamp veya null gelebilir
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }
    
    return MpModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Bilinmeyen',
      party: data['party'] as String? ?? 'Bağımsız',
      currentScore: parseScore(data['current_score']),
      lastUpdated: parseDateTime(data['last_updated']),
      constituency: data['constituency'] as String?,
      termCount: (data['term_count'] as int?) ?? 1,
      lawProposals: (data['law_proposals'] as int?) ?? 0,
      profileImageUrl: data['profile_image_url'] as String?,
    );
  }

  /// Firestore'a yazılacak formata çevir.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'party': party,
      'current_score': currentScore,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'constituency': constituency,
      'term_count': termCount,
      'law_proposals': lawProposals,
      'profile_image_url': profileImageUrl,
    };
  }

  /// Kopyalama metodu.
  MpModel copyWith({
    String? id,
    String? name,
    String? party,
    double? currentScore,
    DateTime? lastUpdated,
    String? constituency,
    int? termCount,
    int? lawProposals,
    String? profileImageUrl,
  }) {
    return MpModel(
      id: id ?? this.id,
      name: name ?? this.name,
      party: party ?? this.party,
      currentScore: currentScore ?? this.currentScore,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      constituency: constituency ?? this.constituency,
      termCount: termCount ?? this.termCount,
      lawProposals: lawProposals ?? this.lawProposals,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  @override
  String toString() {
    return 'MpModel(id: $id, name: $name, party: $party, score: $currentScore)';
  }
}
