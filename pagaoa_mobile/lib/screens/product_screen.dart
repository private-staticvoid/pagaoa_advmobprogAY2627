import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Models
import '../models/product.dart';

// Services
import '../services/product_service.dart';

// Widgets
import '../widgets/custom_text.dart';

// Screens
import 'product_detail_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final Future<List<Product>> _productsFuture;

  // ENHANCEMENT 1 (Search bar): controller for the search field.
  final TextEditingController _searchController = TextEditingController();

  // ENHANCEMENT 1 (Search bar): _allProducts caches the full list once
  // fetched so we can filter locally instead of re-hitting the API on
  // every keystroke. _filteredProducts is what's actually shown.
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _productsFuture = ProductService().getAllProducts();

    // ENHANCEMENT 1 (Search bar): re-filter whenever the text changes.
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ENHANCEMENT 1 (Search bar): case-insensitive filter by product title.
  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredProducts = query.isEmpty
          ? _allProducts
          : _allProducts
                .where((p) => p.title.toLowerCase().contains(query))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENHANCEMENT 1 (Search bar): the old static "Search" box is
            // now a real TextField bound to _searchController above.
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

                // ENHANCEMENT 1 (Search bar): populate the cache the first
                // time the future resolves, respecting whatever is already
                // typed in the search box.
                if (_allProducts.isEmpty && snapshot.data != null) {
                  _allProducts = snapshot.data!;
                  final query = _searchController.text.trim().toLowerCase();
                  _filteredProducts = query.isEmpty
                      ? _allProducts
                      : _allProducts
                            .where((p) => p.title.toLowerCase().contains(query))
                            .toList();
                }

                final products = _filteredProducts;

                if (products.isEmpty) {
                  return Center(
                    child: CustomText(
                      text: 'No products found.',
                      fontSize: 14.sp,
                    ),
                  );
                }

                return GridView.builder(
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

                    // ENHANCEMENT 2 (Details page): wrap the card in a
                    // GestureDetector so tapping it opens the new
                    // ProductDetailScreen, passing the tapped product.
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
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.image, size: 24.sp),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
