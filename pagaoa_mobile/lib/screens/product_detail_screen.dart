import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../widgets/custom_text.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _addingToCart = false;

  Future<void> _addToCart() async {
    setState(() => _addingToCart = true);
    try {
      LocalCartStore.instance.addProduct(widget.product);
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.product.title} added to cart')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not add to cart.')));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final discountedPrice =
        product.price - (product.price * product.discountPercentage / 100);

    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: product.title,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.network(
                  product.thumbnail,
                  height: 220.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220.h,
                    alignment: Alignment.center,
                    child: Icon(Icons.image, size: 48.sp),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              if (product.images.length > 1)
                SizedBox(
                  height: 70.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: product.images.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8.w),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.network(
                          product.images[index],
                          width: 70.w,
                          height: 70.h,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.image, size: 24.sp),
                        ),
                      );
                    },
                  ),
                ),

              SizedBox(height: 16.h),

              CustomText(
                text: product.title,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 4.h),
              CustomText(
                text: '${product.brand} • ${product.category}',
                fontSize: 13.sp,
              ),

              SizedBox(height: 12.h),

              Row(
                children: [
                  if (product.discountPercentage > 0) ...[
                    CustomText(
                      text: '\$${product.price.toStringAsFixed(2)}',
                      fontSize: 14.sp,
                    ),
                    SizedBox(width: 8.w),
                  ],
                  CustomText(
                    text: '\$${discountedPrice.toStringAsFixed(2)}',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  if (product.discountPercentage > 0) ...[
                    SizedBox(width: 8.w),
                    CustomText(
                      text:
                          '-${product.discountPercentage.toStringAsFixed(0)}%',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ],
              ),

              SizedBox(height: 8.h),

              Row(
                children: [
                  Icon(Icons.star, size: 16.sp, color: Colors.amber),
                  SizedBox(width: 4.w),
                  CustomText(
                    text:
                        '${product.rating.toStringAsFixed(1)} • ${product.stock} in stock',
                    fontSize: 13.sp,
                  ),
                ],
              ),

              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addingToCart ? null : _addToCart,
                  icon: _addingToCart
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart),
                  label: CustomText(
                    text: _addingToCart ? 'Adding...' : 'Add to Cart',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 16.h),
              CustomText(
                text: 'Description',
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 4.h),
              CustomText(text: product.description, fontSize: 13.sp),

              SizedBox(height: 16.h),
              CustomText(
                text: 'Shipping & Returns',
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 4.h),
              CustomText(text: product.shippingInformation, fontSize: 13.sp),
              SizedBox(height: 2.h),
              CustomText(text: product.warrantyInformation, fontSize: 13.sp),
              SizedBox(height: 2.h),
              CustomText(text: product.returnPolicy, fontSize: 13.sp),

              SizedBox(height: 16.h),

              if (product.reviews.isNotEmpty) ...[
                CustomText(
                  text: 'Reviews (${product.reviews.length})',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 8.h),
                ...product.reviews.map(
                  (review) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomText(
                                text: review.reviewerName,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.star,
                                size: 14.sp,
                                color: Colors.amber,
                              ),
                              CustomText(
                                text: '${review.rating}',
                                fontSize: 12.sp,
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          CustomText(text: review.comment, fontSize: 13.sp),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
