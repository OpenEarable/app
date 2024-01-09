import 'package:flutter/material.dart';
import 'session_page.dart';
import '../model/session.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import '../model/utility.dart';

class ConfigPage extends StatefulWidget {
  final OpenEarable _openEarable;
  final title = "new Learning Session";
  ConfigPage(this._openEarable);
  @override
  _ConfigPageState createState() => _ConfigPageState(_openEarable);
}

class _ConfigPageState extends State<ConfigPage> {
  final OpenEarable _openEarable;
  _ConfigPageState(this._openEarable);
  final TextEditingController taskController = TextEditingController();
  final TextEditingController setupController = TextEditingController();
  final TextEditingController hoursAwakeController = TextEditingController();
  final TextEditingController textFieldController = TextEditingController();
  Setup? selectedSetup;
  HoursAwake? selectedHoursAwake;
  // check if the form is fully filled with data
  bool formCompleted() {
    return selectedSetup != null && selectedHoursAwake != null;
  }

  // proceed to the session page
  startSession() {
    bool formFilled = formCompleted();
    if (formFilled) {
      Session createdSession = Session(selectedHoursAwake!.percentageOfMax, selectedSetup);
      Navigator.push(context, MaterialPageRoute(builder: (context) => SessionPage(_openEarable, createdSession)));
    } else {
      // FehlerMeldung!!
    }
  }

  // build the page to configure the session
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 100, height: 45, child: Text("Select your Setup.")),
            DropdownMenu<Setup>(
              controller: setupController,
              dropdownMenuEntries: Setup.values.map<DropdownMenuEntry<Setup>>((Setup e) {
                return DropdownMenuEntry(value: e, label: e.name);
              }).toList(),
              onSelected: (Setup? setup) {
                setState(() {
                  selectedSetup = setup;
                });
              },
            )
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 200, height: 45, child: Text("Select how many Hours you are approximately awake.")),
            DropdownMenu<HoursAwake>(
              controller: hoursAwakeController,
              dropdownMenuEntries: HoursAwake.values.map<DropdownMenuEntry<HoursAwake>>((HoursAwake e) {
                return DropdownMenuEntry(value: e, label: e.name);
              }).toList(),
              onSelected: (HoursAwake? hoursAwake) {
                setState(() {
                  selectedHoursAwake = hoursAwake;
                });
              },
            )
          ]),
        ],
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: startSession,
        child: Icon(
          Icons.done,
          color: Colors.black,
        ),
      ),
    );
  }
}
