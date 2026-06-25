import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_strings.dart';
import '../chat_view_model.dart';
import 'camera_source_sheet.dart';
import 'chat_media_preview_view.dart';

/// Shared chat input bar (used by both the group/public chat and 1:1 DMs).
/// Design: a single cream pill containing — 📎 attach · white field with 📷
/// camera inside · divider · 🎤 mic · divider · gradient send circle.
class ChatComposer extends StatelessWidget {
  final ChatViewModel viewModel;

  const ChatComposer({super.key, required this.viewModel});

  static const Color _brand = Color(0xFFFC2E95);
  static const Color _bar = Color(0xFFFBF3C7);

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: as the keyboard slides the bar up, its (shadow-heavy)
    // layer is cached & translated instead of repainting every frame.
    return RepaintBoundary(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.isUploadingMedia)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: viewModel.mediaUploadProgress > 0
                      ? viewModel.mediaUploadProgress
                      : null,
                  minHeight: 3,
                  backgroundColor: Colors.white30,
                  color: _brand,
                ),
              ),
            ),
          viewModel.isRecording
              ? _recordingBar(context)
              : _composerBar(context),
        ],
      ),
      ),
    );
  }

  BoxDecoration _barDecoration() => BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _composerBar(BuildContext context) {
    final busy = viewModel.isSendingMessage || viewModel.isUploadingMedia;
    return Container(
      decoration: _barDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _iconBtn(Icons.attach_file, busy ? null : () => _onAttach(context),
              'Attach'),
          const SizedBox(width: 2),
          Expanded(child: _textField(context, busy)),
          const SizedBox(width: 6),
          _divider(),
          _iconBtn(Icons.mic, busy ? null : () => _onMic(context), 'Voice'),
          _divider(),
          const SizedBox(width: 6),
          _sendButton(
            onTap: viewModel.isSendingMessage ? null : () => _handleSend(context),
            child: viewModel.isSendingMessage
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 25),
          ),
        ],
      ),
    );
  }

  Widget _textField(BuildContext context, bool busy) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.only(left: 18, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: viewModel.messageController,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 6,
              cursorColor: Colors.black,
              decoration: const InputDecoration(
                isDense: true,
                hintText: AppStrings.typeSomething,
                hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(color: Colors.black, fontSize: 16),
              enabled: !viewModel.isSendingMessage,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.camera_alt, color: _brand, size: 24),
            onPressed: busy ? null : () => _onCamera(context),
            tooltip: 'Camera',
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, String tip) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: Icon(icon, color: _brand, size: 24),
      onPressed: onTap,
      tooltip: tip,
    );
  }

  Widget _divider() => Container(
        width: 1.2,
        height: 26,
        color: Colors.black.withValues(alpha: 0.08),
      );

  Widget _sendButton({required VoidCallback? onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF5BB0), Color(0xFFE3198C)],
          ),
          boxShadow: [
            BoxShadow(
              color: _brand.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _recordingBar(BuildContext context) {
    return Container(
      decoration: _barDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 24),
            onPressed: () => viewModel.cancelRecording(),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: const [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recording…',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sendButton(
            onTap: () => viewModel.stopAndSendRecording(),
            child: const Icon(Icons.send, color: Colors.white, size: 25),
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  Future<void> _onAttach(BuildContext context) async {
    final files = await viewModel.pickMedia();
    if (files.isEmpty || !context.mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ChatMediaPreviewView(media: files)),
    );
    if (ok == true) await viewModel.sendMediaFiles(files);
  }

  Future<void> _onCamera(BuildContext context) async {
    final choice = await showCameraSourceSheet(context);
    if (choice == null || !context.mounted) return;
    final XFile? captured = choice == CameraChoice.photo
        ? await viewModel.capturePhoto()
        : await viewModel.recordVideo();
    if (captured == null || !context.mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatMediaPreviewView(media: [captured]),
      ),
    );
    if (ok == true) await viewModel.sendMediaFiles([captured]);
  }

  Future<void> _onMic(BuildContext context) async {
    final ok = await viewModel.startRecording();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
    }
  }

  Future<void> _handleSend(BuildContext context) async {
    final success = await viewModel.sendMessage();
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Couldn't send. Please check your connection and try again.",
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.red.shade200,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );
    }
  }
}
