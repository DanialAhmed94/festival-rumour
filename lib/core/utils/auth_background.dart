import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_font.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart'; // new constants file

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          /// Background Image
          SizedBox(
            width: double.infinity,
            height: screenHeight * 0.8,
            child: Image.asset(AppAssets.background, fit: BoxFit.cover),
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
    );
  }
}
