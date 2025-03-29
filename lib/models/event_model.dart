import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class EventModel {
  String name;
  String description;
  String date;
  int layoutId;
  String saveFolder;
  String uploadFolder;

  EventModel({
    required this.name,
    required this.description,
    required this.date,
    required this.layoutId,
    required this.saveFolder,
    required this.uploadFolder,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
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

  LayoutModel getLayout(BuildContext context) {
    return Provider.of<LayoutsProvider>(
      context,
      listen: false,
    ).layouts.firstWhere((layout) => layout.id == layoutId);
  }

  bool hasValidLayout(BuildContext context) {
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );
    return layoutsProvider.layouts.any((layout) => layout.id == layoutId);
  }
}
