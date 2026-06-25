import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../homeview/post_model.dart';
import '../../homeview/widgets/post_media_fullscreen_page.dart';
import '../chat_message_model.dart';

/// Renders a chat media message's images/videos as a WhatsApp-style album
/// (single tile / 2-up / 2-col grid with "+N"). Tapping opens the existing
/// [PostMediaFullscreenPage] (PhotoView + Chewie) by adapting the message to a
/// lightweight [PostModel].
class ChatMediaGrid extends StatelessWidget {
  final ChatMessageModel message;
  static const double _maxWidth = 240;

  const ChatMediaGrid({super.key, required this.message});

  void _openFullscreen(BuildContext context, int index) {
    final urls = message.mediaUrls ?? const [];
    if (urls.isEmpty) return;
    final post = PostModel(
      username: message.username,
      timeAgo: '',
      content: '',
      imagePath: urls.first,
      likes: 0,
      comments: 0,
      status: '',
      mediaPaths: urls,
      isVideoList: message.isVideoList,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostMediaFullscreenPage(post: post, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = message.mediaUrls ?? const [];
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return SizedBox(
        width: _maxWidth,
        height: 200,
        child: _tile(context, 0),
      );
    }

    final showCount = urls.length > 4 ? 4 : urls.length;
    const tileW = (_maxWidth - 3) / 2;
    return SizedBox(
      width: _maxWidth,
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (int i = 0; i < showCount; i++)
            SizedBox(
              width: tileW,
              height: 110,
              child: _tile(
                context,
                i,
                plusOverlay:
                    (i == 3 && urls.length > 4) ? urls.length - 4 : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int index, {int? plusOverlay}) {
    final urls = message.mediaUrls!;
    final isVideo = message.isVideoAtIndex(index);
    return GestureDetector(
      onTap: () => _openFullscreen(context, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(index == 0 && urls.length == 1 ? 12 : 8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              Container(color: Colors.black)
            else
              CachedNetworkImage(
                imageUrl: urls[index],
                fit: BoxFit.cover,
                memCacheWidth: 480,
                placeholder: (_, __) => Container(color: const Color(0xFFE0E0E0)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFE0E0E0),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            if (isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 40),
              ),
            if (plusOverlay != null)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  '+$plusOverlay',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
