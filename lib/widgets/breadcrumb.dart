import 'package:flutter/material.dart';

class BreadcrumbItem {
  final String label;
  final String? route;
  BreadcrumbItem(this.label, {this.route});
}

class Breadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final void Function(int index)? onTap;
  final TextStyle? style;
  final Color? separatorColor;

  const Breadcrumb({
    super.key,
    required this.items,
    this.onTap,
    this.style,
    this.separatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500);
    final sepColor = separatorColor ?? Colors.grey[400];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 4),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.chevron_right, size: 20, color: sepColor),
              ),
            GestureDetector(
              onTap: onTap != null && i < items.length - 1 && (items[i].route != null)
                  ? () => onTap!(i)
                  : null,
              child: Text(
                items[i].label,
                style: textStyle.copyWith(
                  color: i == items.length - 1 ? Colors.black : Colors.black87,
                  fontWeight: i == items.length - 1 ? FontWeight.bold : FontWeight.normal,
                  decoration: onTap != null && i < items.length - 1 && (items[i].route != null)
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
