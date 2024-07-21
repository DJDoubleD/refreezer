import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings.dart';

class LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const LeadingIcon(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.0,
      height: 42.0,
      decoration:
          BoxDecoration(color: (color ?? Theme.of(context).primaryColor).withOpacity(1.0), shape: BoxShape.circle),
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );
  }
}

//Container with set size to match LeadingIcon
class EmptyLeading extends StatelessWidget {
  const EmptyLeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 42.0, height: 42.0);
  }
}

class FreezerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  //Should be specified if bottom is specified
  final double height;

  const FreezerAppBar(this.title, {super.key, this.actions = const [], this.bottom, this.height = 56.0});

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(primaryColor: (Theme.of(context).brightness == Brightness.light) ? Colors.white : Colors.black),
      child: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(statusBarBrightness: Theme.of(context).brightness),
        elevation: 0.0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: (Theme.of(context).brightness == Brightness.light) ? Colors.black : Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: actions,
        bottom: bottom as PreferredSizeWidget?,
      ),
    );
  }
}

class FreezerDivider extends StatelessWidget {
  const FreezerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      thickness: 1.5,
      indent: 16.0,
      endIndent: 16.0,
    );
  }
}

TextStyle popupMenuTextStyle() {
  return TextStyle(color: settings.isDark ? Colors.white : Colors.black);
}
