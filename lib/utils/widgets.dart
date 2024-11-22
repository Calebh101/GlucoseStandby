import 'dart:ui';
import 'package:flutter/material.dart';

Widget Setting({
  required String title,
  required String desc,
  required String text,
  required GestureTapCallback action,
  }) {
  return InkWell(
    onTap: action,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            text,
          )
        ],
      ),
    ),
  );
}

Widget SettingTitle({
  required String title,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
      ),
    ),
  );
}

Widget SettingButton({
  required String title,
  required GestureTapCallback action,
  required BuildContext context,
}) {
  return Center(
    child: ElevatedButton(
      onPressed: action,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(MediaQuery.of(context).size.width * 0.9, 40),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        textStyle: const TextStyle(fontSize: 18),
      ),
      child: Text(title),
    ),
  );
}