import 'package:flutter/cupertino.dart';

import '../Classes/AppUser.dart';
import '../repositories/UserRepository.dart';

class ProfileViewModel with ChangeNotifier {
  final UserRepository _repository = UserRepository();

  AppUser? profileData;
  int reviews = 0;
  int playlists = 0;

  bool isLoaded = false;

  Future<void> loadFullProfileData() async {
    if (isLoaded) return;

    profileData = await _repository.loadMyBasicData();
    final counts = await _repository.loadCounts();

    reviews = counts['reviews'] ?? 0;
    playlists = counts['playlists'] ?? 0;

    isLoaded = true;
    notifyListeners();
  }
}
