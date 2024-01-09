import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'stapel_abfragen.dart';


// Karteikarten ist ein StatefulWidget, das für die Darstellung und das Management von Karteikarten zuständig ist.
class Karteikarten extends StatefulWidget {
  // Deklaration von notwendigen Variablen und Objekten.
  final AttitudeTracker _attitudeTracker;

  final String stapelName;
  final OpenEarable _openEarable;
  // Konstruktor für die Klasse Karteikarten.
  Karteikarten(this.stapelName, this._openEarable, this._attitudeTracker);

  @override
  _KarteikartenState createState() => _KarteikartenState(_openEarable, _attitudeTracker);

}
// Der State für die Karteikarten, der den aktuellen Zustand des Widgets verwaltet.
class _KarteikartenState extends State<Karteikarten> {
  AttitudeTracker _attitudeTracker;

  final OpenEarable _openEarable;

  final TextEditingController _textController = TextEditingController();
  bool _boolValue = false;
  List<Map<String, dynamic>> _paare = [];
  // Konstruktor für den State.
  _KarteikartenState(this._openEarable, this._attitudeTracker);

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  // Methode, um ein neues Paar hinzuzufügen.
  void _addPaar() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Achtung: Fragenfeld darf nicht leer sein'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }      // Fügt das neue Paar zur Liste hinzu und speichert die Daten
    setState(() {
      _paare.add({'satz': _textController.text, 'wert': _boolValue});
      _textController.clear();
      _boolValue = false;
      _saveData();
    });
  }  // Methode, um die Daten zu speichern.
  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = json.encode(_paare);
    await prefs.setString('karteikarten_daten_${widget.stapelName}', encodedData);
  }
  // Laden der Daten von einem eindeutigen Schlüssel
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? encodedData = prefs.getString('karteikarten_daten_${widget.stapelName}');
    if (encodedData != null) {
      List<dynamic> decodedData = json.decode(encodedData);
      setState(() {
        _paare = decodedData.map((item) => Map<String, dynamic>.from(item)).toList();
      });
    }
  }
  // Löschen einer Karteikarte aus dem Stapel
  void _deletePaar(int index) {
    setState(() {
      _paare.removeAt(index);
      _saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fragen Speichern'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),// Funktion zum zurück gehen
        ),
      ),

      body: Column(
        children: <Widget>[
          TextField(
            controller: _textController,
            decoration: InputDecoration(labelText: 'Geben sie die Frage ein'),
          ),
          SwitchListTile(
            title: Text("Ist die Antwort Wahr"),
            value: _boolValue,
            onChanged: (bool value) {// Funktion, die bei Änderung des Switch-Wertes aufgerufen
              setState(() {
                _boolValue = value;// Aktualisiert den Wert von _boolValue
              });
            },
          ),
          ElevatedButton(
            onPressed: _addPaar, //ruft _addPaar auf der aktuelle Inhalt des Textfeldes und der wahr/falsch wert werden hinzugefügt
            child: Text('Frage abspeichern'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _paare.length,// Anzahl der Karteikarten im Stapel
              itemBuilder: (context, index) {// Builder für jedes Element der Liste
                return ListTile(
                  title: Text(_paare[index]['satz']),// Anzeige des Satzes der Karteikarte
                  trailing: Wrap(
                    spacing: 12,
                    children: <Widget>[
                      Icon(
                        _paare[index]['wert'] ? Icons.check : Icons.close,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deletePaar(index),// Funktion zum Löschen des Paares
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FrageAbfrage( _paare, _openEarable, _attitudeTracker,),// Leitet zum Fragen Abfragen Screen weiter
                ),
              );
            },
            child: Text('Fragen abfragen'),
          )
        ],
      ),
    );
  }




}

