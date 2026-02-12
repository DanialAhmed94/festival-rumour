import 'package:flutter/material.dart';

/// App color constants with Primary = White, Secondary = Black, Accent = Yellow
class AppColors {
  AppColors._();

  // Primary Colors (White theme base)
  static const Color primary = Color(0xFFFFFFFF);        // White
  static const Color onPrimary = Color(0xFF000000);      // Black text/icons on white
  static const Color primaryContainer = Color(0xFFF5F5F5); // Light grey container
  static const Color onPrimaryContainer = Color(0xFF000000);

  // Accent Colors
  static const Color accent = Color(0xFFFECD00);         // Yellow for buttons/highlights
  static const Color gradientStart = Color(0xFFFFFFFF);  // White
  static const Color gradientEnd = Color(0xFF000000);    // Black

  static const LinearGradient mainGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Secondary Colors (Black theme base)
  static const Color secondary = Color(0xFF000000);        // Black
  static const Color onSecondary = Color(0xFFFFFFFF);      // White text/icons on black
  static const Color secondaryContainer = Color(0xFF212121); // Dark grey container
  static const Color onSecondaryContainer = Color(0xFFFFFFFF);

  // Tertiary Colors (Greyscale for contrast)
  static const Color tertiary = Color(0xFFE0E0E0);         // Light grey
  static const Color onTertiary = Color(0xFF000000);       // Black for contrast
  static const Color tertiaryContainer = Color(0xFF9E9E9E); // Mid grey
  static const Color onTertiaryContainer = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF2F2F2);
  static const Color mutedText = Color(0xFF9B9B9B);
  static const Color lightBlack = Color(0xFF212121);

  // Error Colors
  static const Color error = white;  // Material red
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFCD8DF);
  static const Color onErrorContainer = Color(0xFF370617);


  //Add ME
  //static const Color background = Colors.black;
  static const Color textPrimary = Colors.white;
  static const Color borderPrimary = Colors.white;
  static const Color buttonPrimary = Color(0xFFF3B126); // Yellow tone
  static const Color buttonText = Colors.white;
  static const Color iconPrimary = Colors.white;
  static const Color closeButtonBg = Color(0xFFD6D6D6);
  static const Color closeButtonIcon = Colors.black;
  static const Color overlay = Colors.black45;
  static const Color loginButtonText = Colors.white;


  static const Color postBackground = Colors.black;
  // Post UI tint (pink with a slight purple shade)
  static const Color postPinkPurple = Color(0xFFE82B9D);
  static const Color postPinkPurple50 = Color(0x80E82B9D); // 50% opacity
  static const Color postYellow50 = Color(0x80FECD10); // #FECD10 @ 50% opacity
  static const Color postShadow = Colors.grey;
  static const Color reactionLike = Colors.red;
  static const Color reactionLove = Colors.blue;
  static const Color proLabelBackground = Colors.orange;
  static const Color proLabelText = Colors.white;
  static const Color eventOverlay = Colors.black54;
  static const Color nowBadge = Colors.black;
  static const Color iconBackground = Colors.grey;
  static const Color iconColor = Colors.black;
  static const Color headlineBackground = Colors.black54;
  static const Color overlayBlack = Colors.black;
  static const Color headingColor = Colors.white;
  static const Color subHeadingColor = Colors.white70;

  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);        // White surface
  static const Color onSurface = Color(0xFF000000);      // Black text
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Light grey variant
  static const Color onSurfaceVariant = Color(0xFF616161);

  // Background Colors
  static const Color background = Color(0xFFFFFFFF);     // White background
  static const Color onBackground = Color(0xFF000000);   // Black text

  /// Default screen background (cream) — used for scaffold/screen backgrounds app-wide.
  static const Color screenBackground = Color(0xFFFDFFD2);

  // Outline Colors
  static const Color outline = Color(0xFF9E9E9E);
  static const Color outlineVariant = Color(0xFFBDBDBD);

  // Shadow and Scrim
  static const Color shadow = Color(0xFF000000);
  static const Color scrim = Color(0xFF000000);

  // Custom App Colors
  static const Color success = accent;  // Green
  static const Color warning = Color(0xFFFF9800);  // Orange
  static const Color info = Color(0xFF2196F3);     // Blue
  static const Color buttonYellow = Color(0xFFFECD00); // Yellow for buttons

  // Neutral Greys
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, black],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [white, grey100],
  );

  // Additional colors found in UI components
  static const Color googleRed = Color(0xFFDB4437);
  static const Color emailBlue = Color(0xFF375CA1);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  
  // Avatar colors for chat
  static const Color avatarPurple = Color(0xFF9C27B0);
  static const Color avatarOrange = Color(0xFFFF9800);
  static const Color avatarGrey = Color(0xFF9E9E9E);
  static const Color avatarYellow = Color(0xFFFFEB3B);
  static const Color avatarBlue = Color(0xFF2196F3);
  static const Color avatarPink = Color(0xFFE91E63);
  
  // News and Bulletin colors
  static const Color lightGreen = Color(0xFFE8F5E8);
  static const Color greenBackground = Color(0xFF4CAF50);
  static const Color lightBlue = Color(0xFFE3F2FD);
  
  // Additional colors for news and UI
  static const Color newsGreen = Color(0xFF4CAF50);
  static const Color newsLightGreen = Color(0xFFE8F5E8);
  static const Color newsLightBlue = Color(0xFFE3F2FD);

  // Performance specific colors
  static const Color performanceGreen = Color(0xFF4CAF50);
  static const Color performanceLightBlue = Color(0xFFE3F2FD);

  // Event specific colors
  static const Color eventGreen = Color(0xFF4CAF50);
  static const Color eventLightGreen = Color(0xFFE8F5E8);
  static const Color eventLightBlue = Color(0xFFE3F2FD);
  
  // Additional colors found in UI
  static const Color amber = Color(0xFFFFC107);
  static const Color teal = Color(0xFF009688);
  static const Color purple = Color(0xFF9C27B0);
  static const Color orange = Color(0xFFFF9800);
  static const Color brown = Color(0xFF795548);
  static const Color red = Color(0xFFF44336);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color yellow = Color(0xFFFFEB3B);
  static const Color blue = Color(0xFF2196F3);
  static const Color pink = Color(0xFFE91E63);
  static const Color deepOrange = Color(0xFFFF5722);
  static const Color blueAccent = Color(0xFF03A9F4);
  
  // Reaction colors

  static const Color reactionHaha = Color(0xFFFFEB3B); // Yellow
  static const Color reactionWow = Color(0xFFFF9800); // Orange
  static const Color reactionSad = Color(0xFF9C27B0); // Purple
  static const Color reactionAngry = Color(0xFFF44336); // Red
  
  // Overlay colors
  static const Color overlayBlack54 = Color(0x8A000000); // 54% black
  static const Color overlayBlack45 = Color(0x73000000); // 45% black
  
  // Text colors with opacity
  static const Color white70 = Color(0xB3FFFFFF); // 70% white
  static const Color white60 = Color(0x99FFFFFF); // 60% white
  static const Color black54 = Color(0x8A000000); // 54% black
  static const Color black45 = Color(0x73000000); // 45% black
  
  // Border colors
  static const Color borderWhite = Color(0xFFFFFFFF);
  static const Color borderWhite60 = Color(0x99FFFFFF);
  static const Color borderGrey = Color(0xFF9E9E9E);
  
  // Status colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color away = Color(0xFFFF9800);
  static const Color busy = Color(0xFFF44336);
  
  // Priority colors
  static const Color highPriority = Color(0xFFF44336);
  static const Color mediumPriority = Color(0xFFFF9800);
  static const Color lowPriority = Color(0xFF4CAF50);
  
  // Chat bubble colors
  static const Color chatBubbleSent = Color(0xFF2196F3);
  static const Color chatBubbleReceived = Color(0xFFE0E0E0);
  static const Color chatBubbleTextSent = Color(0xFFFFFFFF);
  static const Color chatBubbleTextReceived = Color(0xFF000000);
  
  // List of avatar colors for random selection
  static const List<Color> avatarColors = [
    avatarPurple,
    avatarOrange,
    avatarGrey,
    avatarYellow,
    avatarBlue,
    avatarPink,
  ];
  
  // Transparent color
  static const Color transparent = Color(0x00000000);
}
