import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../services/cart_service.dart';
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

  // ENHANCEMENT: local-mutation helper. DummyJSON's cart-mutation endpoints
  // are simulated and don't persist, so the UI updates this local copy
  // directly instead of trusting a re-fetch.
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

/// ENHANCEMENT: single in-memory source of truth for the cart while the
/// app is open. DummyJSON's POST /carts/add is simulated and never
/// actually persists server-side, so CartScreen and ProductDetailScreen
/// both read/write through here instead of trusting a re-fetch after
/// every change.
///
/// This is the state-management piece: it's a ChangeNotifier, any widget
/// that wraps itself in an AnimatedBuilder (or ListenableBuilder) listening
/// to `LocalCartStore.instance` gets rebuilt automatically the moment the
/// cart changes — whether the change came from the Cart tab's own stepper
/// buttons or from tapping "Add to Cart" on a totally different screen.
class LocalCartStore extends ChangeNotifier {
  LocalCartStore._internal();
  static final LocalCartStore instance = LocalCartStore._internal();

  Cart? _cart;
  Cart? get cart => _cart;

  bool _loading = false;
  bool get loading => _loading;

  /// Total item count across the cart, handy for a badge on the cart icon.
  int get itemCount =>
      _cart?.products.fold<int>(0, (sum, p) => sum + p.quantity) ?? 0;

  Future<void> loadInitial() async {
    if (_cart != null) return; // already loaded once this session
    _loading = true;
    notifyListeners();
    try {
      final cart = await CartService().getCartByUserId(demoUserId);
      _cart = cart ?? _emptyCart();
    } catch (_) {
      _cart = _emptyCart();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Cart _emptyCart() {
    return Cart(
      id: 0,
      products: [],
      total: 0,
      discountedTotal: 0,
      userId: demoUserId,
      totalProducts: 0,
      totalQuantity: 0,
    );
  }

  // ENHANCEMENT: called from ProductDetailScreen's "Add to Cart" button.
  // Adds the product if it's not already in the cart, or bumps quantity
  // by 1 if it already is. Updates local state immediately (so the Cart
  // tab reflects it right away) and fires the API call in the background.
  void addProduct(Product product) {
    final cart = _cart ?? _emptyCart();
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

    unawaited(
      CartService()
          .addToCart(
            userId: demoUserId,
            productId: product.id,
            quantity: newQtyForApi,
          )
          .catchError((_) {
            return _cart!;
          }),
    );
  }

  // ENHANCEMENT: quantity stepper in CartScreen.
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

    unawaited(
      CartService()
          .addToCart(userId: demoUserId, productId: productId, quantity: newQty)
          .catchError((_) {
            return _cart!;
          }),
    );
  }
}
