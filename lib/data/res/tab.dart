import 'package:flutter/material.dart';
import 'package:toolbox/data/model/app/navigation_item.dart';

final List<String> tabs = ['Servers', 'En/Decode', 'Ping'];
final List<NavigationItem> tabItems = [
    NavigationItem(Icons.computer, 'Server'),
    NavigationItem(Icons.code, 'Convert'),
    NavigationItem(Icons.network_check, 'Ping'),
  ];
