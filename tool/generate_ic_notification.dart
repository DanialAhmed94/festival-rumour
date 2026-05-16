// Convert festivalAppLogo.png -> white-on-transparent ic_notification.png per density.
// Run from repo root: dart run tool/generate_ic_notification.dart

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final root = Directory.current;
  final input = File('${root.path}/assets/appIcon/festivalAppLogo.png');
  if (!input.existsSync()) {
    stderr.writeln('Missing: ${input.path}');
    exit(1);
  }

  final raw = input.readAsBytesSync();
  final source = img.decodeImage(raw);
  if (source == null) {
    stderr.writeln('Could not decode PNG');
    exit(1);
  }

  final w = source.width;
  final h = source.height;
  final silhouette = img.Image(width: w, height: h, numChannels: 4);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = source.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final a = p.a.toInt();
      // White/light grey canvas + anti-alias fringes treated as background
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
      final isBackground =
          a < 16 || (luminance > 248 && (r + g + b) / 3 > 246);
      if (isBackground) {
        silhouette.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        silhouette.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }

  // Square icon: center-crop source if not square
  img.Image square = silhouette;
  if (w != h) {
    final side = w < h ? w : h;
    final ox = (w - side) ~/ 2;
    final oy = (h - side) ~/ 2;
    square = img.copyCrop(silhouette, x: ox, y: oy, width: side, height: side);
  }

  const densities = {
    'drawable-mdpi': 24,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 48,
    'drawable-xxhdpi': 72,
    'drawable-xxxhdpi': 96,
  };

  final res = Directory('${root.path}/android/app/src/main/res');
  for (final e in densities.entries) {
    final dir = Directory('${res.path}/${e.key}');
    dir.createSync(recursive: true);
    final size = e.value;
    final resized = img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    final outFile = File('${dir.path}/ic_notification.png');
    outFile.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('Wrote ${outFile.path} (${size}x$size)');
  }
}
