import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const radius = 2.0; // rounded-sm

  static ThemeData light() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.title,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.title,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.title,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(color: AppColors.body),
        bodySmall: TextStyle(color: AppColors.caption),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: shape,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ).copyWith(
              overlayColor: const WidgetStatePropertyAll(
                AppColors.primaryHover,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.caption, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.caption),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      // Material 3 mặc định ám màu primary lên nền dialog/menu -> ép về trắng.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.title,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.divider,
      ),
    );
  }
}
