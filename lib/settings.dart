import 'package:flutter/material.dart';
import 'package:personal/dialogue.dart';
import 'package:personal/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:GlucoseStandby/login.dart';
import 'package:GlucoseStandby/utils.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool showAlertsSettings = true;

  Future<void> clearSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
    prefs.clear();
    });
  }

  Future<void> editSettingsKey(String key, String desc, Map conditions) async {
    print("Starting editSettingsKey with type ${conditions["type"]}");
    TextEditingController textController = TextEditingController();

    if (conditions["type"] == "int" || conditions["type"] == "string") {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Enter Value'),
            content: TextField(
              controller: textController,
              decoration: InputDecoration(hintText:
                conditions["type"] == "string" ? "Text..." :
                conditions["type"] == "int" ? "Number..." : "Input..."
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Submit'),
                onPressed: () async {
                  var value;
                  if (conditions["type"] == "int") {
                    value = int.tryParse(textController.text) ?? textController.text;
                  } else {
                    value = textController.text;
                  }
                  if (value != "") {
                    Map output = verifyOutput(
                      conditions["type"] == "string" ? 1 :
                      conditions["type"] == "int" ? 2 : 0,
                      value, conditions
                    );
                    print(output);
                    var value2 = output["value"];
                    if(output["status"]) {
                      await setKey(key, value2);
                    } else {
                      await showAlertDialogue(context, "Your input is invalid:", output["error"], false, {"show": true});
                    }
                  }
                  Navigator.of(context).pop();
                  setState(() {});
                },
              ),
            ],
          );
        },
      );
    } else if (conditions["type"] == "bool") {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Value'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  conditions["confMode"] == 1 ? 'On' : "Yes"
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  conditions["confMode"] == 1 ? 'Off' : "No"
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ).then((result) async {
        if (result != null) {
          Map output = verifyOutput(4, result, conditions);
          var value2 = output["value"];
          if(output["status"]) {
            await setKey(key, value2);
          } else {
            await showAlertDialogue(context, "Your input is invalid:", output["condition"], false, {"show": true});
          }
          setState(() {});
        }
      });
    } else if (conditions["type"] == "slider") {
      double sliderValue = (conditions["preset"] ?? 0).toDouble();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Select Value"),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Selected Value: ${sliderValue.toInt()}%"),
                    Slider(
                      value: sliderValue,
                      min: conditions["min"].toDouble(),
                      max: conditions["max"].toDouble(),
                      divisions: conditions["divisions"],
                      label: sliderValue.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          sliderValue = value;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text("OK"),
                onPressed: () async {
                  var value = sliderValue.toInt();
                  Map output = verifyOutput(
                    3, value, conditions
                  );
                  var value2 = output["value"];
                  if(output["status"]) {
                    await setKey(key, value2);
                  } else {
                    await showAlertDialogue(context, "Your input is invalid:", output["condition"], false, {"show": true});
                  }
                  Navigator.of(context).pop();
                  setState(() {});
                },
              ),
            ],
          );
        },
      );
    } else if (conditions["type"] == "list") {
      //String selected = conditions["value"];
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Select an Option"),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conditions["items"].length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(conditions["items"][index]),
                    /*leading: conditions["items"][index] == selected ? Icon(
                      Icons.check,
                    ) : SizedBox.shrink(),*/
                    onTap: () async {
                      var value = conditions["items"][index];
                      Map output = verifyOutput(
                        5, value, conditions
                      );

                      print(output);
                      var value2 = output["value"];

                      if (output["status"]) {
                        await setKey(key, value2);
                        //selected = value2;
                      } else {
                        await showAlertDialogue(context, "Your input is invalid:", output["condition"], false, {"show": true});
                      }

                      if (conditions["mode"] == "sound") {
                        playSound(context, conditions["items"][index], conditions["volume"]);
                      }

                      if (conditions["immediatelyCloseOnSelect"]) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              !conditions["immediatelyCloseOnSelect"] ? TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {});
                },
                child: Text("Submit"),
              ) : SizedBox.shrink(),
            ],
          );
        },
      );
    } else {
      showAlertDialogue(context, "Error:", "Unrecognized setting type: ${conditions["type"]}", false, {"show": true});
    }
  }


  Future<void> setKey(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      throw ArgumentError("Unsupported value type: ${value.runtimeType}");
    }
  }

  @override
  Widget build(BuildContext context) {
    String unit = "mg/dL";
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {Navigator.pop(context);},
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: FutureBuilder(
          future: getAllSettings(),
          builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              var data = snapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingTitle(title: "Glucose Range"),
                    Column(
                      children: [
                        Setting(
                          title: "Low bloodsugar",
                          desc: "At what point your bloodsugar is considered low.",
                          text: "${data["low"]} $unit",
                          action: () {editSettingsKey("low", "low glucose", {
                            "type": "int",
                            "high": 120,
                            "low": 60,
                          });},
                        ),
                        Setting(
                          title: "High bloodsugar",
                          desc: "At what point your bloodsugar is considered high.",
                          text: "${data["high"]} $unit",
                          action: () {editSettingsKey("high", "high glucose", {
                            "type": "int",
                            "high": 300,
                            "low": 120,
                          });},
                        ),
                        Setting(
                          title: "Super low bloodsugar",
                          desc: "At what point your bloodsugar is considered super low.",
                          text: "${data["superlow"]} $unit",
                          action: () {editSettingsKey("superlow", "super low glucose", {
                            "type": "int",
                            "high": 60,
                            "low": 40,
                          });},
                        ),
                        Setting(
                          title: "Super high bloodsugar",
                          desc: "At what point your bloodsugar is considered super high.",
                          text: "${data["superhigh"]} $unit",
                          action: () {editSettingsKey("superhigh", "super high glucose", {
                            "type": "int",
                            "high": 400,
                            "low": 300,
                          });},
                        ),
                        Setting(
                          title: "Bloodsugar range",
                          desc: "What is considered in range.",
                          text: "${data["low"]} $unit - ${data["high"]} $unit",
                          action: () {},
                        ),
                        Setting(
                          title: "Bloodsugar super range",
                          desc: "What is considered out of range, but still not too out of range.",
                          text: "${data["superlow"]} $unit - ${data["superhigh"]} $unit",
                          action: () {},
                        ),
                      ],
                    ),
                    showAlertsSettings ? const SizedBox(height: 10) : SizedBox.shrink(),
                    showAlertsSettings ? SettingTitle(title: "Alerts") : SizedBox.shrink(),
                    showAlertsSettings ? Column(
                      children: [
                        Setting(
                          title: "Allow alerts",
                          desc: "If you want to receive alerts for your glucose levels.",
                          text: data["allowalerts"] ? "On" : "Off",
                          action: () {editSettingsKey("allowalerts", "allow alerts", {
                            "type": "bool",
                            "confMode": 1,
                          });},
                        ),
                        Setting(
                          title: "Only super alerts",
                          desc: "Only sound/vibrate if your glucose is out of super range, instead of out of normal range.",
                          text: data["superalerts"] ? "On" : "Off",
                          action: () {editSettingsKey("superalerts", "only super alerts", {
                            "type": "bool",
                            "confMode": 1,
                          });},
                        ),
                        Setting(
                          title: "Alert sound",
                          desc: "The sound alerts make when they go off.",
                          text: data["alertsound"],
                          action: () {editSettingsKey("alertsound", "alert sound", {
                            "value": data["alertsound"],
                            "type": "list",
                            "mode": "sound",
                            "immediatelyCloseOnSelect": false,
                            "items": alertSounds,
                            "volume": data["alertvolume"] ?? 50,
                          });}
                        ),
                        Setting(
                          desc: "How loud the alerts should be.",
                          title: "Alert volume",
                          text: "${data["alertvolume"] ?? 0}% volume",
                          action: () {editSettingsKey("alertvolume", "alert volume", {
                            "type": "slider",
                            "preset": data["alertvolume"],
                            "min": 1,
                            "max": 100,
                            "divisions": 99,
                            "volume": data["alertVolume"],
                          });},
                        ),
                      ],
                    ) : SizedBox.shrink(),
                    const SizedBox(height: 10),
                    SettingTitle(title: "Auto Dim"),
                    Column(
                      children: [
                        Setting(
                          desc: "Enable app auto dim.",
                          title: "Auto dim",
                          text: data["autodimon"] ? "On" : "Off",
                          action: () {editSettingsKey("autodimon", "auto dim on", {
                            "type": "bool",
                            "confMode": 1,
                          });},
                        ),
                        Setting(
                          desc: "When the app auto-dims, the brightness will be set to ${data["autodimvalue"]}%.",
                          title: "Auto dim to",
                          text: "${data["autodimvalue"] ?? 0}% brightness",
                          action: () {editSettingsKey("autodimvalue", "auto dim value", {
                            "type": "slider",
                            "preset": data["autodimvalue"],
                            "min": 1,
                            "max": 100,
                            "divisions": 99,
                          });},
                        ),
                        Setting(
                          desc: "How long it takes to auto dim the screen.",
                          title: "Auto dim after",
                          text: "${data["autodimtime"]} seconds",
                          action: () {editSettingsKey("autodimtime", "auto dim time", {
                            "type": "int",
                            "high": 600,
                            "low": 2,
                          });},
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SettingTitle(title: "Power"),
                    Column(
                      children: [
                        Setting(
                          desc: "Decides whether the device should stay awake at all times while on the app. This does not affect Auto Dim.",
                          title: "Stay awake",
                          text: data["stayawake"] ? "On" : "Off",
                          action: () {editSettingsKey("stayawake", "stay awake", {
                            "type": "bool",
                            "confmode": 1,
                          });},
                        ),
                        Setting(
                          desc: "Decides whether the device should go to sleep after a set period of time.",
                          title: "Sleep timer enabled",
                          text: data["sleeptimer"] ? "On" : "Off",
                          action: () {editSettingsKey("sleeptimer", "sleep timer enabled", {
                            "type": "bool",
                            "confmode": 1,
                          });},
                        ),
                        Setting(
                          title: "Sleep timer",
                          desc: "How long to stay awake before sleeping the device.",
                          text: "${data["sleeptimertime"]} minutes",
                          action: () {editSettingsKey("sleeptimertime", "sleep timer time", {
                            "type": "int",
                            "high": 180,
                            "low": 15,
                          });},
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SettingTitle(title: "Account"),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        SettingButton(
                          title: "Log In With Dexcom",
                          action: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage(showBack: true)),
                            );
                          },
                          context: context,
                        ),
                      ]
                    ),
                    const SizedBox(height: 10),
                    SettingTitle(title: "About"),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        const SizedBox(height: 10),
                        Setting(
                          title: "About",
                          desc: "GlucoseStandby is meant to be an app you can glance at to see your bloodsugar. You can just open the app, turn on Stay Awake, and place your phone or tablet somewhere where you can glance at it. Works best on OLED displays.",
                          text: "",
                          action: () {},
                        ),
                        Setting(
                          desc: "Author information.",
                          title: "Author",
                          text: "Author: Calebh101",
                          action: () {},
                        ),
                        Setting(
                          desc: "Info about the version and channel.",
                          title: "Version Info",
                          text: "Channel: beta\nVersion: 0.0.0A",
                          action: () {},
                        ),
                        const SizedBox(height: 10),
                        SettingButton(
                          title: "Reset to Default",
                          action: () {
                          clearSettings();
                          },
                          context: context,
                        ),
                        const SizedBox(height: 10),
                        SettingButton(
                          title: "Send Feedback",
                          action: () {
                            openUrlConf(context, Uri.parse("mailto:calebh101dev@icloud.com"));
                          },
                          context: context,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else {
              return const Text('No data available');
            }
          },
        ),
      )
    );
  }
}