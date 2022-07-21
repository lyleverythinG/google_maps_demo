import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auto_complete.dart';

final placeResultsProvider = ChangeNotifierProvider<PlaceResults>((ref) {
  return PlaceResults();
});

final searchToggleProvider = ChangeNotifierProvider<SearchToggle>((ref) {
  return SearchToggle();
});

class PlaceResults extends ChangeNotifier {
  List<AutoCompleteResult> allReturnedResults = [];

  void setResults({required allPlaces}) {
    allReturnedResults = allPlaces;
    notifyListeners();
  }
}

class SearchToggle extends ChangeNotifier {
  bool searchToggle = false;

  void toggleSearch() {
    searchToggle = !searchToggle;
    notifyListeners();
  }
}
