import 'package:open_earable/apps/driving_assistant/view/observer.dart';

abstract class Subject{
  void registerObserver(Observer observer);
  void removeObserver(Observer observer);
  void notifyObservers(int tirednessCounter);
}