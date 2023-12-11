// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/cupertino.dart';

//
const TextStyle _kToolbarButtonFontStyle = TextStyle(
  inherit: false,
  fontSize: 14,
  letterSpacing: -0.15,
  fontWeight: FontWeight.w400,
);

const CupertinoDynamicColor _kToolbarTextColor =
    CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.black,
  darkColor: CupertinoColors.white,
);

const CupertinoDynamicColor _kToolbarPressedColor =
    CupertinoDynamicColor.withBrightness(
  color: Color(0x10000000),
  darkColor: Color(0x10FFFFFF),
);

// Value measured from screenshot of iOS 16.0.2
const EdgeInsets _kToolbarButtonPadding =
    EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0);

/// A button in the style of the iOS text selection toolbar buttons.
class CustomCupertinoTextSelectionToolbarButton extends StatefulWidget {
  /// Create an instance of [CustomCupertinoTextSelectionToolbarButton].
  ///
  /// [child] cannot be null.
  const CustomCupertinoTextSelectionToolbarButton({
    super.key,
    this.onPressed,
    required Widget this.child,
  })  : text = null,
        buttonItem = null;

  /// Create an instance of [CustomCupertinoTextSelectionToolbarButton] whose child is
  /// a [Text] widget styled like the default iOS text selection toolbar button.
  const CustomCupertinoTextSelectionToolbarButton.text({
    super.key,
    this.onPressed,
    required this.text,
  })  : buttonItem = null,
        child = null;

  /// Create an instance of [CustomCupertinoTextSelectionToolbarButton] from the given
  /// [ContextMenuButtonItem].
  ///
  /// [buttonItem] cannot be null.
  CustomCupertinoTextSelectionToolbarButton.buttonItem({
    super.key,
    required ContextMenuButtonItem this.buttonItem,
  })  : child = null,
        text = null,
        onPressed = buttonItem.onPressed;

  /// {@template flutter.cupertino.CustomCupertinoTextSelectionToolbarButton.child}
  /// The child of this button.
  ///
  /// Usually a [Text] or an [Icon].
  /// {@endtemplate}
  final Widget? child;

  /// {@template flutter.cupertino.CustomCupertinoTextSelectionToolbarButton.onPressed}
  /// Called when this button is pressed.
  /// {@endtemplate}
  final VoidCallback? onPressed;

  /// {@template flutter.cupertino.CustomCupertinoTextSelectionToolbarButton.onPressed}
  /// The buttonItem used to generate the button when using
  /// [CustomCupertinoTextSelectionToolbarButton.buttonItem].
  /// {@endtemplate}
  final ContextMenuButtonItem? buttonItem;

  /// {@template flutter.cupertino.CustomCupertinoTextSelectionToolbarButton.text}
  /// The text used in the button's label when using
  /// [CustomCupertinoTextSelectionToolbarButton.text].
  /// {@endtemplate}
  final String? text;

  /// Returns the default button label String for the button of the given
  /// [ContextMenuButtonItem]'s [ContextMenuButtonType].
  static String getButtonLabel(
      BuildContext context, ContextMenuButtonItem buttonItem) {
    if (buttonItem.label != null) {
      return buttonItem.label!;
    }

    assert(debugCheckHasCupertinoLocalizations(context));
    final CupertinoLocalizations localizations =
        CupertinoLocalizations.of(context);
    switch (buttonItem.type) {
      case ContextMenuButtonType.cut:
        return localizations.cutButtonLabel;
      case ContextMenuButtonType.copy:
        return localizations.copyButtonLabel;
      case ContextMenuButtonType.paste:
        return localizations.pasteButtonLabel;
      case ContextMenuButtonType.selectAll:
        return localizations.selectAllButtonLabel;
      case ContextMenuButtonType.liveTextInput:
      case ContextMenuButtonType.delete:
      case ContextMenuButtonType.custom:
      case ContextMenuButtonType.lookUp:
      case ContextMenuButtonType.searchWeb:
      case ContextMenuButtonType.share:
        return '';
    }
  }

  @override
  State<StatefulWidget> createState() =>
      _CustomCupertinoTextSelectionToolbarButtonState();
}

class _CustomCupertinoTextSelectionToolbarButtonState
    extends State<CustomCupertinoTextSelectionToolbarButton> {
  bool isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => isPressed = false);
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    setState(() => isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _getContentWidget(context);
    final Widget child = CupertinoButton(
      color: isPressed
          ? _kToolbarPressedColor.resolveFrom(context)
          : const Color(0x00000000),
      borderRadius: null,
      disabledColor: const Color(0x00000000),
      // This CupertinoButton does not actually handle the onPressed callback,
      // this is only here to correctly enable/disable the button (see
      // GestureDetector comment below).
      onPressed: widget.onPressed,
      padding: _kToolbarButtonPadding,
      // There's no foreground fade on iOS toolbar anymore, just the background
      // is darkened.
      pressedOpacity: 1.0,
      child: content,
    );

    if (widget.onPressed != null) {
      // As it's needed to change the CupertinoButton's backgroundColor when
      // pressed, not its opacity, this GestureDetector handles both the
      // onPressed callback and the backgroundColor change.
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: child,
      );
    } else {
      return child;
    }
  }

  Widget _getContentWidget(BuildContext context) {
    if (widget.child != null) {
      return widget.child!;
    }
    final Widget textWidget = Text(
      widget.text ??
          CustomCupertinoTextSelectionToolbarButton.getButtonLabel(
              context, widget.buttonItem!),
      overflow: TextOverflow.ellipsis,
      style: _kToolbarButtonFontStyle.copyWith(
        color: widget.onPressed != null
            ? _kToolbarTextColor.resolveFrom(context)
            : CupertinoColors.inactiveGray,
      ),
    );
    if (widget.buttonItem == null) {
      return textWidget;
    }
    switch (widget.buttonItem!.type) {
      case ContextMenuButtonType.cut:
      case ContextMenuButtonType.copy:
      case ContextMenuButtonType.paste:
      case ContextMenuButtonType.selectAll:
      case ContextMenuButtonType.delete:
      case ContextMenuButtonType.custom:
      case ContextMenuButtonType.lookUp:
      case ContextMenuButtonType.searchWeb:
      case ContextMenuButtonType.share:
        return textWidget;
      case ContextMenuButtonType.liveTextInput:
        return SizedBox(
          width: 13.0,
          height: 13.0,
          child: CustomPaint(
            painter: _LiveTextIconPainter(
                color: _kToolbarTextColor.resolveFrom(context)),
          ),
        );
    }
  }
}

class _LiveTextIconPainter extends CustomPainter {
  _LiveTextIconPainter({required this.color});

  final Color color;

  final Paint _painter = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    _painter.color = color;
    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);

    final Offset origin = Offset(-size.width / 2.0, -size.height / 2.0);
    // Path for the one corner.
    final Path path = Path()
      ..moveTo(origin.dx, origin.dy + 3.5)
      ..lineTo(origin.dx, origin.dy + 1.0)
      ..arcToPoint(Offset(origin.dx + 1.0, origin.dy),
          radius: const Radius.circular(1))
      ..lineTo(origin.dx + 3.5, origin.dy);

    // Rotate to draw corner four times.
    final Matrix4 rotationMatrix = Matrix4.identity()..rotateZ(pi / 2.0);
    for (int i = 0; i < 4; i += 1) {
      canvas.drawPath(path, _painter);
      canvas.transform(rotationMatrix.storage);
    }

    // Draw three lines.
    canvas.drawLine(
        const Offset(-3.0, -3.0), const Offset(3.0, -3.0), _painter);
    canvas.drawLine(const Offset(-3.0, 0.0), const Offset(3.0, 0.0), _painter);
    canvas.drawLine(const Offset(-3.0, 3.0), const Offset(1.0, 3.0), _painter);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveTextIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
