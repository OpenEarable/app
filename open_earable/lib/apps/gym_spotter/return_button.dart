import 'package:flutter/material.dart';

class returnButton extends StatelessWidget {
  const returnButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 10),
      child: SizedBox(
        height: 50.0,
        width: 50.0,
        child: FloatingActionButton(
            elevation: 0.0,
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(
              Icons.close,
              size: 40.0,
            ),
            onPressed: () {
              Navigator.pop(context);
            }),
      ),
    );
  }
}
