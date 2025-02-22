import 'package:flutter/material.dart';
import 'package:localpkg/dialogue.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

List alertSounds = [
  "Default",
  "Vibrate only",
];

Future<AudioPlayer> playSound(
    BuildContext context, String id, int volume) async {
  print("Playing sound: $id");

  AudioPlayer player = AudioPlayer();
  await player.setVolume(volume / 100);

  switch (id) {
    case "Vibrate only":
      vibrate(context, [0, 500, 500, 500], 1000, true, false);
    case "Default":
      player.play(AssetSource('sounds/alerts/chime.mp3'));
      break;
    default:
      playSound(context, "Default", volume);
      break;
  }

  return player;
}

void vibrate(BuildContext context, List<int> pattern, int defaultVibrate,
    bool showWarning, bool onlyUseSingle) async {
  if ((await Vibration.hasCustomVibrationsSupport()) &&
      !onlyUseSingle) {
    Vibration.vibrate(
      pattern: pattern,
    );
  } else if (await Vibration.hasVibrator()) {
    Vibration.vibrate(duration: defaultVibrate);
  } else {
    if (showWarning) {
      showDialogue(context: context, title: "Vibration Not Supported",
          content: Text("Your device does not support vibrations."));
    }
  }
}

Future<Map> getAllSettings() async {
  print("Getting settings...");

  Map settingsDefaults = {
    "low": 70,
    "high": 180,
    "superlow": 55,
    "superhigh": 240,
    "autodimon": false,
    "autodimvalue": 25,
    "autodimtime": 30,
    "stayawake": false,
    "username": "",
    "password": "",
    "allowalerts": false,
    "superalerts": false,
    "alertsound": "Default",
    "alertvolume": 50,
    "sleeptimer": false,
    "sleeptimertime": 60,
    "showtimer": true,
    "style": "Default",
  };

  final prefs = await SharedPreferences.getInstance();
  List settings = settingsDefaults.keys.toList();
  Map<dynamic, dynamic> jsonMap = {};

  settings.forEach((item) async {
    print("Setting $item...");
    try {
      if (prefs.containsKey(item)) {
        jsonMap[item] = prefs.get(item) ?? settingsDefaults[item];
        print("$item set by SharedPreferences");
      } else if (settingsDefaults[item] != null) {
        jsonMap[item] = settingsDefaults[item];
        print("$item set by default");
      } else {
        throw Exception("$item not set: Null");
      }
    } catch (e) {
      throw Exception("$item not set: Error: $e");
    }
  });

  if (jsonMap["alertsound"] == "Vibrate only" &&
      (await Vibration.hasCustomVibrationsSupport())) {
    jsonMap["alertsound"] = "Default";
  }

  return jsonMap;
}

bool? toBoolean(String value) {
  if (value == 'true' || value == '1') {
    return true;
  } else if (value == 'false' || value == '0') {
    return false;
  } else {
    return null;
  }
}

Map verifyOutput(int mode, dynamic input, Map conditions) {
  print("verifying output: $input with mode $mode");

  if (mode == 1) {
    // string
    String validPattern;
    String validCharactersDefault =
        r'\w\s\-_\~:/\?\&='; // alphanumeric, spaces, basic symbols

    if (conditions["valid"] == null) {
      validPattern = validCharactersDefault;
    } else {
      validPattern =
          conditions["valid"].map((char) => RegExp.escape(char)).join('');
    }

    RegExp validCharactersRegExp = RegExp('^[${validPattern}]*\$');

    if (!validCharactersRegExp.hasMatch(input)) {
      // success
      return {"status": true, "value": input};
    } else {
      return {"status": false, "error": "Invalid characters", "value": input};
    }
  } else if (mode == 2) {
    // int
    int? inputS = input;
    if (inputS != null) {
      if (inputS <= conditions["high"] && inputS >= conditions["low"]) {
        return {"status": true, "value": input};
      } else {
        if (inputS <= conditions["high"]) {
          return {"status": false, "error": "Too low", "value": input};
        } else {
          return {"status": false, "error": "Too high", "value": input};
        }
      }
    } else {
      return {"status": false, "error": "Null"};
    }
  } else if (mode == 3) {
    // slider
    int? inputS = input;
    if (inputS != null) {
      print("checkpoint: 2: $conditions");
      if (inputS <= conditions["max"] && inputS >= conditions["min"]) {
        return {"status": true, "value": input};
      } else {
        if (inputS <= conditions["high"]) {
          return {"status": false, "error": "Too low", "value": input};
        } else {
          return {"status": false, "error": "Too high", "value": input};
        }
      }
    } else {
      return {"status": false, "error": "Null"};
    }
  } else if (mode == 4) {
    // bool
    bool? inputS = input;
    if (inputS != null) {
      return {"status": true, "value": input};
    } else {
      return {"status": false, "error": "Null", "value": input};
    }
  } else if (mode == 5) {
    // list
    String? inputS = input;
    if (inputS != null) {
      return {"status": true, "value": input};
    } else {
      return {"status": false, "error": "Null", "value": input};
    }
  } else {
    // unknown
    return {"status": false, "error": "Unknown type", "value": input};
  }
}

Color decideColorForArrow(int mode, input) {
  if (mode == 1) {
    return input == -3
        ? Colors.red
        : input == -2
            ? Colors.orange
            : input == -1
                ? Colors.yellow
                : input == 1
                    ? Colors.yellow
                    : input == 2
                        ? Colors.orange
                        : input == 3
                            ? Colors.red
                            : Colors.green;
  } else {
    return Colors.green;
  }
}

double decideRotation(int mode, int input) {
  if (mode == 1) {
    return input == 3
        ? 3.14159 / -2
        : input == 2
            ? 3.14159 / -2
            : input == 1
                ? 3.14159 / -4
                : input == -3
                    ? 3.14159 / 2
                    : input == -2
                        ? 3.14159 / 2
                        : input == -1
                            ? 3.14159 / 4
                            : input == 0
                                ? 0
                                : 0;
  } else {
    return 0;
  }
}

Color decideColorForReading(int reading, boundaries) {
  int status = 0;
  if (reading <= boundaries["low"]) {
    // low
    if (reading <= boundaries["superlow"]) {
      // super low
      status = -2;
    } else {
      status = -1;
    }
  } else if (reading >= boundaries["high"]) {
    // high
    if (reading >= boundaries["superhigh"]) {
      // super high
      status = 2;
    } else {
      status = 1;
    }
  } else {
    // in range
    status = 0;
  }

  return status == -2
      ? Colors.red
      : status == -1
          ? Colors.redAccent
          : status == 0
              ? Colors.green
              : status == 1
                  ? Colors.yellowAccent
                  : status == 2
                      ? Colors.orange
                      : Colors.white;
}

int getStatusOfGlucose(int reading, Map boundaries) {
  if (reading >= boundaries["high"]) {
    if (reading >= boundaries["superhigh"]) {
      return 2;
    } else {
      return 1;
    }
  } else if (reading <= boundaries["low"]) {
    if (reading <= boundaries["superlow"]) {
      return -2;
    } else {
      return -1;
    }
  } else {
    return 0;
  }
}

Map getGlucoseMessage(int glucoseStatus, int trendStatus) {
  return {
    "message":
        "${glucoseStatus.abs() >= 1 ? "Blood glucose is ${getIdOfGlucoseMessage(2, glucoseStatus)}" : ""}${glucoseStatus.abs() >= 1 && trendStatus.abs() >= 2 ? "\n" : ""}${trendStatus.abs() >= 2 ? "Blood glucose is ${getIdOfTrendMessage(2, trendStatus)}" : ""}"
  };
}

String getIdOfGlucoseMessage(int mode, int glucoseStatus) {
  return glucoseStatus == 0
      ? "normal"
      : glucoseStatus == 1
          ? "high"
          : glucoseStatus == 2
              ? mode == 2
                  ? "super high"
                  : "superhigh"
              : glucoseStatus == -1
                  ? "low"
                  : glucoseStatus == -2
                      ? mode == 2
                          ? "super low"
                          : "superlow"
                      : "normal";
}

String getIdOfTrendMessage(int mode, int trendStatus) {
  return trendStatus == 0
      ? "flat"
      : trendStatus == 1
          ? mode == 2
              ? "rising slowly"
              : "slowrise"
          : trendStatus == -1
              ? mode == 2
                  ? "falling slowly"
                  : "slowfall"
              : trendStatus == 2
                  ? mode == 2
                      ? "rising"
                      : "rise"
                  : trendStatus == -2
                      ? mode == 2
                          ? "falling"
                          : "fall"
                      : trendStatus == 3
                          ? mode == 2
                              ? "rising quickly"
                              : "quickrise"
                          : trendStatus == -3
                              ? mode == 2
                                  ? "falling quickly"
                                  : "fastfall"
                              : trendStatus == -4
                                  ? "unavailable"
                                  : "unavailable";
}
