import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Classes/AppUser.dart'; // Assicurati che il tuo model User sia qui

class UserAdapter extends StatefulWidget {
  final int tabIndex;
  final List<AppUser> users;
  final void Function(AppUser user) onUserClick;

  const UserAdapter({
    required this.tabIndex,
    required this.users,
    required this.onUserClick,
    super.key,
  });

  @override
  State<UserAdapter> createState() => _UserAdapterState();
}

class _UserAdapterState extends State<UserAdapter> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.users.length,
      itemBuilder: (context, index) {
        final user = widget.users[index];

        return ListTile(
          title: Text(user.username, style: TextStyle(color: Colors.white)),
          subtitle: Text('${user.firstName} ${user.lastName}', style: TextStyle(color: Colors.grey)),
          onTap: () => widget.onUserClick(user),
          onLongPress: () => _showPopup(context, user),
        );
      },
    );
  }

  void _showPopup(BuildContext context, AppUser user) {
    if (_currentUserId == null || _currentUserId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Non puoi seguire te stesso")),
      );
      return;
    }

    showMenu(
      context: context,
      position: RelativeRect.fill,
      items: [
        if (widget.tabIndex == 0)
          PopupMenuItem(
            value: 'follow',
            child: Text('Segui'),
          ),
        if (widget.tabIndex == 2)
          PopupMenuItem(
            value: 'unfollow',
            child: Text('Non seguire più'),
          ),
      ],
    ).then((value) async {
      if (value == 'follow') {
        final success = await _followUser(user.id);
        if (success) {
          await _logActivity(user, 'follow');
          _showToast("Ora segui ${user.username}");
        } else {
          _showToast("Segui già ${user.username}");
        }
      } else if (value == 'unfollow') {
        await _unfollowUser(user.id);
        await _logActivity(user, 'unfollow');
        _showToast("Non segui più ${user.username}");
      }
    });
  }

  Future<bool> _followUser(String targetUserId) async {
    final db = FirebaseFirestore.instance;
    final currentUserId = _currentUserId!;
    final currentRef = db.collection('User').doc(currentUserId);
    final targetRef = db.collection('User').doc(targetUserId);

    final followerDoc = targetRef.collection('followersList').doc(currentUserId);
    final already = await followerDoc.get();
    if (already.exists) return false;

    final batch = db.batch();
    batch.set(followerDoc, {'followedAt': Timestamp.now()});
    batch.set(currentRef.collection('followingList').doc(targetUserId), {'followedAt': Timestamp.now()});
    batch.update(currentRef, {'following': FieldValue.increment(1)});
    batch.update(targetRef, {'followers': FieldValue.increment(1)});

    await batch.commit();
    return true;
  }

  Future<void> _unfollowUser(String targetUserId) async {
    final db = FirebaseFirestore.instance;
    final currentUserId = _currentUserId!;
    final currentRef = db.collection('User').doc(currentUserId);
    final targetRef = db.collection('User').doc(targetUserId);

    final batch = db.batch();
    batch.delete(targetRef.collection('followersList').doc(currentUserId));
    batch.delete(currentRef.collection('followingList').doc(targetUserId));
    batch.update(currentRef, {'following': FieldValue.increment(-1)});
    batch.update(targetRef, {'followers': FieldValue.increment(-1)});

    await batch.commit();
  }

  Future<void> _logActivity(AppUser target, String type) async {
    await FirebaseFirestore.instance
        .collection('User')
        .doc(target.id)
        .collection('ActivityForOthers')
        .add({
      'actionType': type,
      'sourceUserId': _currentUserId!,
      'targetUserId': target.id,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final message = type == 'follow'
        ? "Hai iniziato a seguire ${target.username}"
        : "Hai smesso di seguire ${target.username}";

    await FirebaseFirestore.instance
        .collection('User')
        .doc(_currentUserId!)
        .collection('Activity')
        .add({
      'action': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
