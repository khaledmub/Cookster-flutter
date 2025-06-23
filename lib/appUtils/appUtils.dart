import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../appUtils/colorUtils.dart';

class AppUtils {
  static Widget customPasswordTextField({
    required String labelText,
    bool enabled = true,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool readonly = false,
    Function(String)? onChanged, // Optional onChanged function
    FocusNode? focusNode, // Focus node parameter
    TextInputAction? textInputAction, // Text input action parameter
    Function(String)? onSubmitted, // onSubmitted callback
    VoidCallback? toggleObscureText, // Toggle function for obscure text
    bool isPasswordField = false, // Indicator for password field
    String? Function(String?)? validator,
    String? svgIconPath, // SVG Icon path provided by the user
    int maxLines = 1, // Optional maxLines parameter with default value 1
    // Add a new parameter for form key to trigger validation
    GlobalKey<FormFieldState>? fieldKey,
  }) {
    return TextFormField(
      key: fieldKey,
      // Add the key to access the field state
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      autofocus: false,
      readOnly: readonly,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: (value) {
        // Clear error when user starts typing
        if (fieldKey != null) {
          // This will clear the error and reset the border
          fieldKey.currentState?.validate();
        }

        // Still call the original onChanged if provided
        if (onChanged != null) {
          onChanged(value);
        }
      },
      textInputAction: textInputAction ?? TextInputAction.done,
      validator: validator,
      onFieldSubmitted: (value) {
        if (onSubmitted != null) {
          onSubmitted(value);
        }
      },
      maxLines: maxLines,
      decoration: InputDecoration(
        errorStyle: const TextStyle(fontSize: 13),
        labelStyle: const TextStyle(fontSize: 14),
        labelText: labelText,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Color(0xFFBDBDBD).withOpacity(0.3),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ColorUtils.primaryColor, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFBDBDBD), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        errorMaxLines: 2,
        prefixIcon:
            svgIconPath != null
                ? Container(
                  padding: const EdgeInsets.all(14.0),
                  width: 40,
                  height: 40,
                  child: SvgPicture.asset(
                    svgIconPath,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                )
                : null,
        suffixIcon:
            isPasswordField
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    if (toggleObscureText != null) {
                      toggleObscureText();
                    }
                  },
                )
                : null,
      ),
      focusNode: focusNode,
    );
  }
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color color;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final double width;
  final bool isLoading; // New loading state

  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.color = ColorUtils.primaryColor,
    this.borderRadius = 50.0,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.textStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    this.width = double.infinity,
    this.isLoading = false, // Default false
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap, // Disable tap when loading
      child: Container(
        padding: padding,
        width: width,
        decoration: BoxDecoration(
          color: isLoading ? Colors.grey : color,
          // Grey out button when loading
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        child: Center(
          child:
              isLoading
                  ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(text.tr, style: textStyle.copyWith(fontSize: 14.sp, color: ColorUtils.darkBrown)),
        ),
      ),
    );
  }
}

class CustomTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final String iconPath;
  final TextEditingController controller;
  final VoidCallback? onTap; // Optional onTap
  final bool readOnly; // Optional readOnly
  final String? Function(String?)? validator; // Optional validator
  final bool isPassword; // Optional password field
  final bool obscureText; // To toggle visibility

  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.iconPath,
    required this.controller,
    this.onTap,
    this.readOnly = false,
    this.validator,
    this.isPassword = false, // Default false
    this.obscureText = true, // Default true for password fields
  });

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: ColorUtils.greyTextFieldBorderColor),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.all(8.w),
            child: SvgPicture.asset(widget.iconPath, height: 15.h),
          ),
          Expanded(
            child: TextFormField(
              onTap: widget.onTap,
              readOnly: widget.readOnly,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              controller: widget.controller,
              style: TextStyle(fontSize: 14.sp),
              validator: widget.validator,
              obscureText: widget.isPassword ? _obscureText : false,
              // Hide text if it's a password field
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                hintText: widget.hintText.tr,
                labelText: widget.label.tr,

                suffixIcon:
                    widget.isPassword
                        ? IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: _toggleVisibility,
                        )
                        : null, // Show toggle button only for password fields
              ),
            ),
          ),
        ],
      ),
    );
  }


}



class DynamicStyledText extends StatelessWidget {
  final String text;
  final Set<MaterialState> states; // To simulate MaterialState conditions

  const DynamicStyledText({
    super.key,
    required this.text,
    this.states = const {}, // Default to empty states
  });

  TextStyle _resolveTextStyle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Base text style, matching provided fontSize and fontWeight
    TextStyle baseStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12, // Responsive font size with flutter_screenutil

    ) ??
        TextStyle(
          // fontSize: 12,

        );

    // Resolve TextStyle based on states
    if (states.contains(MaterialState.disabled)) {
      return baseStyle.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.38));
    }
    if (states.contains(MaterialState.error)) {
      if (states.contains(MaterialState.focused)) {
        return baseStyle.copyWith(color: theme.colorScheme.error);
      }
      if (states.contains(MaterialState.hovered)) {
        return baseStyle.copyWith(color: theme.colorScheme.onErrorContainer);
      }
      return baseStyle.copyWith(color: theme.colorScheme.error);
    }
    if (states.contains(MaterialState.focused)) {
      return baseStyle.copyWith(color: theme.colorScheme.primary);
    }
    if (states.contains(MaterialState.hovered)) {
      return baseStyle.copyWith(color: theme.colorScheme.onSurfaceVariant);
    }
    return baseStyle.copyWith(color: theme.colorScheme.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text.tr, // Apply translation using GetX
      style: _resolveTextStyle(context),
    );
  }
}