import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/item_model.dart';

class ItemTile extends StatelessWidget {
  final FollowItem item;
  final VoidCallback onTap;

  const ItemTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: FaIcon(
        item.type == ItemType.folder
            ? FontAwesomeIcons.folder
            : FontAwesomeIcons.fileLines,
        color: item.isExpired ? Colors.red : null,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          color: item.isExpired ? Colors.red : null,
          decoration: item.isExpired ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: item.type == ItemType.document
          ? Text("Vence: ${item.expirationHint}")
          : null,
    );
  }
}
