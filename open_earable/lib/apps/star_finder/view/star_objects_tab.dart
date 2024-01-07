import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/model/earable_attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/view/star_finder_view.dart';
import 'package:open_earable/apps/star_finder/view_model/star_finder_view_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StarObjectInfo {
  final IconData iconData;
  final String name;
  final String description;
  final VoidCallback onTap;

  StarObjectInfo(
      {required this.iconData,
      required this.name,
      required this.description,
      required this.onTap});
}


class StarObjectsTab extends StatefulWidget {
  final StarFinderViewModel viewModel;

  StarObjectsTab(this.viewModel);

  @override
  _StarObjectsTabState createState() => _StarObjectsTabState();
}

class _StarObjectsTabState extends State<StarObjectsTab> {
  List<StarObjectInfo> starObjects(BuildContext context) {
    List<StarObject> stars = StarObjectList.starObjects;
    return stars.map((starObject) => StarObjectInfo(
        iconData: starObject,
        name: starObject.name,
        description: starObject.description,
        onTap: () {
          setState(() {
            widget.viewModel.setStarObject(starObject);
          });
        }
      )).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<StarObjectInfo> stars = starObjects(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Choose a Star Object")),
      body: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: ListView.builder(
          itemCount: stars.length,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Card(
                color: widget.viewModel.starObject.name == stars[index].name
                    ? Colors.blue
                    : Theme.of(context).colorScheme.primary,
                child: ListTile(
                  leading: Icon(stars[index].iconData, size: 40.0),
                  title: Text(stars[index].name),
                  subtitle: Text(stars[index].description),
                  contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  onTap: stars[index].onTap,
                ),
              )
            );
          },
        )
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}
