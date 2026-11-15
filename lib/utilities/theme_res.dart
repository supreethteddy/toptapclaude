// import 'package:flutter/material.dart';
// import 'package:toptap/utilities/color_res.dart';
// import 'package:toptap/utilities/font_res.dart';

// class ThemeRes {
//   /// Theme light mode

// // App Body color in light theme
//   static ThemeData lightTheme(BuildContext context) {
//     return ThemeData(
//       scaffoldBackgroundColor: ColorRes.whitePure,
// // Not yet known, bottom navigation bar (guess)
//       bottomNavigationBarTheme:
//           const BottomNavigationBarThemeData(
//         backgroundColor: ColorRes.whitePure,
//         //backgroundColor: ColorRes.blackPure,
//       ),
//       //-------------------------------->
//       //App Bar theme color
//       appBarTheme: const AppBarTheme(
//           backgroundColor: ColorRes.whitePure),
//       //------------------------------->

//       fontFamily: FontRes.outFitRegular400,
//       //fontFamily: FontRes.outFitExtraBold800,
//       //------------------------------->
//       bottomSheetTheme: const BottomSheetThemeData(
//           backgroundColor: ColorRes.whitePure),

//       sliderTheme: const SliderThemeData(
//           trackHeight: 2.5,
//           trackShape: RectangularSliderTrackShape(),
//           overlayShape:
//               RoundSliderOverlayShape(overlayRadius: 0),
//           overlayColor: Colors.transparent),

//       textTheme: const TextTheme(
//         titleLarge: TextStyle(color: ColorRes.whitePure),
//         // titleMedium:
//         //     TextStyle(color: ColorRes.textDarkGrey),
//         titleMedium: TextStyle(color: ColorRes.green1),
//         titleSmall: TextStyle(color: ColorRes.likeRed),
//         labelSmall:
//             TextStyle(color: ColorRes.themeAccentSolid),
//         labelLarge: TextStyle(color: ColorRes.disabledGrey),
//       ),
//       textSelectionTheme: const TextSelectionThemeData(
//           selectionColor: ColorRes.disabledGrey),
//       cardTheme:
//           const CardThemeData(color: ColorRes.blueFollow),
//       splashColor: Colors.transparent,
//       highlightColor: Colors.transparent,
//       primaryColor: ColorRes.themeAccentSolid,
//       dividerColor: ColorRes.bgGrey,
//       cardColor: ColorRes.bgMediumGrey,
//       // primaryColorDark: ColorRes.blackPure,
//       primaryColorDark: ColorRes.whitePure,
//       canvasColor: ColorRes.themeColor,
//       useMaterial3: false,
//     );
//   }

//   /// Theme dark mode

//   static ThemeData darkTheme(BuildContext context) {
//     return ThemeData(
//       scaffoldBackgroundColor: ColorRes.blackPure,

//       // Not Correct in the Dark Mode
//       bottomNavigationBarTheme:
//           const BottomNavigationBarThemeData(
//         backgroundColor: ColorRes.blackPure,
//       ),

//       // This one is Correct in the Dark and Light Mode
//       appBarTheme: const AppBarTheme(
//         // backgroundColor: ColorRes.bgMediumGrey,
//         backgroundColor: ColorRes.blackPure,
//       ),
//       fontFamily: FontRes.outFitRegular400,
//       bottomSheetTheme: const BottomSheetThemeData(
//         backgroundColor: ColorRes.blackPure,
//       ),
//       sliderTheme: const SliderThemeData(
//         trackHeight: 2.5,
//         trackShape: RectangularSliderTrackShape(),
//         overlayShape:
//             RoundSliderOverlayShape(overlayRadius: 0),
//         overlayColor: Colors.transparent,
//       ),
//       textTheme: const TextTheme(
//         titleLarge: TextStyle(color: ColorRes.whitePure),

//         // media titles like username etc..
//         titleMedium:
//             // TextStyle(color: ColorRes.textLightGrey),
//             TextStyle(color: ColorRes.green),

//         // small titles like following , likes , followers text colour etc..

//         titleSmall: TextStyle(color: ColorRes.whitePure),
//         // titleSmall: TextStyle(color: ColorRes.disabledGrey),
//         // titleSmall: TextStyle(color: ColorRes.likeRed),

//         // Setting icons Colors
//         labelSmall:
//             TextStyle(color: ColorRes.themeAccentSolid),

//         // Profile Section icons Colors
//         labelLarge:
//             //TextStyle(color: ColorRes.textLightGrey),
//             TextStyle(color: ColorRes.green1),
//       ),

//       textSelectionTheme: const TextSelectionThemeData(
//         selectionColor: ColorRes.themeAccentSolid,
//       ),
//       // cardTheme: const CardTheme(color: ColorRes.bgGrey),
//       splashColor: Colors.transparent,
//       highlightColor: Colors.transparent,
//       primaryColor: ColorRes.themeAccentSolid,
//       dividerColor: ColorRes.textDarkGrey,
//       //  cardColor: ColorRes.bgGrey,
//       cardColor: ColorRes.blackPure,
//       // primaryColorDark: ColorRes.whitePure,
//       primaryColorDark: ColorRes.blackPure,
//       canvasColor: ColorRes.likeRed,
//       useMaterial3: true,
//     );
//   }
// }

// Color whitePure(BuildContext context) {
//   return Theme.of(context).textTheme.titleLarge?.color ??
//       ColorRes.whitePure;
// }

// Color textDarkGrey(BuildContext context) {
//   return Theme.of(context).textTheme.titleMedium?.color ??
//       textDarkGrey(context);
// }

// Color textLightGrey(BuildContext context) {
//   return Theme.of(context).textTheme.titleSmall?.color ??
//       ColorRes.textLightGrey;
// }

// Color textredstyle(BuildContext context) {
//   return Theme.of(context).textTheme.titleSmall?.color ??
//       ColorRes.themeGradient1;
// }

// Color bgGrey(BuildContext context) {
//   return Theme.of(context).dividerColor;
// }

// Color themeAccentSolid(BuildContext context) {
//   return Theme.of(context).textTheme.labelSmall?.color ??
//       themeAccentSolid(context);
// }

// Color disableGrey(BuildContext context) {
//   return Theme.of(context).textTheme.labelLarge?.color ??
//       ColorRes.disabledGrey;
// }

// Color scaffoldBackgroundColor(BuildContext context) {
//   return Theme.of(context).scaffoldBackgroundColor;
// }

// Color blueFollow(BuildContext context) {
//   return Theme.of(context).cardTheme.color ??
//       ColorRes.blueFollow;
// }

// Color bgMediumGrey(BuildContext context) {
//   return Theme.of(context).cardColor;
// }

// Color blackPure(BuildContext context) {
//   return Theme.of(context).primaryColorDark;
// }

// Color bgLightGrey(BuildContext context) {
//   return Theme.of(context).appBarTheme.backgroundColor ??
//       ColorRes.bgLightGrey;
// }

// Color themeColor(BuildContext context) {
//   return Theme.of(context).canvasColor;
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/instance_manager.dart';
import 'package:toptap/utilities/color_res.dart';
import 'package:toptap/utilities/font_res.dart';

class ThemeRes {
  /// Theme light mode

  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: ColorRes.whitePure,
      bottomNavigationBarTheme:
          const BottomNavigationBarThemeData(
        backgroundColor: ColorRes.whitePure,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColorRes.whitePure,
      ),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ColorRes.whitePure,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2.5,
        trackShape: RectangularSliderTrackShape(),
        overlayShape:
            RoundSliderOverlayShape(overlayRadius: 0),
        overlayColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: ColorRes.blackPure),
        titleMedium: TextStyle(color: ColorRes.green1),
        titleSmall: TextStyle(color: ColorRes.likeRed),
        labelSmall: TextStyle(color: ColorRes.likeRed),
        labelLarge: TextStyle(color: ColorRes.disabledGrey),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: ColorRes.disabledGrey,
      ),
      brightness: Brightness.light,
      cardTheme:
          const CardThemeData(color: ColorRes.blueFollow),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      // primaryColor: ColorRes.themeAccentSolid,
      // primaryColor: const Color.fromRGBO(202, 42, 36, 1)
      //     .withOpacity(0.5),
      dividerColor: ColorRes.bgGrey,
      cardColor: ColorRes.bgMediumGrey,
      primaryColorDark: ColorRes.whitePure,
      canvasColor: ColorRes.themeColor,
      useMaterial3: false,
    );
  }

  /// Theme dark mode

  static ThemeData darkTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: ColorRes.blackPure,
      bottomNavigationBarTheme:
          const BottomNavigationBarThemeData(
        backgroundColor: ColorRes.blackPure,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColorRes.blackPure,
      ),
      brightness: Brightness.dark,
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ColorRes.blackPure,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2.5,
        trackShape: RectangularSliderTrackShape(),
        overlayShape:
            RoundSliderOverlayShape(overlayRadius: 0),
        overlayColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: ColorRes.whitePure),
        titleMedium: TextStyle(color: ColorRes.green),
        titleSmall: TextStyle(color: ColorRes.whitePure),
        labelSmall: TextStyle(color: ColorRes.likeRed),
        labelLarge: TextStyle(color: ColorRes.green1),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: ColorRes.themeAccentSolid,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      primaryColor: ColorRes.themeAccentSolid,
      dividerColor: ColorRes.textDarkGrey,
      cardColor: ColorRes.blackPure,
      primaryColorDark: ColorRes.blackPure,
      canvasColor: ColorRes.likeRed,
      useMaterial3: true,
    );
  }
}

// Always return pure white
Color whitePure(BuildContext context) {
  return ColorRes.whitePure;
}

// Always return pure black
Color blackPure(BuildContext context) {
  return ColorRes.blackPure;
}

// container border colors

Color adaptiveBorderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
}

// Adaptive Text Color: black in dark mode, white in light mode

Color adaptiveTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
}

// Adaptive background: black in dark mode, white in light mode
// how to adapt the background color in my code which is calling color

 
Color adaptiveBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? ColorRes.blackPure
      : ColorRes.whitePure;
}

Color textDarkGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium?.color ??
      ColorRes.textDarkGrey;
}

Color textLightGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.color ??
      ColorRes.textLightGrey;
}

Color textredstyle(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.color ??
      ColorRes.themeGradient1;
}

Color bgGrey(BuildContext context) {
  return Theme.of(context).dividerColor;
}

Color themeAccentSolid(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.color ??
      ColorRes.themeAccentSolid;
}

Color disableGrey(BuildContext context) {
  return Theme.of(context).textTheme.labelLarge?.color ??
      ColorRes.disabledGrey;
}

Color scaffoldBackgroundColor(BuildContext context) {
  return Theme.of(context).scaffoldBackgroundColor;
}

Color blueFollow(BuildContext context) {
  return Theme.of(context).cardTheme.color ??
      ColorRes.blueFollow;
}

Color bgMediumGrey(BuildContext context) {
  return Theme.of(context).cardColor;
}

Color bgLightGrey(BuildContext context) {
  return Theme.of(context).appBarTheme.backgroundColor ??
      ColorRes.bgLightGrey;
}

Color themeColor(BuildContext context) {
  return Theme.of(context).canvasColor;
}
