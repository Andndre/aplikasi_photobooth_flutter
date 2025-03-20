import 'package:aplikasi_photobooth_flutter/models/layouts.dart';
import 'package:aplikasi_photobooth_flutter/providers/layouts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class Event {
  String name;
  String description;
  String date;
  int layoutId;
  String saveFolder;
  String uploadFolder;

  Event({
    required this.name,
    required this.description,
    required this.date,
    required this.layoutId,
    required this.saveFolder,
    required this.uploadFolder,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      name: json['name'],
      description: json['description'],
      date: json['date'],
      layoutId: json['layoutId'],
      saveFolder: json['saveFolder'],
      uploadFolder: json['uploadFolder'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'date': date,
      'layoutId': layoutId,
      'saveFolder': saveFolder,
      'uploadFolder': uploadFolder,
    };
  }

  Layouts getLayout(BuildContext context) {
    return Provider.of<LayoutsProvider>(
      context,
      listen: false,
    ).layouts.firstWhere((layout) => layout.id == layoutId);
  }
}
