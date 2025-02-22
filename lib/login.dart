import 'package:flutter/material.dart';
import 'package:localpkg/logger.dart';
import 'package:localpkg/dialogue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dexcom/dexcom.dart';

class LoginPage extends StatefulWidget {
  final bool showBack;

  const LoginPage({
    super.key,
    required this.showBack,
  });

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool alwaysShowBack = false;

  Future<void> _saveCredentials() async {
    String username = _usernameController.text.toString();
    String password = _passwordController.text.toString();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var dexcom = Dexcom(username, password);
    showSnackBar(context, "Loading...");

    try {
      if (username == "sandbox" && password == "password") {
        print("Account type: sandbox");
        showSnackBar(context,
            'You are using a sandbox data source. This uses random numbers to simulate glucose readings. Even though the readings may not be accurate, the functionality of the app is the same.');
        await Future.delayed(Duration(seconds: 3));
      } else {
        print("Account type: $dexcom");
        await dexcom.verifyLogin(username, password);
        await dexcom.getGlucoseReadings();
      }

      print("Verified login with dexcom: $dexcom");

      await prefs.setString('username', username);
      await prefs.setString('password', password);

      showSnackBar(context,
          'Credentials saved! Please reload the home page to use your credentials.');

      Navigator.pop(context, true);
    } catch (e) {
      showAlertDialogue(
          context,
          "Login error:",
          "An error occurred while logging in: $e (did you enter the correct username and password?)",
          false,
          {"show": true, "text": e});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In With Dexcom'),
        centerTitle: true,
        leading: widget.showBack || alwaysShowBack
            ? IconButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                icon: const Icon(Icons.arrow_back),
              )
            : const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Dexcom Credentials of Sharer",
                  style: TextStyle(
                    fontSize: 20,
                  )),
              const Text("Not Follower",
                  style: TextStyle(
                    fontSize: 14,
                  )),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveCredentials,
                child: const Text('Submit'),
              ),
              const SizedBox(height: 16),
              const Text("Why, exactly?",
                  style: TextStyle(
                    fontSize: 20,
                  )),
              const SizedBox(height: 16),
              const Text(
                "We use your Dexcom credentials to fetch data from Dexcom's servers, not ours. Your credentials are never sent to any other server that's not Dexcom's, including ours. Your credentials are stored locally using Flutter's SharedPreferences library.",
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
