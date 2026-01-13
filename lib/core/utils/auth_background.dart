import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_font.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart'; // new constants file

class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> {
  double? _cachedScreenHeight;
  double? _cachedScreenWidth;
  bool _imagePreloaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    
    // Cache dimensions only if they changed
    if (_cachedScreenHeight != screenHeight || _cachedScreenWidth != screenWidth) {
      _cachedScreenHeight = screenHeight;
      _cachedScreenWidth = screenWidth;
      
      // Preload background image
      if (!_imagePreloaded) {
        _imagePreloaded = true;
        precacheImage(const AssetImage(AppAssets.background), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use cached dimensions or get from MediaQuery if not cached
    final screenHeight = _cachedScreenHeight ?? MediaQuery.of(context).size.height;
    final screenWidth = _cachedScreenWidth ?? MediaQuery.of(context).size.width;

    return RepaintBoundary(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            /// Background Image
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.8,
              child: Image.asset(
                AppAssets.background,
                fit: BoxFit.cover,
                cacheWidth: (screenWidth * 2).toInt(), // Optimize image size
              ),
            ),

            /// Black Overlay
            Container(
              width: double.infinity,
              height: screenHeight,
              color: Colors.black.withOpacity(0.7),
            ),

            /// Logo + Welcome text
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.60,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: screenHeight * 0.15),
                      child: SvgPicture.asset(
                        AppAssets.logo,
                        color: Colors.white,
                        height: screenHeight * 0.20,
                        cacheColorFilter: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.35,
                    left: screenWidth * 0.1,
                    right: screenWidth * 0.1,
                    child: Column(
                      children: [
                        Text(
                          AppStrings.welcome,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.headingColor,
                            fontSize: 35.sp,
                            fontWeight: AppFonts.headingFontWeight,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Text(
                          AppStrings.FestivalRumour,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.headingColor,
                            fontSize: 35.sp,
                            fontWeight: AppFonts.headingFontWeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
