import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/view_model/star_finder_view_model.dart';

/// Represents all relevant star object information for the view
class StarObjectInfo {
  final String image; // The image URL of the star object
  final String name; // Name of the star object
  final String description; // Description of the star object
  final VoidCallback onTap; // Callback function to be executed on tap

  StarObjectInfo(
      {required this.image,
      required this.name,
      required this.description,
      required this.onTap});
}

/// A stateful widget that represents a tab displaying star objects
class StarObjectsTab extends StatefulWidget {
  final StarFinderViewModel viewModel; // ViewModel for the StarFinder app

  StarObjectsTab(this.viewModel);

  @override
  _StarObjectsTabState createState() => _StarObjectsTabState();
}

class _StarObjectsTabState extends State<StarObjectsTab> {
  /// Generates a list of StarObjectInfo from the StarObjectList
  List<StarObjectInfo> starObjects(BuildContext context) {
    List<StarObject> stars = StarObjectList.starObjects;
    return stars
        .map((starObject) => StarObjectInfo(
            image: starObject.image,
            name: starObject.name,
            description: starObject.description,
            onTap: () {
              setState(() {
                widget.viewModel
                    .setStarObject(starObject); // change active Star Object
              });
            }))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    List<StarObjectInfo> stars = starObjects(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Choose a Star Object")),
      body: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: ListView.builder(
            itemCount: stars.length, // The number of items in the list
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  // creation of the Star Object entires
                  child: Card(
                    color: widget.viewModel.starObject.name == stars[index].name
                        ? Colors.blue // Highlights the selected star object
                        : Theme.of(context).colorScheme.primary,
                    child: ListTile(
                      leading:
                          Image.asset(stars[index].image, width: 60, height: 60,
                              errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error);
                      }), // Fallback icon in case of error
                      title: Padding(
                        padding: EdgeInsets.only(bottom: 8.0), // Adjust the value as needed
                        child: Text(
                          stars[index].name,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      subtitle: Text(stars[index].description),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 20.0, horizontal: 25.0),
                      onTap: stars[index].onTap, // Executes the onTap callback when tapped
                    ),
                  ));
            },
          )),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}
