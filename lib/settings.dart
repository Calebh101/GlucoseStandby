import 'dart:async';

import 'package:GlucoseStandby/dashboard.dart';
import 'package:GlucoseStandby/util.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:localpkg_flutter/localpkg.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';

enum DashboardAlignment {
  center,
  left,
  right,
}

class Settings {
  bool showTimer;
  bool defaultToWakelockOn;
  int? fakeSleep; // seconds
  DashboardAlignment alignment;
  Bounderies bounderies;

  Settings({required this.fakeSleep, required this.bounderies, required this.showTimer, required this.alignment, required this.defaultToWakelockOn});

  static Settings fromPrefs(SharedPreferences prefs) {
    return Settings(
      showTimer: prefs.getBool("showTimer") ?? true,
      defaultToWakelockOn: prefs.getBool("defaultToWakelockOn") ?? false,
      alignment: DashboardAlignment.values[prefs.getInt("alignment") ?? DashboardAlignment.center.index],
      bounderies: Bounderies(
        high: prefs.getInt("high") ?? 180,
        low: prefs.getInt("low") ?? 70,
        superHigh: prefs.getInt("superHigh") ?? 240,
        superLow: prefs.getInt("superLow") ?? 55,
      ),
      fakeSleep: (prefs.getInt("fakeSleep") ?? 0) <= 0 ? null : prefs.getInt("fakeSleep"),
    );
  }

  void save(SharedPreferences prefs) {
    Logger.print("Saving settings...");
    prefs.setBool("showTimer", showTimer);
    prefs.setBool("defaultToWakelockOn", defaultToWakelockOn);
    prefs.setInt("alignment", alignment.index);
    prefs.setInt("fakeSleep", fakeSleep ?? 0);
    bounderies.save(prefs);
  }
}

// Mg/dL
class Bounderies {
  int superLow;
  int superHigh;
  int low;
  int high;

  Bounderies({required this.high, required this.low, required this.superHigh, required this.superLow});

  void save(SharedPreferences prefs) {
    prefs.setInt("low", low);
    prefs.setInt("high", high);
    prefs.setInt("superLow", superLow);
    prefs.setInt("superHigh", superHigh);
  }
}

class SettingsWidget extends StatefulWidget {
  final Settings settings;
  const SettingsWidget({super.key, required this.settings});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        centerTitle: true,
        leading: IconButton(onPressed: () {
          context.navigator.pop();
        }, icon: Icon(Icons.arrow_back)),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text("Ranges"),
            tiles: [
              SettingsTile(
                title: Text("Low Glucose"),
                value: Text("${widget.settings.bounderies.low} mg/dL"),
                leading: Icon(Icons.arrow_downward),
                onPressed: (context) async {
                  int value = widget.settings.bounderies.low;

                  bool? result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: Text("Low Glucose"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("$value mg/dL"),
                            Slider(value: value.toDouble(), min: 55, max: 130, onChanged: (x) {
                              value = x.toInt();
                              setState(() {});
                            }),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("OK")),
                        ],
                      );
                    }
                  ));

                  if (result == true) {
                    widget.settings.bounderies.low = value;
                    widget.settings.save(await SharedPreferences.getInstance());
                    setState(() {});
                  }
                },
              ),
              SettingsTile(
                title: Text("High Glucose"),
                value: Text("${widget.settings.bounderies.high} mg/dL"),
                leading: Icon(Icons.arrow_upward),
                onPressed: (context) async {
                  int value = widget.settings.bounderies.high;

                  bool? result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: Text("High Glucose"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("$value mg/dL"),
                            Slider(value: value.toDouble(), min: 110, max: 300, onChanged: (x) {
                              value = x.toInt();
                              setState(() {});
                            }),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("OK")),
                        ],
                      );
                    }
                  ));

                  if (result == true) {
                    widget.settings.bounderies.high = value;
                    widget.settings.save(await SharedPreferences.getInstance());
                    setState(() {});
                  }
                },
              ),
              SettingsTile(
                title: Text("Super Low Glucose"),
                value: Text("${widget.settings.bounderies.superLow} mg/dL"),
                leading: Icon(Icons.arrow_downward),
                onPressed: (context) async {
                  int value = widget.settings.bounderies.superLow;

                  bool? result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: Text("Super Low Glucose"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("$value mg/dL"),
                            Slider(value: value.toDouble(), min: 40, max: 70, onChanged: (x) {
                              value = x.toInt();
                              setState(() {});
                            }),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("OK")),
                        ],
                      );
                    }
                  ));

                  if (result == true) {
                    widget.settings.bounderies.superLow = value;
                    widget.settings.save(await SharedPreferences.getInstance());
                    setState(() {});
                  }
                },
              ),
              SettingsTile(
                title: Text("Super High Glucose"),
                value: Text("${widget.settings.bounderies.superHigh} mg/dL"),
                leading: Icon(Icons.arrow_upward),
                onPressed: (context) async {
                  int value = widget.settings.bounderies.superHigh;

                  bool? result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: Text("Super High Glucose"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("$value mg/dL"),
                            Slider(value: value.toDouble(), min: 210, max: 400, onChanged: (x) {
                              value = x.toInt();
                              setState(() {});
                            }),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("OK")),
                        ],
                      );
                    }
                  ));

                  if (result == true) {
                    widget.settings.bounderies.superHigh = value;
                    widget.settings.save(await SharedPreferences.getInstance());
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          SettingsSection(
            title: Text("General"),
            tiles: [
              SettingsTile.switchTile(
                title: Text("Show Timer"),
                description: Text("Show how long has passed since the last received reading."),
                leading: Icon(Icons.timer),
                initialValue: widget.settings.showTimer,
                onToggle: (value) async {
                  widget.settings.showTimer = value;
                  widget.settings.save(await SharedPreferences.getInstance());
                  setState(() {});
                },
              ),
              SettingsTile.switchTile(
                title: Text("Default to Wakelock On"),
                description: Text("When the app is opened, wakelock is turned on automatically. If this is not enabled, wakelock defaults to what it was at last time you used the app."),
                leading: Icon(Icons.lightbulb),
                initialValue: widget.settings.defaultToWakelockOn,
                onToggle: (value) async {
                  widget.settings.defaultToWakelockOn = value;
                  widget.settings.save(await SharedPreferences.getInstance());
                  setState(() {});
                },
              ),
              SettingsTile(
                title: Text("Fake Sleep"),
                description: Text("How long to wait before fake sleeping, or making the screen completely black. This can be combined with the sleep timer."),
                value: Text(widget.settings.fakeSleep != null ? formatDuration(widget.settings.fakeSleep!) : "Off"),
                leading: Icon(Icons.bed_outlined),
                onPressed: (context) async {
                  int value = widget.settings.fakeSleep ?? 0;

                  bool? result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      Timer timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
                        if (!context.mounted) return timer.cancel();
                        setState(() {});
                      });

                      return AlertDialog(
                        title: Text("Fake Sleep"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: context.screenSize.width * 0.9),
                            if (value > 0)
                            Text("+${formatDuration(value)}")
                            else
                            Text("Off"),
                            Slider(value: value.clamp(60, maxFakeSleep * 60 * 60).toDouble(), min: 60, max: maxFakeSleep * 60 * 60, divisions: 1439, onChanged: (x) {
                              value = x.toInt();
                              setState(() {});
                            }, activeColor: sliderActiveColor, inactiveColor: sliderInactiveColor),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(onPressed: () {
                                  value = 0;
                                  setState(() {});
                                }, child: Text("Turn Off")),
                              ],
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () {
                            timer.cancel();
                            Navigator.of(context).pop(false);
                          }, child: Text("Cancel")),
                          TextButton(onPressed: () {
                            timer.cancel();
                            Navigator.of(context).pop(true);
                          }, child: Text("OK")),
                        ],
                      );
                    }
                  ));

                  if (result == true) {
                    if (value <= 0) {
                      widget.settings.fakeSleep = null;
                    } else {
                      widget.settings.fakeSleep = value;
                    }

                    Logger.print("Set fake sleep to ${widget.settings.fakeSleep}s");
                    widget.settings.save(await SharedPreferences.getInstance());
                    setState(() {});
                  }
                },
              ),
              SettingsTile(
                title: Text("Alignment"),
                description: Text("How to align the glucose widget on the home page."),
                value: Text("Align ${widget.settings.alignment.name}"),
                leading: Icon(switch (widget.settings.alignment) {
                  DashboardAlignment.center => Icons.align_horizontal_center,
                  DashboardAlignment.left => Icons.align_horizontal_left,
                  DashboardAlignment.right => Icons.align_horizontal_right,
                }),
                onPressed: (context) async {
                  await showDialog(context: context, builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 150,
                          child: Center(
                            child: ListView.builder(shrinkWrap: true, itemCount: DashboardAlignment.values.length, itemBuilder: (context, i) {
                              final item = DashboardAlignment.values[i];

                              return ListTile(
                                leading: Icon(widget.settings.alignment == item ? Icons.check : switch (item) {
                                  DashboardAlignment.center => Icons.align_horizontal_center,
                                  DashboardAlignment.left => Icons.align_horizontal_left,
                                  DashboardAlignment.right => Icons.align_horizontal_right,
                                }),
                                title: Text("Align ${item.name}"),
                                onTap: () {
                                  widget.settings.alignment = item;
                                  setState(() {});
                                },
                              );
                            }),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("OK")),
                        ],
                      );
                    }
                  ));

                  widget.settings.save(await SharedPreferences.getInstance());
                  setState(() {});
                },
              ),
            ],
          ),
          SettingsSection(
            title: Text("Account"),
            tiles: [
              SettingsTile(
                title: Text("Dexcom Account"),
                description: Text("Manage your Dexcom account credentials. These are never sent anywhere, other than Dexcom's servers."),
                leading: Icon(Icons.person),
                trailing: Icon(Environment.isIOS ? Icons.arrow_forward_ios : Icons.arrow_forward),
                onPressed: (context) async {
                  SimpleNavigator.navigate(context: context, page: LoginPage(prefs: await SharedPreferences.getInstance()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final SharedPreferences prefs;
  final bool showBack;

  const LoginPage({
    super.key,
    required this.prefs,
    this.showBack = true,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  static const bool alwaysShowBack = false;
  bool obscureText = true;
  bool loading = false;

  @override
  void initState() {
    usernameController.text = widget.prefs.getString("username") ?? "";
    super.initState();
  }

  Future<void> _saveCredentials() async {
    String username = usernameController.text.toString().trim();
    String password = passwordController.text.toString().trim();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var dexcom = Dexcom(username: username, password: password);
    SnackBarManager.show(context, "Verifying... This might take a while.");
    loading = true;
    setState(() {});

    try {
      Logger.print("Verifying...");
      if ((await dexcom.verify()).status == false) throw Exception("Invalid credentials");
      SnackBarManager.show(context, "Finding readings...");
      await dexcom.getGlucoseReadings();

      Logger.print("Verified login with dexcom: $dexcom");
      await prefs.setString('username', username);
      await prefs.setString('password', password);
      loading = false;
      setState(() {});
      Navigator.pop(context, true);
    } catch (e) {
      loading = false;
      setState(() {});
      SimpleDialogue.show(context: context, title: "Uh Oh!", content: Text("Unable to verify your account. Make sure your password is correct."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log In With Dexcom'),
        centerTitle: true,
        leading: widget.showBack || alwaysShowBack ? IconButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          icon: Icon(Icons.arrow_back),
        ) : null,
        actions: [
          if (loading)
          Container(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Dexcom Credentials of Sharer", style: TextStyle(fontSize: 20)),
              SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(onPressed: () {
                    obscureText = !obscureText;
                    setState(() {});
                  }, icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off))
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveCredentials,
                child: Text('Submit'),
              ),
              SizedBox(height: 16),
              Text("Why, exactly?",
                  style: TextStyle(
                    fontSize: 20,
                  )),
              SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final url = Uri.parse("https://github.com/Calebh101/GlucoseStandby/blob/main/README.md#can-i-trust-this-app");

                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Your credentials are needed for authenticating with Dexcom's servers. Your credentials are sent to their server ",
                        ),
                        TextSpan(
                          text: "only",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ". For more information, see ",
                        ),
                        TextSpan(
                          text: "my documentation",
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()..onTap = () async {
                            try {
                              ConfirmationDialogue.showUrlConfirmation(context, url);
                            } catch (e) {
                              Logger.warn("Unable to open URL: $e");
                              Clipboard.setData(ClipboardData(text: url.toString()));
                              SnackBarManager.show(context, "Copied URL to clipboard.");
                            }
                          },
                        ),
                        TextSpan(
                          text: ".",
                        )
                      ],
                    ),
                  );
                }
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
