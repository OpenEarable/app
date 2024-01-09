import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Karteikarten.dart';

//Ich hoffe das ich nichts vergessen habe hochzuladen falls sie das gefühl haben ich habe zu viele von den build datein weggelassen geben sie mir gerne bescheid

class MainScreen extends StatefulWidget {
  final OpenEarable _openEarable; //openEarable für jingle ausgabe
  final AttitudeTracker _attitudeTracker;// attitude Tracker für nicken und kopschütteln

  MainScreen(this._openEarable, this._attitudeTracker);


  @override
  _MainScreenState createState() => _MainScreenState(_openEarable, _attitudeTracker);



}

class _MainScreenState extends State<MainScreen> {
  final OpenEarable _openEarable;
  AttitudeTracker _attitudeTracker;

  _MainScreenState(this._openEarable, this._attitudeTracker);


  final TextEditingController _stapelNameController = TextEditingController();

  List<String> _stapelNamen = [];  // Alle Karteikarten Stapel des Benutzers

  void initState() {
    super.initState();
    _loadStapelNamen(); //
  }

  void _saveStapelNamen() async {  //    Speichert die Liste _stapelNamen in den SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('stapel_namen', _stapelNamen);
  }
  void _loadStapelNamen() async {  //Lädt die Liste _stapelNamen aus den SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stapelNamen = prefs.getStringList('stapel_namen') ?? [];
    });
  }
  void _removeStapelName(String stapelName) async { // Entfernt einen spezifischen stapel Namen aus der Liste _stapelNamen und aktualisiert die SharedPreferences.
    setState(() {
      _stapelNamen.remove(stapelName);
    });
    _saveStapelNamen();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Karteikarten Stapel auswählen')),
      body: Column(
        children: [
          TextField(
            controller: _stapelNameController,
            decoration: InputDecoration(labelText: 'Stapelname eingeben'),
          ),
          ElevatedButton(
            onPressed: () {//Benutzer kann neuen Karteikartenstapel erstellen
              if (_stapelNameController.text.isNotEmpty) {
                setState(() {
                  _stapelNamen.add(_stapelNameController.text);
                  _saveStapelNamen();
                  _stapelNameController.clear();
                });
              }
            },
            child: Text('Stapel erstellen'),
          ),

          Expanded(//Liste der aktuellen Stapel
            child: ListView.builder(
              itemCount: _stapelNamen.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_stapelNamen[index]),
                  onTap: () {// Falls der jeweilige Stapel gedrückt wird wird zum Karteikarten Screen weitergeleitet
                    Navigator.push(
                      context,
                      MaterialPageRoute(

                        builder: (context) => Karteikarten(_stapelNamen[index], _openEarable, _attitudeTracker),
                      ),
                    );
                  },
                  trailing: IconButton( //Button zum löschen des jeweiligen Stapels
                    icon: Icon(Icons.delete),
                    onPressed: () => _removeStapelName(_stapelNamen[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}