import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] if it parses as http(s); shows a snackbar on failure.
Future<void> tryLaunchJobUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
