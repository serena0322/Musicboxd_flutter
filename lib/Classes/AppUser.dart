import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final int followers;
  final int following;
  final Timestamp createdAt;
  final dynamic like;

  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.followers,
    required this.following,
    required this.createdAt,
    required this.like,
  });

  // Factory constructor to create an instance from Firestore document
  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppUser(
      id: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      followers: (data['followers'] ?? 0) as int,
      following: (data['following'] ?? 0) as int,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      like: data['likes'] ?? '',
    );
  }

  // Method to convert the instance to a Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'followers': followers,
      'following': following,
      'createdAt': createdAt,
      'likes': like,
    };
  }
}
