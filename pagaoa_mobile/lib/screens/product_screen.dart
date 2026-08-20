import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/custom_text.dart';
import 'product_detail_screen.dart';
import '../providers/theme_provider.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final Future<List<Product>> _productsFuture;

  final TextEditingController _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  List<String> _categories = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _productsFuture = ProductService().getAllProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesQuery =
            query.isEmpty || p.title.toLowerCase().contains(query);
        final matchesCategory =
            _selectedCategory == null || p.category == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
    _filterProducts();
  }

  IconData _iconForCategory(String category) {
    final c = category.toLowerCase();

    if (c.contains('furniture')) return Icons.chair_alt;
    if (c.contains('grocery') ||
        c.contains('groceries') ||
        c.contains('food')) {
      return Icons.fastfood;
    }
    if (c.contains('beauty') ||
        c.contains('makeup') ||
        c.contains('skin') ||
        c.contains('fragrance')) {
      return Icons.brush;
    }
    if (c.contains('smartphone') ||
        c.contains('mobile') ||
        c.contains('phone')) {
      return Icons.smartphone;
    }
    if (c.contains('laptop') ||
        c.contains('tablet') ||
        c.contains('computer')) {
      return Icons.laptop_mac;
    }
    if (c.contains('watch')) return Icons.watch;
    if (c.contains('shoe') || c.contains('sneaker')) return Icons.snowshoeing;
    if (c.contains('bag')) return Icons.shopping_bag;
    if (c.contains('jewel')) return Icons.diamond;
    if (c.contains('dress') ||
        c.contains('shirt') ||
        c.contains('top') ||
        c.contains('cloth')) {
      return Icons.checkroom;
    }
    if (c.contains('sunglass') || c.contains('glasses')) return Icons.sunny;
    if (c.contains('decor') || c.contains('home')) return Icons.chair;
    if (c.contains('kitchen')) return Icons.kitchen;
    if (c.contains('vehicle') ||
        c.contains('motorcycle') ||
        c.contains('car')) {
      return Icons.directions_car;
    }
    if (c.contains('electronic')) return Icons.devices_other;
    if (c.contains('toy')) return Icons.toys;
    if (c.contains('book')) return Icons.menu_book;
    if (c.contains('sport')) return Icons.sports_soccer;

    return Icons.category;
  }

  String _labelForCategory(String category) {
    return category
        .split(RegExp(r'[-_]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = selected
        ? colorScheme.primary
        : (isDark ? colorScheme.surfaceContainerHighest : Colors.white);
    final Color borderColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final Color iconBadgeColor = selected
        ? AppColors.gold
        : (isDark ? Colors.white : colorScheme.primary.withValues(alpha: 0.10));
    final Color iconColor = selected ? Colors.black87 : colorScheme.primary;
    final Color textColor = selected
        ? (isDark ? Colors.white : Colors.white)
        : (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 6.w,
            right: 14.w,
            top: 6.h,
            bottom: 6.h,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26.w,
                height: 26.w,
                decoration: BoxDecoration(
                  color: iconBadgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.sp, color: iconColor),
              ),
              SizedBox(width: 8.w),
              CustomText(
                text: label,
                fontSize: 13.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: ScreenUtil().screenWidth,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(fontSize: 14.sp),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, size: 20.sp),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear, size: 18.sp),
                          onPressed: () => _searchController.clear(),
                        ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.r),
                      child: const CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: CustomText(
                      text: 'Error: ${snapshot.error}',
                      fontSize: 14.sp,
                    ),
                  );
                }

                if (_allProducts.isEmpty && snapshot.data != null) {
                  _allProducts = snapshot.data!;
                  _categories =
                      _allProducts.map((p) => p.category).toSet().toList()
                        ..sort();

                  final query = _searchController.text.trim().toLowerCase();
                  _filteredProducts = _allProducts.where((p) {
                    final matchesQuery =
                        query.isEmpty || p.title.toLowerCase().contains(query);
                    final matchesCategory =
                        _selectedCategory == null ||
                        p.category == _selectedCategory;
                    return matchesQuery && matchesCategory;
                  }).toList();
                }

                final products = _filteredProducts;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_categories.isNotEmpty) ...[
                      SizedBox(
                        height: 40.h,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildCategoryChip(
                              label: 'All',
                              icon: Icons.apps,
                              context: context,
                              selected: _selectedCategory == null,
                              onTap: () => _onCategorySelected(null),
                            ),
                            ..._categories.map(
                              (category) => _buildCategoryChip(
                                label: _labelForCategory(category),
                                icon: _iconForCategory(category),
                                context: context,
                                selected: _selectedCategory == category,
                                onTap: () => _onCategorySelected(category),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    if (products.isEmpty)
                      Center(
                        child: CustomText(
                          text: 'No products found.',
                          fontSize: 14.sp,
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10.w,
                          mainAxisSpacing: 10.h,
                          childAspectRatio: 0.75,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProductDetailScreen(product: product),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 2,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Image.network(
                                      product.thumbnail,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Center(
                                              child: Icon(
                                                Icons.image,
                                                size: 24.sp,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.r),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CustomText(
                                          text: product.title,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        CustomText(
                                          text:
                                              '\$${product.price.toStringAsFixed(2)}',
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
