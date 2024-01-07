import 'package:flutter/material.dart';
import 'package:open_earable/apps/head_trainer/logic/orientation_value_updater.dart';
import 'package:open_earable/apps/head_trainer/logic/sequence_calculator.dart';
import 'package:open_earable/apps/head_trainer/widget/move_card.dart';

import '../model/sequence.dart';

class SequenceView extends StatefulWidget {
  const SequenceView({
    super.key,
    required this.sequence,
    required this.orientationValueUpdater,
  });

  final OrientationValueUpdater orientationValueUpdater;
  final Sequence sequence;

  @override
  State<SequenceView> createState() => _SequenceViewState(sequence,
      orientationValueUpdater);
}

class _SequenceViewState extends State<SequenceView> {

  final OrientationValueUpdater _oriValueUpdater;
  final Sequence _sequence;

  late SequenceCalculator _sequenceCalculator;
  int _currentPos = 0;
  double _progress = 0;
  int _currentDegree = 0;

  _SequenceViewState(this._sequence, this._oriValueUpdater);

  _updateCurrentValues() {
    setState(() {
      _currentPos = _sequenceCalculator.currentPosition;

      if (_sequenceCalculator.currentMoveProgress != null) {
        _progress = _sequenceCalculator.currentMoveProgress!;
      }

      if (_sequenceCalculator.currentMoveProbability != null) {
        _currentDegree = (_sequenceCalculator.currentMoveProbability! * 90)
            .toInt();
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _sequenceCalculator = SequenceCalculator(
        sequence: _sequence,
        oriValueOffset: _oriValueUpdater.valueOffset,
        oriValueUpdater: _oriValueUpdater,
        onUpdate: () => _updateCurrentValues());
    _sequenceCalculator.startCalculator();
  }

  @override
  void dispose() {
    super.dispose();

    _sequenceCalculator.stopCalculator();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> moveCards = List.empty(growable: true);

    for (final (index, move) in _sequence.moves.indexed) {
      if ((index - _currentPos).abs() > 2) {
        continue;
      }

      moveCards.add(MoveCard(
        move: move,
        size: index > _currentPos ? 1 - ((index - _currentPos) * 0.1) : 1,
        percentFinished: index == _currentPos ? _progress :
            index < _currentPos ? 1 : 0,
        currentDegree: _currentPos == index ? _currentDegree : null,
      ));
    }

    moveCards = List.from(moveCards.reversed);

    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text(_sequence.name),
          actions: [],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: moveCards,
        ),
    );
  }
}
