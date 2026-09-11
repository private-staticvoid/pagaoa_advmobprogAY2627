// Profile screen (Lab 4, updated for Lab 5 — Enhancement 3)
//   * Loads the session via UserService().getUserData() -> User.fromJson
//   * Shows different details depending on the LoginType:
//       Firebase  -> UID, age, contact no, email, member since
//       DummyJSON -> User ID, age, contact no, gender (read-only demo user)
//   * Firebase accounts can: update username, change password, delete account
//   * Logout (also available in Settings)
//   * Cart summary by userId (Lab 4) — still driven by LocalCartStore.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../models/login_type.dart';
import '../models/user.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../widgets/account_dialogs.dart';

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
    LocalCartStore.instance.loadInitial();
  }

  Future<void> _loadUser() async {
    // Handout: "Fetch user data via UserService().getUserData()".
    final data = await _userService.getUserData();
    if (!mounted) return;
    setState(() {
      _user = User.fromJson(data);
      _loadingUser = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToSignIn() {
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  // ---------------- Account actions (Firebase only) ----------------

  Future<void> _updateUsername(User user) async {
    final ok = await showUpdateUsernameDialog(
      context,
      currentUsername: user.username,
    );
    if (!ok || !mounted) return;
    await _loadUser();
    _toast('Username updated');
  }

  Future<void> _changePassword(User user) async {
    final ok = await showChangePasswordDialog(context, email: user.email);
    if (!ok || !mounted) return;
    _toast('Password changed successfully');
  }

  Future<void> _deleteAccount(User user) async {
    final ok = await showDeleteAccountDialog(context, email: user.email);
    if (!ok || !mounted) return;
    _toast('Account deleted');
    _goToSignIn();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Log out',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _userService.logout(); // Firebase signOut + clear prefs + cart
    if (!mounted) return;
    _goToSignIn();
  }

  // ------------------------------- UI -------------------------------

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
          _buildHeader(user),
          SizedBox(height: 16.h),
          _buildDetails(user),
          SizedBox(height: 16.h),
          _sectionTitle('Account'),
          SizedBox(height: 8.h),
          user.isFirebase ? _buildFirebaseActions(user) : _buildDummyNote(),
          SizedBox(height: 16.h),
          _sectionTitle('Your Cart Summary'),
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

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 15.sp,
      fontWeight: FontWeight.w700,
      color: AppColors.maroon,
    ),
  );

  Widget _buildHeader(User user) {
    final initials = [
      user.firstName,
      user.lastName,
    ].where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).join();

    return Card(
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
                  ? (initials.isNotEmpty
                        ? Text(
                            initials,
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.maroon,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 44.sp,
                            color: AppColors.maroon,
                          ))
                  : null,
            ),
            SizedBox(height: 14.h),
            Text(
              user.fullName.isNotEmpty ? user.fullName : user.username,
              style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
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
            SizedBox(height: 10.h),
            // LoginType badge
            Chip(
              avatar: Icon(
                user.isFirebase
                    ? Icons.local_fire_department
                    : Icons.cloud_outlined,
                size: 16.sp,
                color: user.isFirebase ? Colors.deepOrange : Colors.blueGrey,
              ),
              label: Text(
                'Signed in with ${user.loginType.label}',
                style: TextStyle(fontSize: 11.sp),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(User user) {
    final rows = <_InfoRow>[
      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
      _InfoRow(
        icon: Icons.cake_outlined,
        label: 'Age',
        value: user.age > 0 ? '${user.age}' : '',
      ),
      _InfoRow(
        icon: Icons.phone_outlined,
        label: 'Contact No.',
        value: user.phone,
      ),
      _InfoRow(icon: Icons.wc_outlined, label: 'Gender', value: user.gender),
      if (user.isFirebase) ...[
        _InfoRow(
          icon: Icons.fingerprint,
          label: 'Firebase UID',
          value: user.uid,
        ),
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Member since',
          value: _memberSince(),
        ),
      ] else
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'User ID',
          value: '#${user.id}',
        ),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  /// Firebase keeps the account creation time in user.metadata.
  String _memberSince() {
    final created = _userService.currentUser?.metadata.creationTime;
    if (created == null) return '';
    final d = created.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Widget _buildFirebaseActions(User user) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.gold),
            title: const Text('Update username'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _updateUsername(user),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppColors.gold),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(user),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
            title: Text(
              'Delete account',
              style: TextStyle(color: Colors.red.shade400),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _deleteAccount(user),
          ),
        ],
      ),
    );
  }

  /// DummyJSON users are shared demo accounts on a mock API, so there's
  /// nothing real to update or delete.
  Widget _buildDummyNote() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blueGrey, size: 20.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'This is a read-only DummyJSON demo account. Updating the '
                'username, changing the password and deleting the account '
                'are available for Firebase accounts — sign up with Firebase '
                'to try them.',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
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
