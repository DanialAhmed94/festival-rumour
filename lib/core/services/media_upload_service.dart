import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Storage uploads with optional progress.
/// Mirrors the upload logic in CreatePostViewModel so chat media reuses one path.
class MediaUploadService {
  /// Uploads [file] to `{folder}/{fileName}` and returns the download URL
  /// (or null on failure). [onProgress] reports 0.0–1.0.
  Future<String?> uploadFile({
    required File file,
    required String folder,
    required String fileName,
    required String contentType,
    String? uploadedBy,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(folder).child(fileName);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          if (uploadedBy != null) 'uploadedBy': uploadedBy,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final task = ref.putFile(file, metadata);

      StreamSubscription<TaskSnapshot>? sub;
      if (onProgress != null) {
        sub = task.snapshotEvents.listen(
          (s) {
            if (s.totalBytes == 0) return;
            onProgress(s.bytesTransferred / s.totalBytes);
          },
          onError: (Object _) {},
          cancelOnError: false,
        );
      }

      try {
        final snap = await task;
        return await snap.ref.getDownloadURL();
      } finally {
        await sub?.cancel();
      }
    } catch (e) {
      if (kDebugMode) print('❌ MediaUploadService.uploadFile error: $e');
      return null;
    }
  }
}
