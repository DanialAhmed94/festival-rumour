import 'package:flutter/material.dart';

enum CameraChoice { photo, video }

/// WhatsApp-style chooser: "Take Photo" or "Record Video". Returns null on cancel.
Future<CameraChoice?> showCameraSourceSheet(BuildContext context) {
  return showModalBottomSheet<CameraChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Color(0xFFFC2E95)),
            title: const Text('Take Photo',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, CameraChoice.photo),
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Color(0xFFFC2E95)),
            title: const Text('Record Video',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, CameraChoice.video),
          ),
          ListTile(
            leading: const Icon(Icons.close, color: Colors.black54),
            title: const Text('Cancel', style: TextStyle(color: Colors.black)),
            onTap: () => Navigator.pop(ctx),
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom),
        ],
      ),
    ),
  );
}
