import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/item_model.dart';

class ItemTile extends StatelessWidget {
  final FollowItem item;
  final VoidCallback onTap;

  const ItemTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isExpired = item.isExpired;
    return ListTile(
      // onTap: onTap,
      // leading: FaIcon(
      //   item.type == ItemType.folder
      //       ? FontAwesomeIcons.folder
      //       : FontAwesomeIcons.fileLines,
      //   color: item.isExpired ? Colors.red : null,
      // ),
      leading: Icon(
        item.type == ItemType.folder ? Icons.folder : Icons.description,
        color: isExpired ? Colors.red : Colors.blue,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          color: item.isExpired ? Colors.red : Colors.black,
          // decoration: item.isExpired
          //     ? TextDecoration.lineThrough
          //     : null, // Regla de negocio
          fontWeight: item.isExpired ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      // subtitle: item.type == ItemType.document
      //     ? Text("Vence: ${item.expirationHint}")
      //     : null,
      subtitle: Text("Vence: ${item.expirationDate}"),
    );
  }
}
