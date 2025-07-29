import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Classes/ActivityItem.dart';

class ActivityAdapter extends StatelessWidget {
  final List<ActivityItem> items;
  final int tabIndex;

  const ActivityAdapter({
    Key? key,
    required this.items,
    this.tabIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          "Nessuna attività trovata",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final timestamp = item.timestamp?.toDate();
        final formattedDate = timestamp != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
            : 'Data non disponibile';

        return Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
