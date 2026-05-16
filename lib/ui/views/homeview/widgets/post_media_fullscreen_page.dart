import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/backbutton.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/responsive_text_widget.dart';
import '../../../../shared/widgets/responsive_widget.dart';
import '../post_model.dart';

/// Fullscreen viewer for post media: swipe between items; pinch-zoom images; play videos.
class PostMediaFullscreenPage extends StatefulWidget {
  final PostModel post;
  final int initialIndex;

  const PostMediaFullscreenPage({
    super.key,
    required this.post,
    required this.initialIndex,
  });

  @override
  State<PostMediaFullscreenPage> createState() => _PostMediaFullscreenPageState();
}

class _PostMediaFullscreenPageState extends State<PostMediaFullscreenPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final paths = widget.post.allMediaPaths;
    final last = paths.isEmpty ? 0 : paths.length - 1;
    final safeInitial = widget.initialIndex.clamp(0, last);
    _currentIndex = safeInitial;
    _pageController = PageController(initialPage: safeInitial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static bool _isAssetPath(String path) => path.startsWith('assets/');
  static bool _isNetworkUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  ImageProvider? _imageProvider(String path) {
    final p = path.trim();
    if (p.isEmpty) return null;
    if (_isAssetPath(p)) return AssetImage(p);
    if (_isNetworkUrl(p)) return CachedNetworkImageProvider(p);
    final f = File(p);
    if (f.existsSync()) return FileImage(f);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.post.allMediaPaths;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: ResponsivePadding(
                mobilePadding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.appBarHorizontalMobile,
                  vertical: AppDimensions.appBarVerticalMobile,
                ),
                tabletPadding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.appBarHorizontalTablet,
                  vertical: AppDimensions.appBarVerticalTablet,
                ),
                desktopPadding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.appBarHorizontalDesktop,
                  vertical: AppDimensions.appBarVerticalDesktop,
                ),
                child: Row(
                  children: [
                    CustomBackButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: context.getConditionalSpacing()),
                    if (paths.length > 1)
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 0),
                          child: ResponsiveTextWidget(
                            '${_currentIndex + 1} / ${paths.length}',
                            fontSize: context.getConditionalMainFont(),
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: paths.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final path = paths[index];
                if (path.trim().isEmpty) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  );
                }
                if (widget.post.isVideoAtIndex(index)) {
                  return _FullscreenVideo(urlOrPath: path);
                }
                final provider = _imageProvider(path);
                if (provider == null) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  );
                }
                return PhotoView(
                  imageProvider: provider,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  loadingBuilder: (context, event) {
                    if (event == null) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    final total = event.expectedTotalBytes;
                    final loaded = event.cumulativeBytesLoaded;
                    final value = total != null && total > 0 ? loaded / total : null;
                    return Center(
                      child: CircularProgressIndicator(
                        value: value,
                        color: AppColors.primary,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  final String urlOrPath;

  const _FullscreenVideo({required this.urlOrPath});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final p = widget.urlOrPath;
      final isNet = p.startsWith('http://') || p.startsWith('https://');
      final controller = isNet
          ? VideoPlayerController.networkUrl(Uri.parse(p))
          : VideoPlayerController.file(File(p));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _videoPlayerController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final chewie = _chewieController;
    if (chewie != null) {
      return Center(child: Chewie(controller: chewie));
    }
    return const SizedBox.shrink();
  }
}
