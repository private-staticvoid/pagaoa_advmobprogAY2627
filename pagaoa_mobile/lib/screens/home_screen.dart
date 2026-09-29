import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'product_screen.dart';
import 'cart_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../services/chat_service.dart';
import '../widgets/chat_extras.dart';
import '../widgets/custom_text.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, this.username = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final ChatService _chatService = ChatService();

  // Total unread across every conversation, for the badge on the chat button.
  // Kept as plain state rather than a StreamBuilder so switching tabs can't
  // reset it and make the badge blink.
  StreamSubscription<Map<String, int>>? _unreadSubscription;
  int _unreadTotal = 0;

  @override
  void initState() {
    super.initState();

    final uid = _chatService.currentUserId;
    // DummyJSON accounts have no Firebase uid, so there is nothing to count.
    if (uid.isEmpty) return;

    _unreadSubscription = _chatService.unreadBySender(uid).listen(
      (counts) {
        final total = counts.values.fold<int>(0, (sum, count) => sum + count);
        if (mounted && total != _unreadTotal) {
          setState(() => _unreadTotal = total);
        }
      },
      // Usually the collection group index isn't created yet. The badge just
      // stays hidden rather than breaking the home screen.
      onError: (Object error) {
        debugPrint('[HomeScreen] unread count unavailable: $error');
      },
    );
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  static const int _cartIndex = 1;
  static const int _profileIndex = 2;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          title: _selectedIndex == 0
              ? Image.asset('assets/images/nubdexchange_logo.png', scale: 11.sp)
              : CustomText(
                  text: _selectedIndex == _cartIndex
                      ? 'Cart'
                      : _selectedIndex == _profileIndex
                      ? 'Profile'
                      : 'Home',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const <Widget>[
            ProductScreen(),
            CartScreen(),
            ProfileScreen(),
          ],
          onPageChanged: (page) => setState(() => _selectedIndex = page),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTappedBar,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shop_2), label: 'Shop'),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
        // The chat button opens the chat list and carries the unread badge.
        floatingActionButton: _selectedIndex == _cartIndex ? null : _chatFab(),
      ),
    );
  }

  Widget _chatFab() {
    final fab = FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      ),
      child: const Icon(Icons.chat_bubble_outline),
    );

    if (_unreadTotal <= 0) return fab;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        fab,
        Positioned(right: -2, top: -2, child: UnreadBadge(count: _unreadTotal)),
      ],
    );
  }

  void _onTappedBar(int value) {
    setState(() => _selectedIndex = value);
    _pageController.jumpToPage(value);
  }
}
