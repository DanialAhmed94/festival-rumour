import 'package:festival_rumour/ui/views/username/username_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/views/forgot_password/forgot_password_view.dart';
import '../../ui/views/jobdetail/festivals_job_view.dart';
import '../../ui/views/jobpost/festivals_job_post_view.dart';
import '../../ui/views/signup/signupphone/signup_view.dart';
import '../../ui/views/username/username_view.dart';
import '../../ui/views/viewall/viewall_view.dart';
import '../constants/app_strings.dart';
import '../../ui/views/Profile/profile_view.dart';
import '../../ui/views/Profile/profilelist/profile_list_view.dart';
import '../../ui/views/Splash/SplashView.dart';
import '../../ui/views/chat/chat_view.dart';
import '../../ui/views/comment/comment_view.dart';
import '../../ui/views/detail/detail_view.dart';
import '../../ui/views/discover/discover_view.dart';
import '../../ui/views/event/event_view.dart';
import '../../ui/views/festival/festival_view.dart';
import '../../ui/views/homeview/home_view.dart';
import '../../ui/views/interest/interests_view.dart';
import '../../ui/views/name/name_view.dart';
import '../../ui/views/navbar/navbaar.dart';
import '../../ui/views/news/news_view.dart';
import '../../ui/views/notification/notification_view.dart';
import '../../ui/views/otp/otp_view.dart';
import '../../ui/views/performance/performance_view.dart';
import '../../ui/views/toilet/toilet_view.dart';
import '../../ui/views/uploadphotos/upload_photos_view.dart';
import '../../ui/views/welcome/welcome_view.dart';
import '../../ui/views/signup/signupemail/signup_viewemail.dart';
import '../../ui/views/map/map_view.dart';
import '../../ui/views/subscription/subscription_view.dart';
import '../../ui/views/settings/settings_view.dart';
import '../../ui/views/settings/edit_account_view.dart';
import '../../ui/views/leaderboard/leaderboard_view.dart';
import '../../ui/views/posts/posts_view.dart';
import '../../ui/views/chat/create_chat_room_view.dart';
import '../../ui/views/rumors/rumors_view.dart';
import '../../ui/views/test/firebase_test_view.dart';
import '../../ui/views/create_post/create_post_view.dart';
import '../../ui/views/search_users/search_users_view.dart';
import '../../ui/views/Profile/view_user_profile_view.dart';
import '../../ui/views/homeview/post_model.dart';
import '../utils/transition.dart';

class AppRoutes {
  static const String welcome = '/welcome';
  static const String signup = '/signup';
  static const String signupEmail = '/signup_email';
  static const String uploadphotos = '/uploadphotos';
  static const String name = '/name';
  static const String otp = '/otp';
  static const String splash = '/splash';
  static const String interest = '/interest';
  static const String home = '/home';
  static const String navbaar = '/navbaar';
  static const String festivals = '/festivals';
  static const String subscription = '/subscription';
  static const String chat = '/chat';
  static const String map = '/map';
  static const String notification = '/notification';
  static const String settings = '/settings';
  static const String editAccount = '/edit_account';
  static const String leaderboard = '/leaderboard';
  static const String comments = '/comments';
  static const String profileList = '/profileList';
  static const String username = '/username';
  static const String profile = '/profile';
  static const String festivalsJob = '/festivals_job';
  static const String discover = '/discover';
  static const String posts = '/posts';
  static const String detail = '/detail';
  static const String chatRoom = '/chat_room';
  static const String createChatRoom = '/create_chat_room';
  static const String toilets = '/toilets';
  static const String performance = '/performance';
  static const String event = '/event';
  static const String news = '/news';
  static const String rumors = '/rumors';
  static const String jobpost = '/jobpost';
  static const String firebaseTest = '/firebase_test';
  static const String photoUpload = '/photo_upload';
  static const String viewAll = '/view_all';
  static const String forgotpassword = '/forgot_password';
  static const String createPost = '/create_post';
  static const String searchUsers = '/search_users';
  static const String viewUserProfile = '/view_user_profile';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.welcome:
      return SmoothPageRoute(page: const WelcomeView());

    case AppRoutes.splash:
      return SmoothPageRoute(page: const SplashView());

    case AppRoutes.signup:
      return SmoothPageRoute(page: const SignupView());

    case AppRoutes.signupEmail:
      return SmoothPageRoute(page: const SignupViewEmail());

    case AppRoutes.uploadphotos:
      return SmoothPageRoute(page: const UploadPhotosViews());

    case AppRoutes.name:
      return SmoothPageRoute(page: const NameView());

    case AppRoutes.festivals:
      // final args = settings.arguments as List<dynamic>;
      return SmoothPageRoute(page: const FestivalView());

    case AppRoutes.otp:
      return SmoothPageRoute(page: OtpView());

    case AppRoutes.interest:
      return SmoothPageRoute(page: const InterestsView());

    case AppRoutes.home:
      return SmoothPageRoute(page: const HomeView());

    case AppRoutes.navbaar:
      return SmoothPageRoute(page: const NavBaar());

    case AppRoutes.subscription:
      return SmoothPageRoute(page: const SubscriptionView());

    case AppRoutes.chat:
      return SmoothPageRoute(page: const ChatView());

    case AppRoutes.map:
      return SmoothPageRoute(page: const MapView());

    case AppRoutes.notification:
      return SmoothPageRoute(page: const NotificationView());

    case AppRoutes.settings:
      return SmoothPageRoute(page: const SettingsView());

    case AppRoutes.editAccount:
      return SmoothPageRoute(page: const EditAccountView());

    case AppRoutes.leaderboard:
      return SmoothPageRoute(page: const LeaderboardView());

    case AppRoutes.comments:
      // Arguments can be PostModel or Map with 'post' and 'collectionName'
      dynamic args = settings.arguments;
      PostModel? post;
      String? collectionName;

      if (args is Map) {
        post = args['post'] as PostModel?;
        collectionName = args['collectionName'] as String?;
      } else {
        post = args as PostModel?;
      }

      return SmoothPageRoute(
        page: CommentView(post: post, collectionName: collectionName),
        settings: RouteSettings(
          name: AppRoutes.comments,
          arguments:
              collectionName, // Pass collection name for CommentViewModel
        ),
      );

    case AppRoutes.discover:
      return SmoothPageRoute(page: const DiscoverView());

    case AppRoutes.username:
      return SmoothPageRoute(page: const UsernameView());

    case AppRoutes.festivalsJob:
      return SmoothPageRoute(page: const FestivalsJobView());

    case AppRoutes.jobpost:
      return SmoothPageRoute(page: const FestivalsJobPostView());

    case AppRoutes.profile:
      // Arguments can be:
      // - String: userId to view another user's profile
      // - Map: {'userId': String, 'fromRoute': String?} for navigation tracking
      String? userId;
      String? fromRoute;
      
      if (settings.arguments is Map) {
        final args = settings.arguments as Map<String, dynamic>;
        userId = args['userId'] as String?;
        fromRoute = args['fromRoute'] as String?;
      } else if (settings.arguments is String) {
        userId = settings.arguments as String;
      }
      
      return SmoothPageRoute(
        page: ProfileView(
          userId: userId,
          fromRoute: fromRoute, // Pass the route we came from
        ),
      );

    case AppRoutes.profileList:
      // Arguments can be:
      // - int: initialTab (0 = Followers, 1 = Following, 2 = Festivals)
      // - Map: {'initialTab': int, 'username': String, 'userId': String?}
      int initialTab = 0;
      String username = 'username';
      String? userId;
      
      if (settings.arguments is Map) {
        final args = settings.arguments as Map<String, dynamic>;
        initialTab = args['initialTab'] as int? ?? 0;
        username = args['username'] as String? ?? 'username';
        userId = args['userId'] as String?;
        
        if (kDebugMode) {
          print('🔍 [AppRouter.profileList] Parsing arguments:');
          print('   initialTab: $initialTab');
          print('   username: $username');
          print('   userId: $userId');
          print('   args: $args');
        }
      } else if (settings.arguments is int) {
        initialTab = settings.arguments as int;
      }
      
      if (kDebugMode) {
        print('📱 [AppRouter.profileList] Creating ProfileListView');
        print('   initialTab: $initialTab');
        print('   username: $username');
        print('   userId: $userId');
      }
      
      return SmoothPageRoute(
        page: ProfileListView(initialTab: initialTab, Username: username, userId: userId),
      );

    case AppRoutes.posts:
      return SmoothPageRoute(page: const PostsView());

    case AppRoutes.detail:
      return SmoothPageRoute(page: const DetailView());

    case AppRoutes.chatRoom:
      // Arguments can be chat room ID (String)
      final chatRoomId = settings.arguments as String?;
      return SmoothPageRoute(
        page: const ChatView(),
        settings: RouteSettings(
          name: AppRoutes.chatRoom,
          arguments: chatRoomId, // Pass chat room ID to ChatView
        ),
      );

    case AppRoutes.createChatRoom:
      return SmoothPageRoute(page: const CreateChatRoomView());

    case AppRoutes.toilets:
      return SmoothPageRoute(page: const ToiletView());

    case AppRoutes.performance:
      return SmoothPageRoute(page: const PerformanceView());

    case AppRoutes.event:
      return SmoothPageRoute(page: const EventView());

    case AppRoutes.news:
      return SmoothPageRoute(page: const NewsView());

    case AppRoutes.rumors:
      return SmoothPageRoute(page: const RumorsView());

    case AppRoutes.firebaseTest:
      return SmoothPageRoute(page: const FirebaseTestView());

    case AppRoutes.photoUpload:
      return SmoothPageRoute(page: const UploadPhotosViews());

    case AppRoutes.forgotpassword:
      return SmoothPageRoute(page: const ForgotPasswordView());

    case AppRoutes.viewAll:
      final initialTab = settings.arguments as int?;
      return SmoothPageRoute(page: ViewAllView(initialTab: initialTab));

    case AppRoutes.createPost:
      // Arguments can be collection name (String) when called from rumors context
      final collectionName = settings.arguments as String?;
      final view = CreatePostView();
      // Initialize viewModel with collection name if provided
      if (collectionName != null) {
        // The viewModel will be initialized in the view's onViewModelReady
        // We'll pass it through a custom route or handle it in the view
      }
      return SmoothPageRoute(
        page: view,
        settings: RouteSettings(
          name: AppRoutes.createPost,
          arguments: collectionName, // Pass collection name as arguments
        ),
      );

    case AppRoutes.searchUsers:
      return SmoothPageRoute(page: const SearchUsersView());

    case AppRoutes.viewUserProfile:
      // Arguments should be userId (String) to view another user's profile
      final userId = settings.arguments as String?;
      if (userId == null) {
        // If no userId provided, return to home or show error
        return SmoothPageRoute(page: const HomeView());
      }
      return SmoothPageRoute(
        page: ViewUserProfileView(userId: userId),
      );

    default:
      final name = settings.name?.toLowerCase() ?? "";

      // Ignore Firebase Phone Auth internal routes safely
      if (name.contains("auth") ||
          name.contains("firebase") ||
          name.contains("recaptcha") ||
          name.contains("callback") ||
          name.contains("handler") ||
          name.contains("complete") ||
          name.contains("apple-app-site-association") ||
          name.contains("favicon") ||
          name.isEmpty ||
          name == "/" ||
          name == "null") {
        // Return invisible route – keeps current UI visible
        return EmptyRoute();
      }

      // Unknown routes → also ignore
      return EmptyRoute();
  }
}

class EmptyRoute extends PageRoute<void> {
  EmptyRoute() {
    // pop this route immediately after pushing it
    Future.microtask(() {
      navigator?.pop();
    });
  }

  @override
  bool get opaque => false; // fully transparent

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => Duration(milliseconds: 1);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const SizedBox.shrink(); // shown for <1ms
  }
}
