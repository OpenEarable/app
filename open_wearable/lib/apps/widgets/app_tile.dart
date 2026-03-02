import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';

class AppTile extends StatelessWidget {
  final AppInfo app;

  const AppTile({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
        title: PlatformText(app.title),
        subtitle: PlatformText(app.description),
        leading: SizedBox(
          height: 50.0,
          width: 50.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              app.logoPath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            platformPageRoute(context: context, builder: (context) => app.widget),
          );
        },
      );
  }
}
