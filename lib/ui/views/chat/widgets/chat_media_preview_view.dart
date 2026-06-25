import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../chat_view_model.dart';

/// Review screen shown after picking media; returns `true` to send.
class ChatMediaPreviewView extends StatelessWidget {
  final List<XFile> media;

  const ChatMediaPreviewView({super.key, required this.media});

  static const Color _brand = Color(0xFFFC2E95);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          media.length == 1 ? 'Preview' : '${media.length} selected',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: media.length == 1
          ? Center(child: _previewTile(media.first, big: true))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: media.length,
              itemBuilder: (_, i) => _previewTile(media[i]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send, color: Colors.white),
              label: Text(
                media.length == 1 ? 'Send' : 'Send ${media.length} items',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewTile(XFile file, {bool big = false}) {
    final isVideo = ChatViewModel.isVideoPath(file.path);
    if (isVideo) {
      return Container(
        color: const Color(0xFF1A1A1A),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.videocam, color: Colors.white70, size: 40),
            SizedBox(height: 6),
            Text('Video', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }
    final img = Image.file(File(file.path), fit: big ? BoxFit.contain : BoxFit.cover);
    return big ? img : ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
  }
}
