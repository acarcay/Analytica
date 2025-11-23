// lib/services/financial_data_service.dart

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:convert';
import 'dart:async';
import '../utils/logging.dart';

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
  final double? btcUsdtPrice; // BTC price in USDT (e.g., from Binance)
  final double? goldGramPrice; // Gram altın fiyatı (TRY)

  FinancialData({required this.currencies, required this.btcPrice, this.btcUsdtPrice, this.goldGramPrice});
}

// API'den veri çeken servis sınıfı
class FinancialDataService {
  final String _tcmbUrl = 'https://www.tcmb.gov.tr/kurlar/today.xml';
  // Query CoinGecko for bitcoin and tether-gold (used as a gold ounce proxy)
  // We ask for TRY and USDT so we can get BTC/TRY and BTC/USDT in one call.
  final String _coinGeckoUrl = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,tether-gold&vs_currencies=try,usdt';
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

      // CoinGecko'dan BTC ve tether-gold verisini çek (basit cache: 60 saniye)
      final now = DateTime.now();
      double btcPrice;
      double? btcUsdt;
      try {
        if (_lastBtcFetchAt != null && _lastBtcPrice != null && now.difference(_lastBtcFetchAt!).inSeconds < 60) {
          btcPrice = _lastBtcPrice!;
        } else {
          final responseCG = await _getWithRetry(Uri.parse(_coinGeckoUrl));
          if (responseCG.statusCode != 200) {
            throw Exception('CoinGecko yanıtı başarısız: ${responseCG.statusCode}');
          }
          final btcData = json.decode(responseCG.body) as Map<String, dynamic>;
          // BTC price in TRY
          btcPrice = btcData['bitcoin'] != null && btcData['bitcoin']['try'] != null
              ? (btcData['bitcoin']['try'] as num).toDouble()
              : (throw Exception('CoinGecko returned no BTC TRY'));
          _lastBtcPrice = btcPrice;
          _lastBtcFetchAt = now;

          // Try to get BTC/USDT from CoinGecko first
          if (btcData['bitcoin'] != null && btcData['bitcoin']['usdt'] != null) {
            btcUsdt = (btcData['bitcoin']['usdt'] as num).toDouble();
          } else {
            btcUsdt = null;
          }
        }
      } catch (e) {
        // If CoinGecko fails completely, try Binance as a fallback for BTC/USDT
  AppLog.d('CoinGecko fetch failed, will attempt Binance fallback for BTC/USDT: $e');
        btcPrice = _lastBtcPrice ?? 0.0;
        try {
          final resp = await _getWithRetry(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT'));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            btcUsdt = (data['price'] as num).toDouble();
          }
        } catch (_) {
          btcUsdt = null;
        }
      }

      // Gram altın: try multiple sources. First genelpara, then CoinGecko (tether-gold per troy ounce) -> convert to gram.
      double? gramAltin;
      // 1 troy ounce = 31.1034768 grams
      const double troyOunceToGram = 31.1034768;

      // Try genelpara first
      try {
        final resp = await _getWithRetry(Uri.parse('https://api.genelpara.com/embed/altin.json'));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          try {
            final g = data['gram-altin'] ?? data['gram_altin'] ?? data['gramAltin'];
            if (g != null) {
              if (g['satis'] != null) {
                gramAltin = double.tryParse(g['satis'].toString());
              }
              if (gramAltin == null && g['price'] != null) gramAltin = (g['price'] as num).toDouble();
            }
          } catch (_) {
            gramAltin = null;
          }
        }
      } catch (_) {
        gramAltin = null;
      }

      // If genelpara didn't return a value, try CoinGecko's tether-gold price (which is per troy ounce) and convert to gram
      if (gramAltin == null) {
        try {
          final resp = await _getWithRetry(Uri.parse(_coinGeckoUrl));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            if (data['tether-gold'] != null && data['tether-gold']['try'] != null) {
              final ouncePriceTry = (data['tether-gold']['try'] as num).toDouble();
              gramAltin = ouncePriceTry / troyOunceToGram;
            }
          }
        } catch (e) {
          // ignore and leave gramAltin null
          AppLog.d('CoinGecko tether-gold fetch failed: $e');
        }
      }

      return FinancialData(currencies: currencies, btcPrice: btcPrice, btcUsdtPrice: btcUsdt, goldGramPrice: gramAltin);

    } catch (e) {
  AppLog.e("Finansal veri çekilirken hata oluştu: $e");
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