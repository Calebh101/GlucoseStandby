import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showSnackBar(context, String content) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(content)),
  );
}

Future<bool> showAlertDialogue(BuildContext context, String title, String text, bool cancel, Map copy) {
  if (copy["text"] == null) {
    copy["text"] = text;
  }
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          copy["show"] ? TextButton(
            child: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copy["text"]));
              showSnackBar(context, "Copied to clipboard!");
            },
          ) : const SizedBox.shrink(),
          cancel ? TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ) : const SizedBox.shrink(),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  ) as Future<bool>;
}
