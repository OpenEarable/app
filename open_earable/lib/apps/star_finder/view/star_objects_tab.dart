import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/model/earable_attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/view/star_finder_view.dart';
import 'package:open_earable/apps/star_finder/view_model/star_finder_view_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StarObjectInfo {
  final IconData iconData;
  final String title;
  final String description;
  final VoidCallback onTap;

  StarObjectInfo(
      {required this.iconData,
      required this.title,
      required this.description,
      required this.onTap});
}


class StarObjectsTab extends StatelessWidget {

  final StarFinderViewModel _viewModel;

  StarObjectsTab(StarFinderViewModel this._viewModel);

  List<StarObjectInfo> starObjects(BuildContext context) {
  // Define your stars here
  List<StarObject> stars = StarObjectList.starObjects;

  // Map the stars to StarObjectInfo
  return stars.map((starObject) => StarObjectInfo(
      iconData: starObject.icon,
      title: starObject.name,
      description: starObject.description,
      onTap: () {
        _viewModel.setStarObject(starObject);
      }
    )).toList();
}

  @override
  Widget build(BuildContext context) {
    List<StarObjectInfo> stars = starObjects(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Chose a Star Object")),
      body: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: ListView.builder(
          itemCount: stars.length,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Card(
                  color: Theme.of(context).colorScheme.primary,
                  child: ListTile(
                    leading: Icon(stars[index].iconData, size: 40.0),
                    title: Text(stars[index].title),
                    subtitle: Text(stars[index].description),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16.0), // Arrow icon on the right
                    contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), // Increase padding
                    onTap:
                        stars[index].onTap, // Callback when the card is tapped
                  ),
                ));
          },
        )),
        backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}
