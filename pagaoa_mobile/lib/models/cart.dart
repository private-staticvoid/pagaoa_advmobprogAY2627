import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart'; // NEW — resolves the real logged-in userId
import 'product.dart';

class Cart {
  final int id;
  final List<CartProduct> products;
  final double total;
  final double discountedTotal;
  final int userId;
  final int totalProducts;
  final int totalQuantity;

  Cart({
    required this.id,
    required this.products,
    required this.total,
    required this.discountedTotal,
    required this.userId,
    required this.totalProducts,
    required this.totalQuantity,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] ?? 0,
      products:
          (json['products'] as List?)
              ?.map((e) => CartProduct.fromJson(e))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      discountedTotal: (json['discountedTotal'] as num?)?.toDouble() ?? 0.0,
      userId: json['userId'] ?? 0,
      totalProducts: json['totalProducts'] ?? 0,
      totalQuantity: json['totalQuantity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'products': products.map((e) => e.toJson()).toList(),
      'total': total,
      'discountedTotal': discountedTotal,
      'userId': userId,
      'totalProducts': totalProducts,
      'totalQuantity': totalQuantity,
    };
  }

  Cart copyWith({
    List<CartProduct>? products,
    double? total,
    double? discountedTotal,
  }) {
    return Cart(
      id: id,
      products: products ?? this.products,
      total: total ?? this.total,
      discountedTotal: discountedTotal ?? this.discountedTotal,
      userId: userId,
      totalProducts: totalProducts,
      totalQuantity: totalQuantity,
    );
  }
}

class CartProduct {
  final int id;
  final String title;
  final double price;
  final int quantity;
  final double total;
  final double discountPercentage;
  final double discountedTotal;
  final String thumbnail;

  CartProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    required this.total,
    required this.discountPercentage,
    required this.discountedTotal,
    required this.thumbnail,
  });

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    return CartProduct(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      discountPercentage:
          (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      discountedTotal: (json['discountedTotal'] as num?)?.toDouble() ?? 0.0,
      thumbnail: json['thumbnail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'quantity': quantity,
      'total': total,
      'discountPercentage': discountPercentage,
      'discountedTotal': discountedTotal,
      'thumbnail': thumbnail,
    };
  }

  CartProduct copyWith({
    int? quantity,
    double? total,
    double? discountedTotal,
  }) {
    return CartProduct(
      id: id,
      title: title,
      price: price,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      discountPercentage: discountPercentage,
      discountedTotal: discountedTotal ?? this.discountedTotal,
      thumbnail: thumbnail,
    );
  }
}

class LocalCartStore extends ChangeNotifier {
  LocalCartStore._internal();
  static final LocalCartStore instance = LocalCartStore._internal();

  Cart? _cart;
  Cart? get cart => _cart;

  bool _loading = false;
  bool get loading => _loading;

  // ============================================================
  // ENHANCEMENT 3 — "render the cart by userId"
  // ------------------------------------------------------------
  // Previously loadInitial() always called
  // CartService().getCartByUserId(demoUserId) — a hardcoded `1`, so
  // every user saw the same cart. We now track which userId the
  // currently-cached _cart belongs to (_loadedUserId) and resolve the
  // REAL id from the persisted session via UserService().getUser().id
  // (the same SharedPreferences-backed session that survives app
  // restarts thanks to the splash screen's persistent-auth check).
  //
  // Call site is unchanged — cart_screen.dart still just calls
  // `LocalCartStore.instance.loadInitial()` with no args — this method
  // resolves "who's logged in right now" internally, and reloads
  // automatically whenever that differs from what's cached (e.g. after
  // a different user logs in).
  // ============================================================
  int? _loadedUserId;

  int get itemCount =>
      _cart?.products.fold<int>(0, (sum, p) => sum + p.quantity) ?? 0;

  Future<void> loadInitial() async {
    final effectiveUserId = await _resolveUserId();

    // Already loaded for this exact user — nothing to do.
    if (_cart != null && _loadedUserId == effectiveUserId) return;

    _loading = true;
    notifyListeners();
    try {
      final cart = await CartService().getCartByUserId(effectiveUserId);
      _cart = cart ?? _emptyCart(effectiveUserId);
      _loadedUserId = effectiveUserId;
    } catch (_) {
      _cart = _emptyCart(effectiveUserId);
      _loadedUserId = effectiveUserId;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Falls back to `demoUserId` only when there's no logged-in user yet
  /// (e.g. a guest browsing before signing in) so the app never crashes
  /// on a missing id — but any real, logged-in user's own id always wins.
  Future<int> _resolveUserId() async {
    final user = await UserService().getUser();
    return user.id != 0 ? user.id : demoUserId;
  }

  /// Call this on logout (see UserService.logout()) so the next person
  /// to log in on this device doesn't briefly see the previous user's
  /// cached cart before the new one loads.
  void reset() {
    _cart = null;
    _loadedUserId = null;
    notifyListeners();
  }

  Cart _emptyCart(int userId) {
    return Cart(
      id: 0,
      products: [],
      total: 0,
      discountedTotal: 0,
      userId: userId,
      totalProducts: 0,
      totalQuantity: 0,
    );
  }

  void addProduct(Product product) {
    final cart = _cart ?? _emptyCart(_loadedUserId ?? demoUserId);
    final index = cart.products.indexWhere((p) => p.id == product.id);
    final updatedProducts = List<CartProduct>.of(cart.products);
    int newQtyForApi;

    if (index == -1) {
      final discountedTotal =
          product.price * (1 - product.discountPercentage / 100);
      updatedProducts.add(
        CartProduct(
          id: product.id,
          title: product.title,
          price: product.price,
          quantity: 1,
          total: product.price,
          discountPercentage: product.discountPercentage,
          discountedTotal: discountedTotal,
          thumbnail: product.thumbnail,
        ),
      );
      newQtyForApi = 1;
    } else {
      final item = updatedProducts[index];
      final newQty = item.quantity + 1;
      updatedProducts[index] = item.copyWith(
        quantity: newQty,
        total: item.price * newQty,
        discountedTotal:
            (item.price * newQty) * (1 - item.discountPercentage / 100),
      );
      newQtyForApi = newQty;
    }

    _cart = cart.copyWith(
      products: updatedProducts,
      total: updatedProducts.fold<double>(0.0, (sum, p) => sum + p.total),
      discountedTotal: updatedProducts.fold<double>(
        0.0,
        (sum, p) => sum + p.discountedTotal,
      ),
    );
    notifyListeners();

    final userId = _loadedUserId ?? demoUserId;
    unawaited(
      CartService()
          .addToCart(
            userId: userId,
            productId: product.id,
            quantity: newQtyForApi,
          )
          .catchError((_) {
            return _cart!;
          }),
    );
  }

  void changeQuantity(int productId, int delta) {
    final cart = _cart;
    if (cart == null) return;
    final index = cart.products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final item = cart.products[index];
    final newQty = item.quantity + delta;
    if (newQty < 1) return;

    final updatedProducts = List<CartProduct>.of(cart.products);
    updatedProducts[index] = item.copyWith(
      quantity: newQty,
      total: item.price * newQty,
      discountedTotal:
          (item.price * newQty) * (1 - item.discountPercentage / 100),
    );

    _cart = cart.copyWith(
      products: updatedProducts,
      total: updatedProducts.fold<double>(0.0, (sum, p) => sum + p.total),
      discountedTotal: updatedProducts.fold<double>(
        0.0,
        (sum, p) => sum + p.discountedTotal,
      ),
    );
    notifyListeners();

    final userId = _loadedUserId ?? demoUserId;
    unawaited(
      CartService()
          .addToCart(userId: userId, productId: productId, quantity: newQty)
          .catchError((_) {
            return _cart!;
          }),
    );
  }
}
