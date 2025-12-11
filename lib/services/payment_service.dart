import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';

class PaymentService with ChangeNotifier {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService() {
    return _instance;
  }

  PaymentService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Product IDs - These must match App Store Connect / Google Play Console
  static const Set<String> _kIds = <String>{
    'analytica_premium_monthly',
    'analytica_premium_annual',
  };

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isPremium = false;
  bool _isLoading = false;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  void oneTimeInit() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error
    });
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      _isAvailable = false;
      _products = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Example: query products
    final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);
    if (response.error != null) {
      _isAvailable = isAvailable;
      _products = response.productDetails; // Likely empty or partial
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (response.productDetails.isEmpty) {
      _isAvailable = isAvailable;
      _products = [];
      // If empty, it might be due to pending agreement in App Store Connect or invalid IDs
      debugPrint('Product query empty. Ensure IDs are correct in store.'); 
    } else {
      _products = response.productDetails;
    }

    _isAvailable = isAvailable;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    // For iOS, if it's subscription / non-consumable:
    // _iap.buyNonConsumable(purchaseParam: purchaseParam);
    // For now assuming subscriptions are non-consumable logic in IAP wrapper
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint("Purchase failed initiation: $e");
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint("Restore failed: $e");
    }
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Grant entitlement
          _isPremium = true;
          notifyListeners();
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
