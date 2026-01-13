import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import '../constants/app_colors.dart';
import '../../shared/extensions/context_extensions.dart';

/// Service for managing responsive text styles following MVVM architecture
class ResponsiveTextService {
  ResponsiveTextService._();
  static final ResponsiveTextService _instance = ResponsiveTextService._();
  static ResponsiveTextService get instance => _instance;

  // Cache for responsive font sizes to avoid repeated calculations
  final Map<String, double> _fontSizeCache = {};
  Size? _lastScreenSize;
  
  /// Get responsive font size based on screen size - optimized for high-res phones
  /// Uses caching to avoid repeated calculations
  double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final cacheKey = '${screenSize.width}_${screenSize.height}_$baseFontSize';
    
    // Check if screen size changed - clear cache if it did
    if (_lastScreenSize != null && _lastScreenSize != screenSize) {
      _fontSizeCache.clear();
    }
    _lastScreenSize = screenSize;
    
    // Return cached value if available
    if (_fontSizeCache.containsKey(cacheKey)) {
      return _fontSizeCache[cacheKey]!;
    }
    
    // Calculate and cache
    double fontSize;
    final screenWidth = screenSize.width;
    if (screenWidth >= 400 && screenWidth < 600) {
      fontSize = baseFontSize * 1.15; // High-res phones
    } else if (screenWidth >= 1200) {
      fontSize = baseFontSize * 1.3; // Desktop
    } else if (screenWidth >= 600 && screenWidth < 1200) {
      fontSize = baseFontSize * 1.2; // Tablets
    } else {
      fontSize = baseFontSize; // Small phones
    }
    
    _fontSizeCache[cacheKey] = fontSize;
    return fontSize;
  }

  /// Get responsive text style for headings
  TextStyle getHeadingStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textXL
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? AppColors.primary,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for body text
  TextStyle getBodyStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? AppColors.onSurface,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for labels
  TextStyle getLabelStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textS
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.onSurfaceVariant,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for buttons
  TextStyle getButtonStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textL
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.onPrimary,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for captions
  TextStyle getCaptionStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textXS
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? AppColors.onSurfaceVariant,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for titles
  TextStyle getTitleStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textTitle
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.primary,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for subtitles
  TextStyle getSubtitleStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.onSurfaceVariant,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for error messages
  TextStyle getErrorStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textS
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.error,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for success messages
  TextStyle getSuccessStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textS
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.success,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for accent text
  TextStyle getAccentStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.accent,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for primary text
  TextStyle getPrimaryStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.primary,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for secondary text
  TextStyle getSecondaryStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? AppColors.secondary,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for white text
  TextStyle getWhiteStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? AppColors.white,
      fontFamily: 'Montserrat',
    );
  }

  /// Get responsive text style for grey text
  TextStyle getGreyStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    double? baseFontSize,
  }) {
    final fontSize = getResponsiveFontSize(
      context, 
      baseFontSize ?? AppDimensions.textM
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? AppColors.grey300,
      fontFamily: 'Montserrat',
    );
  }
}
