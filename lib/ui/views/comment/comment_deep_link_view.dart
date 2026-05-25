import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/firestore_service.dart';
import '../homeview/post_model.dart';

/// Resolves `postId` + `collectionName` from a notification into [CommentView].
class CommentDeepLinkView extends StatefulWidget {
  const CommentDeepLinkView({super.key});

  @override
  State<CommentDeepLinkView> createState() => _CommentDeepLinkViewState();
}

class _CommentDeepLinkViewState extends State<CommentDeepLinkView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openComments());
  }

  Future<void> _openComments() async {
    final raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is! Map) {
      _goFallback();
      return;
    }
    final args = Map<String, dynamic>.from(raw);
    final postId = args['postId'] as String?;
    final collectionName = args['collectionName'] as String?;
    final focusCommentId = args['focusCommentId'] as String?;

    if (postId == null ||
        postId.isEmpty ||
        collectionName == null ||
        collectionName.isEmpty) {
      _goFallback();
      return;
    }

    try {
      final firestore = locator<FirestoreService>();
      final map = await firestore.getPostById(
        postId: postId,
        collectionName: collectionName,
      );
      if (!mounted) return;
      if (map == null) {
        _goFallback();
        return;
      }
      final post = PostModel.fromFirestore(
        _PostDocMap(postId, map),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.comments,
        arguments: <String, dynamic>{
          'post': post,
          'collectionName': collectionName,
          if (focusCommentId != null && focusCommentId.isNotEmpty)
            'focusCommentId': focusCommentId,
        },
      );
    } catch (_) {
      _goFallback();
    }
  }

  void _goFallback() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.festivals);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.black),
      ),
    );
  }
}

/// Minimal stand-in for Firestore document for [PostModel.fromFirestore].
class _PostDocMap {
  _PostDocMap(this._docId, this.dataMap);

  final String _docId;
  final Map<String, dynamic> dataMap;

  dynamic data() => dataMap;

  String get id => _docId;

  String? get docId => _docId;
}
