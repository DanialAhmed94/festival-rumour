import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../core/services/responsive_text_service.dart';
import '../extensions/context_extensions.dart';

/// Responsive text widget that follows MVVM architecture
class ResponsiveTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextType textType;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;

  const ResponsiveTextWidget(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.textType = TextType.body,
    this.color,
    this.fontWeight,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Cache MediaQuery to avoid repeated calls
    final mediaQuery = MediaQuery.of(context);
    final responsiveService = ResponsiveTextService.instance;
    TextStyle? responsiveStyle;

    switch (textType) {
      case TextType.heading:
        responsiveStyle = responsiveService.getHeadingStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.body:
        responsiveStyle = responsiveService.getBodyStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.label:
        responsiveStyle = responsiveService.getLabelStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.button:
        responsiveStyle = responsiveService.getButtonStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.caption:
        responsiveStyle = responsiveService.getCaptionStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.title:
        responsiveStyle = responsiveService.getTitleStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.subtitle:
        responsiveStyle = responsiveService.getSubtitleStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.error:
        responsiveStyle = responsiveService.getErrorStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.success:
        responsiveStyle = responsiveService.getSuccessStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.accent:
        responsiveStyle = responsiveService.getAccentStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.primary:
        responsiveStyle = responsiveService.getPrimaryStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.secondary:
        responsiveStyle = responsiveService.getSecondaryStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.white:
        responsiveStyle = responsiveService.getWhiteStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
      case TextType.grey:
        responsiveStyle = responsiveService.getGreyStyle(
          context,
          color: color,
          fontWeight: fontWeight,
          baseFontSize: fontSize,
        );
        break;
    }

    // Merge with custom style if provided
    if (style != null) {
      responsiveStyle = responsiveStyle?.merge(style);
    }

    return Text(
      text,
      style: responsiveStyle,
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

/// Enum for different text types
enum TextType {
  heading,
  body,
  label,
  button,
  caption,
  title,
  subtitle,
  error,
  success,
  accent,
  primary,
  secondary,
  white,
  grey,
}

/// Responsive Rich Text widget
class ResponsiveRichText extends StatelessWidget {
  final List<ResponsiveTextSpan> children;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveRichText({
    Key? key,
    required this.children,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final responsiveService = ResponsiveTextService.instance;
    
    return RichText(
      text: TextSpan(
        children: children.map((span) {
          TextStyle? responsiveStyle;

          switch (span.textType) {
            case TextType.heading:
              responsiveStyle = responsiveService.getHeadingStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.body:
              responsiveStyle = responsiveService.getBodyStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.label:
              responsiveStyle = responsiveService.getLabelStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.button:
              responsiveStyle = responsiveService.getButtonStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.caption:
              responsiveStyle = responsiveService.getCaptionStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.title:
              responsiveStyle = responsiveService.getTitleStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.subtitle:
              responsiveStyle = responsiveService.getSubtitleStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.error:
              responsiveStyle = responsiveService.getErrorStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.success:
              responsiveStyle = responsiveService.getSuccessStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.accent:
              responsiveStyle = responsiveService.getAccentStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.primary:
              responsiveStyle = responsiveService.getPrimaryStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.secondary:
              responsiveStyle = responsiveService.getSecondaryStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.white:
              responsiveStyle = responsiveService.getWhiteStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
            case TextType.grey:
              responsiveStyle = responsiveService.getGreyStyle(
                context,
                color: span.color,
                fontWeight: span.fontWeight,
                baseFontSize: span.baseFontSize,
              );
              break;
          }

          if (span.style != null) {
            responsiveStyle = responsiveStyle?.merge(span.style);
          }

          return TextSpan(
            text: span.text,
            style: responsiveStyle,
            recognizer: span.recognizer,
          );
        }).toList(),
      ),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

/// Responsive TextSpan class
class ResponsiveTextSpan {
  final String text;
  final TextStyle? style;
  final TextType textType;
  final Color? color;
  final FontWeight? fontWeight;
  final double? baseFontSize;
  final GestureRecognizer? recognizer;

  const ResponsiveTextSpan({
    required this.text,
    this.style,
    this.textType = TextType.body,
    this.color,
    this.fontWeight,
    this.baseFontSize,
    this.recognizer,
  });
}
