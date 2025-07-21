import 'package:flutter/material.dart';
import '../Classes/AppUser.dart';
import '../repositories/UserRepository.dart';

class ProfileViewModel with ChangeNotifier {
  final UserRepository _repository = UserRepository();

  AppUser? profileData;
  bool isLoaded = false;

  Future<void> loadBasicUserData() async {
    if (isLoaded) return;
    profileData = await _repository.loadMyBasicData();
    isLoaded = true;
    notifyListeners();
  }
}
