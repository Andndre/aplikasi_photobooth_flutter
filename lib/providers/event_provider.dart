import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:provider/provider.dart';

class EventsProvider with ChangeNotifier {
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

  // Ensure the saveEvents method is properly implemented
  Future<void> saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert events to JSON list
      final eventsJsonList = _events.map((event) => event.toJson()).toList();
      final eventsJson = jsonEncode(eventsJsonList);

      // Save to SharedPreferences
      await prefs.setString('events', eventsJson);

      print('Events saved successfully: ${_events.length} events');
      notifyListeners();
    } catch (e) {
      print('Error saving events: $e');
      rethrow; // Re-throw to allow handling elsewhere
    }
  }

  // Add a method to update an event's preset
  void updateEventPreset(int eventId, PresetModel preset) {
    final index = _events.indexWhere((event) => event.layoutId == eventId);
    if (index != -1) {
      _events[index].updatePreset(preset);
      _saveToLocalStorage();
      notifyListeners();
    }
  }

  // Update a method to get an event's preset
  PresetModel? getEventPreset(BuildContext context, int eventId) {
    // Find the event by ID
    final event = _events.firstWhereOrNull(
      (event) => event.layoutId == eventId,
    );

    // If no event found, return null
    if (event == null) return null;

    // Get the preset from the PresetProvider using the event's presetId
    final presetProvider = Provider.of<PresetProvider>(context, listen: false);
    return presetProvider.getPresetById(event.presetId) ??
        presetProvider.activePreset ??
        PresetModel.defaultPreset();
  }

  // Add method to get event by name
  EventModel? getEventByName(String name) {
    try {
      return _events.firstWhere((event) => event.name == name);
    } catch (e) {
      return null;
    }
  }

  // Ensure we have a method to find event by ID
  EventModel? getEventById(String id) {
    try {
      return _events.firstWhere((event) => event.id == id);
    } catch (e) {
      print('Event with ID $id not found');
      return null;
    }
  }
}
