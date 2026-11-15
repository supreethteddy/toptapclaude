import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class DrawingToolbar extends StatelessWidget {
  final Color selectedColor;
  final double selectedSize;
  final bool isEraser;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onDone;
  final Function(Color) onColorSelected;
  final Function(double) onSizeSelected;
  final VoidCallback onEraserToggle;
  final bool canUndo;
  final bool canRedo;

  const DrawingToolbar({
    super.key,
    required this.selectedColor,
    required this.selectedSize,
    required this.isEraser,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onDone,
    required this.onColorSelected,
    required this.onSizeSelected,
    required this.onEraserToggle,
    required this.canUndo,
    required this.canRedo,
  });

  // Preset colors
  static const List<Color> colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Color(0xFFFF1493), // Pink
    Colors.purple,
    Colors.orange,
    Colors.cyan,
  ];

  // Brush sizes
  static const List<double> sizes = [3.0, 6.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: adaptiveBackground(context).withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top controls: Undo, Redo, Clear, Done
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildIconButton(
                    icon: Icons.undo,
                    onTap: canUndo ? onUndo : null,
                    enabled: canUndo,
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.redo,
                    onTap: canRedo ? onRedo : null,
                    enabled: canRedo,
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.delete_outline,
                    onTap: onClear,
                    color: Colors.red,
                  ),
                ],
              ),
              _buildTextButton(
                text: 'Done',
                onTap: onDone,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Color picker
          _buildSectionTitle('Color', context),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected =
                  selectedColor.value == color.value &&
                      !isEraser;
              return _buildColorCircle(
                color: color,
                isSelected: isSelected,
                onTap: () => onColorSelected(color),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Brush size selector
          _buildSectionTitle('Brush Size', context),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            children: sizes.map((size) {
              final isSelected =
                  selectedSize == size && !isEraser;
              return _buildSizeCircle(
                size: size,
                isSelected: isSelected,
                onTap: () => onSizeSelected(size),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Eraser button
          _buildEraserButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
      String title, BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyleCustom.outFitMedium500(
          fontSize: 13,
          color: adaptiveTextColor(context),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
    Color? color,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? (color ?? themeAccentSolid(Get.context!))
              : Colors.grey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTextButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: themeAccentSolid(Get.context!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyleCustom.outFitMedium500(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildColorCircle({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? themeAccentSolid(Get.context!)
                : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: themeAccentSolid(Get.context!)
                    .withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check,
                color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildSizeCircle({
    required double size,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccentSolid(Get.context!)
              : Colors.grey.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? themeAccentSolid(Get.context!)
                : Colors.grey,
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: size * 2,
            height: size * 2,
            decoration: BoxDecoration(
              color:
                  isSelected ? Colors.white : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEraserButton() {
    return InkWell(
      onTap: onEraserToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isEraser
              ? Colors.red
              : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEraser ? Colors.red : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_fix_high,
              color: isEraser ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isEraser ? 'Eraser (Active)' : 'Eraser',
              style: TextStyleCustom.outFitMedium500(
                fontSize: 14,
                color:
                    isEraser ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
