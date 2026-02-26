import 'package:festival_rumour/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/custom_navbar.dart';
import '../discover/discover_view.dart';
import '../rumors/rumors_view.dart';
import '../detail/detail_view.dart';
import '../chat/chat_view.dart';
import '../map/map_view.dart';
import '../news/news_view.dart';
import '../posts/posts_view.dart';
import '../Profile/profilelist/profile_list_view.dart';
import '../toilet/toilet_view.dart';
import 'navbaar_view_model.dart';

class NavBaar extends BaseView<NavBaarViewModel> {
  const NavBaar({super.key});

  @override
  NavBaarViewModel createViewModel() => NavBaarViewModel();

  @override
  Widget buildView(BuildContext context, NavBaarViewModel viewModel) {
    return WillPopScope(
      onWillPop: () async {
        // Rumours (index 1): device back → switch to Discover tab
        if (viewModel.currentIndex == 1) {
          viewModel.goToDiscover();
          return false;
        }
        // Discover (index 0): device back → navigate to Festival screen
        viewModel.navigateToFestival();
        return false;
      },
      child: Scaffold(
        body: _NavBarBody(viewModel: viewModel),
        bottomNavigationBar: Selector<NavBaarViewModel, String?>(
          selector: (_, vm) => vm.subNavigation,
          builder: (context, subNavigation, child) {
            final vm = Provider.of<NavBaarViewModel>(context, listen: false);
            return _shouldHideNavBar(subNavigation)
                ? const SizedBox.shrink()
                : CustomNavBar(
                    currentIndex: vm.currentIndex,
                    onTap: vm.setIndex,
                  );
          },
        ),
      ),
    );
  }

  static bool _shouldHideNavBar(String? subNavigation) {
    return subNavigation == 'toilets' || 
           subNavigation == 'news' ||
           subNavigation == 'performance' ||
           subNavigation == 'event';
  }
}

/// Body widget that manages cached view instances and IndexedStack
class _NavBarBody extends StatefulWidget {
  final NavBaarViewModel viewModel;
  
  const _NavBarBody({required this.viewModel});
  
  @override
  State<_NavBarBody> createState() => _NavBarBodyState();
}

class _NavBarBodyState extends State<_NavBarBody> {
  // Cache view instances to prevent recreation
  late final List<Widget> _cachedMainViews;
  final Map<String, Widget> _cachedSubViews = {};
  
  @override
  void initState() {
    super.initState();
    // Pre-create and cache main tab views
    _cachedMainViews = [
      DiscoverView(
        onBack: widget.viewModel.navigateToFestival,
        onNavigateToSub: widget.viewModel.setSubNavigation,
      ),
      RumorsView(
        onBack: () {

          widget.viewModel.goToDiscover();
        },
      ),
    ];
    
    // Pre-initialize adjacent tabs in background
    _preInitializeTabs();
  }
  
  /// Pre-initialize adjacent tabs for faster switching
  void _preInitializeTabs() {
    // This allows views to prepare in background
    Future.microtask(() {
      // Views will initialize when first accessed
      // This is just to ensure they're created
    });
  }
  
  Widget _buildSubNavigation(NavBaarViewModel viewModel) {
    final subNav = viewModel.subNavigation;
    if (subNav == null) return const SizedBox.shrink();
    
    // Cache sub-navigation views
    if (!_cachedSubViews.containsKey(subNav)) {
      switch (subNav) {
        case 'detail':
          _cachedSubViews[subNav] = DetailView(
            onBack: () => viewModel.setSubNavigation(null),
            onNavigateToSub: viewModel.setSubNavigation,
          );
          break;
        case 'chat':
          _cachedSubViews[subNav] = ChatView(onBack: () => viewModel.setSubNavigation(null));
          break;
        case 'map':
          _cachedSubViews[subNav] = MapView(onBack: () => viewModel.setSubNavigation(null));
          break;
        case 'news':
          _cachedSubViews[subNav] = NewsView(onBack: () => viewModel.setSubNavigation(null));
          break;
        case 'posts':
          _cachedSubViews[subNav] = PostsView(onBack: () => viewModel.setSubNavigation(null));
          break;
        case 'toilets':
          _cachedSubViews[subNav] = ToiletView(onBack: () => viewModel.setSubNavigation(null));
          break;
        case 'followers':
          _cachedSubViews[subNav] = ProfileListView(
            initialTab: 0,
            Username: AppStrings.name,
            onBack: () => viewModel.setSubNavigation(null),
          );
          break;
        case 'following':
          _cachedSubViews[subNav] = ProfileListView(
            initialTab: 1,
            Username: AppStrings.name,
            onBack: () => viewModel.setSubNavigation(null),
          );
          break;
        case 'festivals':
          _cachedSubViews[subNav] = ProfileListView(
            initialTab: 2,
            Username: AppStrings.name,
            onBack: () => viewModel.setSubNavigation(null),
          );
          break;
        case 'attended':
          _cachedSubViews[subNav] = ProfileListView(
            initialTab: 3,
            Username: AppStrings.name,
            onBack: () => viewModel.setSubNavigation(null),
          );
          break;
        default:
          _cachedSubViews[subNav] = DiscoverView(
            onBack: viewModel.navigateToFestival,
            onNavigateToSub: viewModel.setSubNavigation,
          );
      }
    }
    
    return _cachedSubViews[subNav]!;
  }
  
  @override
  Widget build(BuildContext context) {
    return Selector<NavBaarViewModel, String?>(
      selector: (_, vm) => vm.subNavigation,
      builder: (context, subNavigation, child) {
        final viewModel = Provider.of<NavBaarViewModel>(context, listen: false);
        
        // Handle sub-navigation first
        if (subNavigation != null) {
          return _buildSubNavigation(viewModel);
        }
        
        // Use IndexedStack to keep all tabs alive
        return Selector<NavBaarViewModel, int>(
          selector: (_, vm) => vm.currentIndex,
          builder: (context, currentIndex, child) {
            return IndexedStack(
              index: currentIndex,
              children: _cachedMainViews,
            );
          },
        );
      },
    );
  }
}
