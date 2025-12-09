// test/models/mp_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:analytica/models/mp_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('MpModel', () {
    group('fromFirestore', () {
      test('should parse complete MP data correctly', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        final testData = {
          'name': 'Ahmet Yılmaz',
          'party': 'AKP',
          'current_score': 45.5,
          'last_updated': DateTime(2024, 1, 15),
          'constituency': 'İstanbul',
          'term_count': 3,
          'law_proposals': 7,
          'profile_image_url': 'https://example.com/photo.jpg',
        };
        
        await fakeFirestore.collection('mps').doc('mp_001').set(testData);
        final doc = await fakeFirestore.collection('mps').doc('mp_001').get();
        
        // Act
        final mp = MpModel.fromFirestore(doc);
        
        // Assert
        expect(mp.id, equals('mp_001'));
        expect(mp.name, equals('Ahmet Yılmaz'));
        expect(mp.party, equals('AKP'));
        expect(mp.currentScore, equals(45.5));
        expect(mp.constituency, equals('İstanbul'));
        expect(mp.termCount, equals(3));
        expect(mp.lawProposals, equals(7));
        expect(mp.profileImageUrl, equals('https://example.com/photo.jpg'));
      });

      test('should handle missing optional fields with defaults', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        final testData = {
          'name': 'Mehmet Demir',
          'party': 'CHP',
        };
        
        await fakeFirestore.collection('mps').doc('mp_002').set(testData);
        final doc = await fakeFirestore.collection('mps').doc('mp_002').get();
        
        // Act
        final mp = MpModel.fromFirestore(doc);
        
        // Assert
        expect(mp.id, equals('mp_002'));
        expect(mp.currentScore, equals(0.0));
        expect(mp.termCount, equals(1));
        expect(mp.lawProposals, equals(0));
        expect(mp.constituency, isNull);
        expect(mp.profileImageUrl, isNull);
      });

      test('should handle null name and party with defaults', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('mps').doc('mp_003').set({});
        final doc = await fakeFirestore.collection('mps').doc('mp_003').get();
        
        // Act
        final mp = MpModel.fromFirestore(doc);
        
        // Assert
        expect(mp.name, equals('Bilinmeyen'));
        expect(mp.party, equals('Bağımsız'));
      });

      test('should parse integer score as double', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('mps').doc('mp_004').set({
          'name': 'Test',
          'party': 'Test',
          'current_score': 50, // integer instead of double
        });
        final doc = await fakeFirestore.collection('mps').doc('mp_004').get();
        
        // Act
        final mp = MpModel.fromFirestore(doc);
        
        // Assert
        expect(mp.currentScore, isA<double>());
        expect(mp.currentScore, equals(50.0));
      });

      test('should parse string score as double', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('mps').doc('mp_005').set({
          'name': 'Test',
          'party': 'Test',
          'current_score': '75.5', // string instead of number
        });
        final doc = await fakeFirestore.collection('mps').doc('mp_005').get();
        
        // Act
        final mp = MpModel.fromFirestore(doc);
        
        // Assert
        expect(mp.currentScore, equals(75.5));
      });
    });

    group('toFirestore', () {
      test('should convert MpModel to Firestore map correctly', () {
        // Arrange
        final mp = MpModel(
          id: 'mp_001',
          name: 'Ali Öztürk',
          party: 'İYİ',
          currentScore: 32.5,
          lastUpdated: DateTime(2024, 3, 10),
          constituency: 'Ankara',
          termCount: 2,
          lawProposals: 4,
          profileImageUrl: 'https://example.com/ali.jpg',
        );
        
        // Act
        final map = mp.toFirestore();
        
        // Assert
        expect(map['name'], equals('Ali Öztürk'));
        expect(map['party'], equals('İYİ'));
        expect(map['current_score'], equals(32.5));
        expect(map['constituency'], equals('Ankara'));
        expect(map['term_count'], equals(2));
        expect(map['law_proposals'], equals(4));
        expect(map['profile_image_url'], equals('https://example.com/ali.jpg'));
      });
    });

    group('copyWith', () {
      test('should create new instance with updated fields', () {
        // Arrange
        final original = MpModel(
          id: 'mp_001',
          name: 'Fatma Kaya',
          party: 'MHP',
          currentScore: 20.0,
          lastUpdated: DateTime.now(),
        );
        
        // Act
        final updated = original.copyWith(
          currentScore: 55.0,
          lawProposals: 10,
        );
        
        // Assert
        expect(updated.id, equals('mp_001'));
        expect(updated.name, equals('Fatma Kaya'));
        expect(updated.party, equals('MHP'));
        expect(updated.currentScore, equals(55.0));
        expect(updated.lawProposals, equals(10));
        // Original should be unchanged
        expect(original.currentScore, equals(20.0));
        expect(original.lawProposals, equals(0));
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        // Arrange
        final mp = MpModel(
          id: 'mp_001',
          name: 'Test Vekil',
          party: 'CHP',
          currentScore: 42.5,
          lastUpdated: DateTime.now(),
        );
        
        // Act
        final result = mp.toString();
        
        // Assert
        expect(result, contains('mp_001'));
        expect(result, contains('Test Vekil'));
        expect(result, contains('CHP'));
        expect(result, contains('42.5'));
      });
    });
  });
}
