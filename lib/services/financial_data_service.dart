// lib/services/financial_data_service.dart

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:convert';
import 'dart:async';

// Her bir para biriminin verisini tutacak model
class CurrencyData {
  final String name;
  final String code;
  final String buying;
  final String selling;

  CurrencyData({required this.name, required this.code, required this.buying, required this.selling});
}

// Tüm finansal verileri bir arada tutacak ana model
class FinancialData {
  final List<CurrencyData> currencies;
  final double btcPrice;

  FinancialData({required this.currencies, required this.btcPrice});
}

// API'den veri çeken servis sınıfı
class FinancialDataService {
  final String _tcmbUrl = 'https://www.tcmb.gov.tr/kurlar/today.xml';
  final String _coinGeckoUrl = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=try';
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _maxRetries = 2;
  DateTime? _lastBtcFetchAt;
  double? _lastBtcPrice;

  Future<FinancialData> fetchFinancialData() async {
    try {
      // TCMB'den Döviz verilerini çek
      final responseTCMB = await _getWithRetry(Uri.parse(_tcmbUrl));
      if (responseTCMB.statusCode != 200) {
        throw Exception('TCMB yanıtı başarısız: ${responseTCMB.statusCode}');
      }
      final document = xml.XmlDocument.parse(responseTCMB.body);

      final List<CurrencyData> currencies = [];
      final codesToFetch = ['USD', 'EUR', 'GBP'];

      for (var code in codesToFetch) {
        final currencyNode = document.findAllElements('Currency').firstWhere((e) => e.getAttribute('Kod') == code);
        currencies.add(CurrencyData(
          code: code,
          name: currencyNode.findElements('Isim').first.text,
          buying: currencyNode.findElements('ForexBuying').first.text,
          selling: currencyNode.findElements('ForexSelling').first.text,
        ));
      }

      // CoinGecko'dan BTC verisini çek (basit cache: 60 saniye)
      final now = DateTime.now();
      double btcPrice;
      if (_lastBtcFetchAt != null && _lastBtcPrice != null && now.difference(_lastBtcFetchAt!).inSeconds < 60) {
        btcPrice = _lastBtcPrice!;
      } else {
        final responseBTC = await _getWithRetry(Uri.parse(_coinGeckoUrl));
        if (responseBTC.statusCode != 200) {
          throw Exception('CoinGecko yanıtı başarısız: ${responseBTC.statusCode}');
        }
        final btcData = json.decode(responseBTC.body);
        btcPrice = (btcData['bitcoin']['try'] as num).toDouble();
        _lastBtcPrice = btcPrice;
        _lastBtcFetchAt = now;
      }

      return FinancialData(currencies: currencies, btcPrice: btcPrice);

    } catch (e) {
      print("Finansal veri çekilirken hata oluştu: $e");
      throw Exception('Veriler alınamadı.');
    }
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await http.get(uri).timeout(_defaultTimeout);
        return response;
      } on TimeoutException catch (_) {
        if (attempt++ >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      } catch (_) {
        if (attempt++ >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }
}