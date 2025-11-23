// lib/services/image_extractor.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../utils/logging.dart';

class ImageExtractor {
  // Simple in-memory cache to avoid refetching same URLs repeatedly during app run
  static final Map<String, String?> _cache = {};

  /// Tries to extract a representative image URL from [pageUrl].
  /// Checks in order: og:image, twitter:image, schema.org/image, first <img> in article/content.
  /// Returns null if no suitable image found or on error.
  static Future<String?> extractImage(String pageUrl, {Duration timeout = const Duration(seconds: 8)}) async {
    if (pageUrl.isEmpty) return null;
    if (_cache.containsKey(pageUrl)) return _cache[pageUrl];

    try {
      final uri = Uri.tryParse(pageUrl);
      if (uri == null || !uri.isAbsolute) return null;

      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        _cache[pageUrl] = null;
        return null;
      }

      final document = html_parser.parse(response.body);

      // helper to normalize relative urls safely
      String? normalize(String? src) {
        if (src == null) return null;
        final trimmed = src.trim();
        if (trimmed.isEmpty) return null;
        try {
          final srcUri = Uri.parse(trimmed);
          if (srcUri.isAbsolute) return trimmed;
        } catch (_) {
          // not an absolute URL
        }
        try {
          final base = uri;
          return Uri.parse(base.origin).resolve(trimmed).toString();
        } catch (_) {
          return null;
        }
      }

      // SECURITY: simple host allowlist — only accept images from known hosts to reduce privacy/tracker risk
      final allowedHosts = <String>{
        'i.pravatar.cc',
        'cdn.pixabay.com',
        'pbs.twimg.com',
        'upload.wikimedia.org',
        'images.unsplash.com',
      };

      // 1) og:image
      final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
      final og = normalize(ogImage);
      if (og != null) {
        final host = Uri.tryParse(og)?.host;
        if (host != null && (allowedHosts.contains(host) || host.endsWith('.akamaized.net'))) {
          _cache[pageUrl] = og;
          return og;
        } else {
          AppLog.d('ImageExtractor: og:image host not allowed: $host for $pageUrl');
        }
      }

      // 2) twitter:image
      final twImage = document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
      final tw = normalize(twImage);
      if (tw != null) {
        final host = Uri.tryParse(tw)?.host;
        if (host != null && (allowedHosts.contains(host) || host.endsWith('.akamaized.net'))) {
          _cache[pageUrl] = tw;
          return tw;
        } else {
          AppLog.d('ImageExtractor: twitter:image host not allowed: $host for $pageUrl');
        }
      }

      // 3) schema.org image (itemprop="image")
      final schemaImage = document.querySelector('meta[itemprop="image"]')?.attributes['content'];
      final sch = normalize(schemaImage);
      if (sch != null) {
        final host = Uri.tryParse(sch)?.host;
        if (host != null && (allowedHosts.contains(host) || host.endsWith('.akamaized.net'))) {
          _cache[pageUrl] = sch;
          return sch;
        } else {
          AppLog.d('ImageExtractor: schema image host not allowed: $host for $pageUrl');
        }
      }

      // 4) look for <article> or common containers and find first <img>
      dom.Element? container = document.querySelector('article') ?? document.querySelector('[role="main"]') ?? document.querySelector('.article') ?? document.body;
      final firstImg = container?.querySelector('img')?.attributes['src'] ?? container?.querySelector('img')?.attributes['data-src'];
      final first = normalize(firstImg);
      if (first != null) {
        final host = Uri.tryParse(first)?.host;
        if (host != null && (allowedHosts.contains(host) || host.endsWith('.akamaized.net'))) {
          _cache[pageUrl] = first;
          return first;
        } else {
          AppLog.d('ImageExtractor: first <img> host not allowed: $host for $pageUrl');
        }
      }

      // 5) fallback: any <img> in the page
      final anyImg = document.querySelector('img')?.attributes['src'];
      final any = normalize(anyImg);
      if (any != null) {
        final host = Uri.tryParse(any)?.host;
        if (host != null && (allowedHosts.contains(host) || host.endsWith('.akamaized.net'))) {
          _cache[pageUrl] = any;
          return any;
        } else {
          AppLog.d('ImageExtractor: fallback <img> host not allowed: $host for $pageUrl');
        }
      }

      _cache[pageUrl] = null;
      return null;
    } catch (e) {
      AppLog.d('ImageExtractor: error for $pageUrl -> $e');
      // on any error, don't crash; cache negative result briefly
      _cache[pageUrl] = null;
      return null;
    }
  }
}
