// ENHANCEMENT 3 — Profile screen
//   Reads the saved session via UserService.getUser() typed User (models/user.dart).
//   All the header/detail UI below renders from that instance.
//   Based on the saved user data render the cart by userId": listens
//   to the project's real LocalCartStore (models/cart.dart), which now
//   resolves the logged-in user's own id internally (see the
//   loadInitial()/_resolveUserId() patch in models/cart.dart) instead
//   of the old hardcoded demoUserId. Same store the Cart tab uses, so
//   both stay in sync automatically.
//

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pagaoa_mobile/providers/theme_provider.dart';

import '../models/cart.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();

  User? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Store resolves the current userId itself and is a no-op if
    // already cached for this user (see LocalCartStore.loadInitial()).
    LocalCartStore.instance.loadInitial();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Log out',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _userService
        .logout(); // also resets LocalCartStore, see user_service.dart
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _user ?? User.empty();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUser();
        LocalCartStore.instance.reset();
        await LocalCartStore.instance.loadInitial();
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Header card: avatar + name + username, from User model.
          Card(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44.r,
                    backgroundColor: AppColors.maroonLight,
                    backgroundImage: user.image.isNotEmpty
                        ? NetworkImage(user.image)
                        : null,
                    child: user.image.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 44.sp,
                            color: AppColors.maroon,
                          )
                        : null,
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : user.username,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Details card
          Card(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email,
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.wc_outlined,
                    label: 'Gender',
                    value: user.gender,
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'User ID',
                    value: '#${user.id}',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Cart-by-userId summary — driven by the shared LocalCartStore.
          Text(
            'Your Cart Summary',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.maroon,
            ),
          ),
          SizedBox(height: 8.h),
          AnimatedBuilder(
            animation: LocalCartStore.instance,
            builder: (context, _) => _buildCartSummary(LocalCartStore.instance),
          ),
          SizedBox(height: 24.h),

          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(LocalCartStore store) {
    if (store.loading && store.cart == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    final cart = store.cart;

    if (cart == null || cart.products.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade500),
              SizedBox(width: 10.w),
              Text(
                'No cart found for this user yet.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart #${cart.id}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${cart.totalProducts} items · ${cart.totalQuantity} qty',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ...cart.products
                .take(3)
                .map(
                  (p) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 3.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.title}  x${p.quantity}',
                            style: TextStyle(fontSize: 12.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${p.discountedTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (cart.products.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(
                  '+ ${cart.products.length - 3} more item(s)',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '\$${cart.discountedTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.maroon,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.gold),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
