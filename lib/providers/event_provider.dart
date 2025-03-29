import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventsProvider extends ChangeNotifier {
  List<EventModel> _events = [];

  List<EventModel> get events => _events;

  Future<void> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsString = prefs.getString('events');
    if (eventsString != null) {
      final List<dynamic> eventsJson = json.decode(eventsString);
      _events = eventsJson.map((json) => EventModel.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> addEvent(EventModel event) async {
    _events.add(event);
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> editEvent(int index, EventModel event) async {
    _events[index] = event;
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> removeEvent(int index) async {
    _events.removeAt(index);
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> _saveToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsString = json.encode(
      _events.map((event) => event.toJson()).toList(),
    );
    prefs.setString('events', eventsString);
  }
}
