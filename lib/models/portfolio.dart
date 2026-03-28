import 'package:flutter/material.dart';

class PortfolioItem {
  final String name;
  final double value;
  final Color color;

  PortfolioItem({
    required this.name,
    required this.value,
    required this.color,
  });
}

class ProjectionData {
  final int year;
  final double value;

  ProjectionData({
    required this.year,
    required this.value,
  });
}

class StockData {
  final String name;
  final String price;
  final String change;
  final String pe;
  final String trend;
  final String range;

  StockData({
    required this.name,
    required this.price,
    required this.change,
    required this.pe,
    required this.trend,
    required this.range,
  });
}
