import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/controller/star_finder_controller.dart';
//import 'package:open_earable/apps/star_finder/model/XXX.dart';

class StarFinderView extends StatefulWidget {
  const StarFinderView({super.key});



  @override
  State<StarFinderView> createState() => _StarFinderViewState();
}

class _StarFinderViewState extends State<StarFinderView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Star Finder")),
      //body: ,
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}