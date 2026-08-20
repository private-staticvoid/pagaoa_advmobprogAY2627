import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pagaoa_mobile/providers/theme_provider.dart';

import '../models/cart.dart';
import '../services/product_service.dart';
import '../widgets/custom_text.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    LocalCartStore.instance.loadInitial();
  }

  Future<void> _refresh() async {
    setState(() {});
  }

  Future<void> _openDetail(int productId) async {
    try {
      final product = await ProductService().getProductById(productId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open product details.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: LocalCartStore.instance,
      builder: (context, _) {
        final store = LocalCartStore.instance;

        if (store.loading && store.cart == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final cart = store.cart;
        if (cart == null || cart.products.isEmpty) {
          return _emptyState('Your cart is empty.');
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: cart.products.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final item = cart.products[index];

                    return GestureDetector(
                      onTap: () => _openDetail(item.id),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: Image.network(
                                  item.thumbnail,
                                  width: 64.w,
                                  height: 64.w,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 64.w,
                                    height: 64.w,
                                    color: colorScheme.primaryContainer,
                                    child: const Icon(Icons.image),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText(
                                      text: item.title,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    CustomText(
                                      text:
                                          '\$${item.price.toStringAsFixed(2)}',
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gold,
                                    ),
                                    SizedBox(height: 2.h),
                                    CustomText(
                                      text:
                                          '${item.discountPercentage.toStringAsFixed(0)}% off • \$${item.discountedTotal.toStringAsFixed(2)} total',
                                      fontSize: 11.sp,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _stepperButton(
                                    icon: Icons.add,
                                    onTap: () => LocalCartStore.instance
                                        .changeQuantity(item.id, 1),
                                  ),
                                  SizedBox(height: 4.h),
                                  CustomText(
                                    text: '${item.quantity}',
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(height: 4.h),
                                  _stepperButton(
                                    icon: Icons.remove,
                                    filled: false,
                                    onTap: () => LocalCartStore.instance
                                        .changeQuantity(item.id, -1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _summaryBar(cart),
            ],
          ),
        );
      },
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26.w,
        height: 26.w,
        decoration: BoxDecoration(
          color: filled ? AppColors.gold : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16.sp, color: Colors.black87),
      ),
    );
  }

  Widget _summaryBar(dynamic cart) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText(text: 'Subtotal', fontSize: 14.sp),
                CustomText(
                  text: '\$${cart.discountedTotal.toStringAsFixed(2)}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: CustomText(
                  text: 'Confirm Order',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 48.sp,
                  color: Colors.grey,
                ),
                SizedBox(height: 8.h),
                CustomText(text: message, fontSize: 14.sp, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
