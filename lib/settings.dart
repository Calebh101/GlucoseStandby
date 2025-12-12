import 'package:dexcom/dexcom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localpkg_flutter/localpkg.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';

class Settings {
  bool showTimer;
  Bounderies bounderies;
  Autodim? autodim;

  Settings({required this.autodim, required this.bounderies, required this.showTimer});

  static Settings fromPrefs(SharedPreferences prefs) {
    return Settings(
      showTimer: prefs.getBool("showTimer") ?? true,
      bounderies: Bounderies(
        high: prefs.getInt("high") ?? 180,
        low: prefs.getInt("low") ?? 70,
        superHigh: prefs.getInt("superHigh") ?? 240,
        superLow: prefs.getInt("superLow") ?? 55,
      ),
      autodim: (prefs.getBool("autodim") ?? false) ? Autodim(
        endValue: prefs.getDouble("autodimValue") ?? 0.75,
        delay: prefs.getDouble("autodimDelay") ?? 300,
      ) : null,
    );
  }

  void save(SharedPreferences prefs) {
    Logger.print("Saving settings...");
    prefs.setBool("showTimer", showTimer);
    bounderies.save(prefs);
    autodim.save(prefs);
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

class Autodim {
  double endValue; // 0 being darkest, 1 being brightest
  double delay; // seconds

  Autodim({required this.endValue, required this.delay});
}

extension on Autodim? {
  void save(SharedPreferences prefs) {
    if (this != null) {
      prefs.setBool("autodim", true);
      prefs.setDouble("autodimValue", this!.endValue);
      prefs.setDouble("autodimDelay", this!.delay);
    } else {
      prefs.setBool("autodim", false);
    }
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
                initialValue: widget.settings.showTimer,
                onToggle: (value) async {
                  widget.settings.showTimer = value;
                  widget.settings.save(await SharedPreferences.getInstance());
                  setState(() {});
                },
              ),
              SettingsTile.navigation(
                title: Text("Dexcom Account"),
                description: Text("Manage your Dexcom account credentials."),
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
