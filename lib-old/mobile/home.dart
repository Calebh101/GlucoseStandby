import 'dart:math';
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/logger.dart';

import 'package:window_manager/window_manager.dart';
import 'package:universal_html/html.dart' as html;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:dexcom/dexcom.dart';

import '../utils.dart';
import 'settings.dart';
import 'var.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Random random = Random();
  int readingTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  Map prevData = {};
  bool sleepTimerActive = false;
  bool fullscreen = false;
  bool allowDim = false;
  bool showSampleWarning = false;
  bool showValueTimer = true;
  int dimTime = 60;
  int dimValue = 0;
  int autodimcounter = 0;
  bool sleeptimer = false;
  int sleeptimertime = 60;
  Timer? _timer;
  Map alerts = {"time": 0};
  String globalLog = "";
  int? previousReading;
  int? previousTrend;
  late AudioPlayer globalPlayer;
  final int _currentValue = 0;
  final int _durationInSeconds = 1;

  // intialize streams and updaters
  late Stream<int> timeSinceLastReading;
  late Stream<int>? autodimstream;
  final StreamController<String> _controller = StreamController<String>();
  final StreamController<int> _autodimcontroller = StreamController<int>();
  StreamSubscription? _subscription;
  final ValueNotifier<bool> isVisible = ValueNotifier<bool>(true);
  final ValueNotifier<String> logNotif = ValueNotifier("waiting on logs...");

  // settings
  bool showGlucoseWarning = true;
  bool quickUndim = false;
  int dimDuration = 25;
  int maxSeconds = 7200;
  int buffer = 10;

  // debug options
  bool showOnScreenLog = false; // shows logs on the screen
  bool showTimeLogs =
      false; // shows logs related to autodimstream and timeSinceLastReading; not recommended, as it generates about 101 logs per second on average
  bool showAutoDimTimer =
      false; // shows a timer on the screen for autodim; currently not working
  bool forceLogin = false; // I'ma be honest I forgot what this does
  bool forceSampleData = false; // forces sample data to be used

  int translateStyle(String input) {
    int result = 0;
    input = input.toLowerCase();

    switch (input) {
      case "default":
        result = 1;
        break;
      case "digital":
        result = 2;
        break;
      default:
        result = 0;
        break;
    }

    log("translated style $input to code $result");
    return result;
  }

  void log(message) {
    String log = "${DateTime.now().millisecondsSinceEpoch}: $message";

    globalLog += "${globalLog == "" ? "" : "\n"}$log";
    logNotif.value = globalLog;
    print(log);
  }

  void _subscribeToStream() {
    if (_subscription == null || _subscription!.isPaused) {
      _subscription = timeSinceLastReading.listen((data) {});
    }
  }

  bool wakelock(bool status, bool logS) {
    try {
      if (status) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      if (logS) {
        log("wakelock: success: $status");
      }

      return true;
    } catch (e) {
      if (logS) {
        log("wakelock: fail: $e");
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchData() async {
    int mode = 1;
    if (mode == 1 && !forceSampleData) {
      var response = await fetchApiData();
      if (response != null) {
        return response;
      } else {
        return {"error": "no response"};
      }
    } else if (mode == 2 || forceSampleData) {
      return await fetchSampleData(false);
    } else {
      return {"error": "invalid_mode"};
    }
  }

  Future<Map<String, dynamic>?> fetchApiData() async {
    Map settings = await getAllSettings();
    var dexcom = Dexcom(username: settings["username"], password: settings["password"]);
    List<dynamic>? response;

    if (settings["username"] == "sandbox" &&
        settings["password"] == "password") {
      showSampleWarning = false;
      return await fetchSampleData(true, possibleError: true);
    }

    if (settings["username"] == "" ||
        settings["password"] == "" ||
        forceLogin) {
      showSampleWarning = true;
      return await fetchSampleData(false);
    } else {
      showSampleWarning = false;
    }

    try {
      response = await dexcom.getGlucoseReadings(
          maxCount: 2, minutes: maxSeconds ~/ 60);
      log("Read data with dexcom: $dexcom");
    } catch (e) {
      showAlertDialogue(
          context,
          "Login error:",
          "An error occurred while logging in: $e: Did you enter the correct username and password? If not, go to Settings > Log In With Dexcom.",
          false,
          {"show": true, "text": e});
    }

    if (response != null) {
      String wtString = response[0]['ST'];
      RegExp regExp = RegExp(r'Date\((\d+)\)');
      Match? match = regExp.firstMatch(wtString);

      if (match != null) {
        int milliseconds = int.parse(match.group(1)!);
        int seconds = milliseconds ~/ 1000;
        log('Time in seconds: $seconds');
        readingTime = seconds;
      } else {
        log('Invalid date format');
      }

      Map<String, dynamic> data = getAppData(response[0]["Value"],
          response[1]["Value"], getTrend(response[0]["Trend"]), settings);
      prevData = data;
      return data;
    } else {
      return {"error": "response is null"};
    }
  }

  check(int value) {
    log("Alert: $value");
  }

  int getTrend(String trend) {
    int newTrend = -4;

    switch (trend) {
      case "Flat":
        newTrend = 0;
        break;
      case "FortyFiveDown":
        newTrend = -1;
        break;
      case "FortyFiveUp":
        newTrend = 1;
        break;
      case "SingleDown":
        newTrend = -2;
        break;
      case "SingleUp":
        newTrend = 2;
        break;
      case "DoubleDown":
        newTrend = -3;
        break;
      case "DoubleUp":
        newTrend = 3;
        break;
      case "None":
        newTrend = -4;
        break;
      case "NonComputable":
        newTrend = -4;
        break;
      case "RateOutOfRange":
        newTrend = -4;
        break;
      default:
        newTrend = -4;
        break;
    }

    return newTrend;
  }

  Future<Map<String, dynamic>> fetchSampleData(bool delay,
      {bool possibleError = false}) async {
    if (delay) {
      final random = Random();
      await Future.delayed(Duration(seconds: random.nextInt(2) + 1));
    }

    Map settings = await getAllSettings();
    int reading = (previousReading ?? random.nextInt(261) + 40) +
        (random.nextInt(41) - 20);
    int prevreading = previousReading ?? (reading + (random.nextInt(41) - 20));
    int trend = getTrendByChange(reading, prevreading, possibleError);
    Map<String, dynamic> data =
        getAppData(reading, prevreading, trend, settings);

    readingTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
        (random.nextInt(6) + 4);
    prevData = data;
    previousReading = reading;
    previousTrend = trend;
    showValueTimer = settings["showtimer"];
    return data;
  }

  Map<String, dynamic> getAppData(
      int reading, int prevreading, int trend, Map settings) {
    log("generating AppData");
    return {
      "bg": reading,
      "trend": trend,
      "previousreading": prevreading,
      "style": translateStyle(settings["style"]),
      "showtimer": settings["showtimer"],
      "boundaries": {
        "superlow": settings["superlow"],
        "low": settings["low"],
        "high": settings["high"],
        "superhigh": settings["superhigh"],
      },
      "autodim": {
        "autodimon": settings["autodimon"],
        "autodimvalue": settings["autodimvalue"],
        "autodimtime": settings["autodimtime"],
        "stayawake": settings["stayawake"],
      },
      "alerts": {
        "allowalerts": settings["allowalerts"],
        "superalerts": settings["superalerts"],
        "alertsound": settings["alertsound"],
        "alertvolume": settings["alertvolume"],
      },
      "sleeptimer": {
        "sleeptimer": settings["sleeptimer"],
        "sleeptimertime": settings["sleeptimertime"],
      },
    };
  }

  int getTrendByChange(int reading, int prevreading, bool possibleError) {
    int chance = 25;
    int change = reading - prevreading;
    int num = random.nextInt(chance);

    log("getTrendByChange called for readings $reading,$prevreading");
    log("change: $change");
    log("chance: $num (1/$chance)");

    if (num == 0 && possibleError) {
      return -4; // no trend simulation
    }

    if (change >= 5) {
      if (change >= 10) {
        if (change >= 15) {
          if (change >= 50) {
            return -4; // RateOutOfRange simulation
          } else {
            return 3; // rising fast
          }
        } else {
          return 2; // rising
        }
      } else {
        return 1; // rising slow
      }
    } else if (change <= -5) {
      if (change <= -10) {
        if (change <= -15) {
          if (change <= -50) {
            return -4; // RateOutOfRange simulation
          } else {
            return -3; // falling fast
          }
        } else {
          return -2; // falling
        }
      } else {
        return -1; // falling slow
      }
    } else {
      return 0; // steady
    }
  }

  int getTimeDifference(int recordedTimeInSeconds) {
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
        recordedTimeInSeconds;
  }

  String formatDuration(int seconds, bool includeHours) {
    if (seconds < 0) {
      seconds = 0;
    }

    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = duration.inHours > 0 ? duration.inHours.toString() : '';
    String minutes;

    if (seconds < 600) {
      minutes = duration.inMinutes.remainder(60).toString();
    } else {
      minutes = twoDigits(duration.inMinutes.remainder(60));
    }

    String secs = twoDigits(duration.inSeconds.remainder(60));

    if (hours.isNotEmpty || includeHours) {
      return "$hours:$minutes:$secs";
    } else {
      return "$minutes:$secs";
    }
  }

  bool isMultiple(int number, int multipleOf) {
    return number % multipleOf == 0;
  }

  void setFullscreen(bool fullscreenS) async {
    if (kIsWeb) {
      if (fullscreenS) {
        html.document.documentElement?.requestFullscreen();
      } else {
        html.document.exitFullscreen();
      }
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        if (fullscreenS) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
              overlays: []);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
              overlays: SystemUiOverlay.values);
        }
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        await windowManager.setFullScreen(fullscreenS);
      }
    }

    fullscreen = fullscreenS;
    refresh();
  }

  double convertReading(double reading, int mode) {
    if (mode == 1) {
      // mg/dL to mmol/L
      return reading / 180.16;
    } else if (mode == 2) {
      // mmol/L to mg/dL
      return reading * 180.16;
    } else {
      // other
      return reading;
    }
  }

  void refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  double invertNumber(double x, double axis) {
    return axis + (axis - x);
  }

  void _startTimer() {
    _stopTimer(); // Ensure no duplicate timers
    _timer = Timer.periodic(Duration(seconds: _durationInSeconds), (timer) {
      autodimcounter++;
      _autodimcontroller.add(_currentValue);
    });
  }

  void resetStayAwake() {
    sleepTimerActive = false;
  }

  void touchScreen() {
    log("screen contact");
    resetAutoDimTimer();
    resetStayAwake();
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void setAutoDimTimer(int amount) {
    log("Setting autodimcounter to $amount");
    autodimcounter = amount;
    _autodimcontroller.add(amount);
  }

  void resetAutoDimTimer() {
    setAutoDimTimer(0);
  }

  void activateAutoDim() {
    setAutoDimTimer(dimTime);
  }

  @override
  void initState() {
    timeSinceLastReading = Stream.periodic(
      const Duration(seconds: 1),
      (time) => getTimeDifference(readingTime),
    ).asBroadcastStream();

    autodimstream = Stream.periodic(
      const Duration(milliseconds: 1),
      (time) => autodimcounter,
    ).asBroadcastStream();
    init();
    super.initState();
  }

  void init() async {
    await getAllSettings();
    wakelock(false, true);
    _subscribeToStream();
    _startTimer();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    _autodimcontroller.close();
    wakelock(false, true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        touchScreen();
      },
      child: Scaffold(
        body: Stack(children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: fetchData(),
                  builder: (context, snapshot) {
                    double size;
                    double maxSize = 3;
                    bool forceUseWidth = true;
                    Size screenSize = MediaQuery.of(context).size;

                    // ignore: dead_code
                    if ((screenSize.width > screenSize.height) &&
                        !forceUseWidth) {
                      size = screenSize.height;
                    } else {
                      size = screenSize.width;
                    }

                    size = size * 0.003;
                    size = size > maxSize ? maxSize : size;
                    log("size: $size");
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      log("Error with data: ${snapshot.error}: ${snapshot.data}");
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "No Data",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12 * size,
                            ),
                          ),
                        ],
                      );
                    } else {
                      Map data;
                      if (snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data != "") {
                        data = snapshot.data!;
                      } else {
                        data = {"error": "no data available"};
                      }
                      if (data["error"] != null) {
                        log("Error with data: $data");
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Data Error",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12 * size,
                              ),
                            ),
                          ],
                        );
                      } else {
                        int reading = data["bg"];
                        int previousreading = data["previousreading"];
                        int change = reading - previousreading;
                        int trend = data["trend"] ??= -4;
                        Map boundaries = data["boundaries"];
                        int style = data["style"];
                        String formattedNumber =
                            (change >= 0) ? '+$change' : change.toString();

                        if (data["autodim"]["stayawake"] && !sleepTimerActive) {
                          wakelock(true, true);
                        } else {
                          wakelock(false, true);
                        }

                        allowDim = data["autodim"]["autodimon"];
                        dimTime = data["autodim"]["autodimtime"];
                        dimValue = data["autodim"]["autodimvalue"];

                        sleeptimer = data["sleeptimer"]["sleeptimer"];
                        sleeptimertime = data["sleeptimer"]["sleeptimertime"];

                        int glucoseStatus =
                            getStatusOfGlucose(reading, boundaries);
                        int trendStatus = trend;
                        int alertBuffer = 1800; // seconds

                        log('style: $style');
                        log("alerts: $alerts");

                        bool showGlucoseAlert = (data["alerts"]["superalerts"]
                                ? (glucoseStatus.abs() >= 2 ||
                                    trendStatus.abs() >= 3)
                                : (glucoseStatus.abs() >= 1 ||
                                    trendStatus.abs() >= 2)) &&
                            data["alerts"]["allowalerts"] &&
                            (isSecondsAway(alerts["time"], alertBuffer) ||
                                alerts["time"] == 0) &&
                            showGlucoseWarning;

                        if (showGlucoseAlert) {
                          log("Showing glucose alert: ${isSecondsAway(alerts["time"], alertBuffer)}");
                          playAlert(data["alerts"]["alertsound"],
                              data["alerts"]["alertvolume"]);
                        } else {
                          log("Hiding glucose alert: ${isSecondsAway(alerts["time"], alertBuffer)}");
                        }

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(children: [
                              if (showSampleWarning)
                                Container(
                                  height: 100,
                                  width: double.infinity,
                                  child: Stack(children: [
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.red,
                                        width: double.infinity,
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          "Warning: You are currently using sample data. Please log in with Dexcom to view your glucose data.",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                              if (showGlucoseAlert)
                                ValueListenableBuilder<bool>(
                                    valueListenable: isVisible,
                                    builder: (context, alertVisible, child) {
                                      return Visibility(
                                        visible: alertVisible,
                                        child: Container(
                                          height: 100,
                                          width: double.infinity,
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  color: glucoseStatus.abs() >=
                                                              2 ||
                                                          trendStatus.abs() >= 2
                                                      ? Colors.red
                                                      : Colors.orange,
                                                  width: double.infinity,
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      SizedBox.shrink(),
                                                      Text(
                                                        getGlucoseMessage(
                                                                glucoseStatus,
                                                                trendStatus)[
                                                            "message"],
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      TextButton(
                                                          onPressed: () {
                                                            isVisible.value =
                                                                !isVisible
                                                                    .value;
                                                            dismissAlerts();
                                                          },
                                                          child: Text(
                                                            "Dismiss",
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ))
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                            ]),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  reading.toString(),
                                  style: TextStyle(
                                    fontSize: 50 * size,
                                    fontFamily:
                                        style == 2 ? "DSEG" : defaultFont,
                                    color: decideColorForReading(
                                        reading, boundaries),
                                  ),
                                ),
                                Visibility(
                                  visible: trend != -4,
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Transform.rotate(
                                            angle: decideRotation(1, trend),
                                            child: style == 2
                                                ? Text(
                                                    "→",
                                                    style: TextStyle(
                                                      fontSize: 50.0 * size,
                                                      fontFamily: "DSEG",
                                                      color:
                                                          decideColorForArrow(
                                                              1, trend),
                                                    ),
                                                  )
                                                : Icon(Icons.arrow_forward,
                                                    size: 50.0 * size,
                                                    color: decideColorForArrow(
                                                        1, trend)),
                                          ),
                                          if (trend == 3 || trend == -3)
                                            Row(
                                              children: [
                                                SizedBox(width: 30 * size),
                                                Icon(
                                                  trend == 3
                                                      ? Icons.arrow_upward
                                                      : Icons.arrow_downward,
                                                  size: 50.0 * size,
                                                  color: decideColorForArrow(
                                                      1, trend),
                                                ),
                                              ],
                                            ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                SizedBox(width: trend == -4 ? 10 : 0),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(formattedNumber,
                                            style: TextStyle(
                                              color: change.abs() >= 15
                                                  ? Colors.red
                                                  : change.abs() >= 10
                                                      ? Colors.orange
                                                      : change.abs() >= 5
                                                          ? Colors.yellow
                                                          : Colors.green,
                                              fontSize: 12 * size,
                                              fontFamily: style == 2
                                                  ? "DSEG"
                                                  : defaultFont,
                                            )),
                                        Text(
                                          " from ",
                                          style: TextStyle(
                                            fontSize: 12 * size,
                                            fontFamily: style == 2
                                                ? "Audiowide"
                                                : defaultFont,
                                          ),
                                        ),
                                        Text(previousreading.toString(),
                                            style: TextStyle(
                                              color: decideColorForReading(
                                                  previousreading, boundaries),
                                              fontSize: 12 * size,
                                              fontFamily: style == 2
                                                  ? "DSEG"
                                                  : defaultFont,
                                            )),
                                      ],
                                    ),
                                    StreamBuilder<int>(
                                      stream: timeSinceLastReading,
                                      builder: (BuildContext context,
                                          AsyncSnapshot<int> snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const CircularProgressIndicator();
                                        } else if (snapshot.hasError) {
                                          return Text(
                                              'Error: ${snapshot.error}');
                                        } else if (snapshot.hasData &&
                                            snapshot.data != null) {
                                          int data = snapshot.data!;
                                          if (showTimeLogs) {
                                            log("reading (data): $data");
                                          }
                                          if (isMultiple(data - buffer, 300) &&
                                              data >= 60) {
                                            refresh();
                                            return const CircularProgressIndicator();
                                          } else if (data >= maxSeconds) {
                                            return Text(
                                              "No Data",
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12 * size,
                                              ),
                                            );
                                          } else {
                                            return Text(
                                              showValueTimer
                                                  ? '-${formatDuration(data, false)}'
                                                  : 'Previous Reading',
                                              style: TextStyle(
                                                color: data >= 300
                                                    ? Colors.orange
                                                    : Colors.green,
                                                fontSize: 12 * size,
                                                fontFamily: style == 2
                                                    ? "DSEG"
                                                    : defaultFont,
                                              ),
                                            );
                                          }
                                        } else {
                                          return const Text(
                                              'No data available');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    }
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        touchScreen();
                        refresh();
                      },
                      icon: const Icon(Icons.refresh, size: 30),
                    ),
                    IconButton(
                      onPressed: () {
                        touchScreen();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Settings()),
                        );
                      },
                      icon: const Icon(
                        Icons.settings,
                        size: 30,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        touchScreen();
                        setFullscreen(!fullscreen);
                      },
                      icon: Icon(
                          fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: autodimstream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return showAutoDimTimer
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (snapshot.hasData && snapshot.data != null) {
                int data = snapshot.data!;
                double dimValueS =
                    (invertNumber(dimValue.toDouble(), 50) / 100);
                if (showTimeLogs) {
                  log("autodim (data): $data");
                }

                if (sleeptimer) {
                  if (data * 60 >= sleeptimertime) {
                    sleepTimerActive = true;
                    wakelock(false, false);
                  }
                }

                if (allowDim && data > dimTime) {
                  return Stack(
                    children: [
                      IgnorePointer(
                        ignoring: true,
                        child: AnimatedOpacity(
                          opacity: data > dimTime ? dimValueS : 0,
                          duration: data == 0
                              ? (!quickUndim
                                  ? Duration(milliseconds: dimDuration ~/ 2)
                                  : const Duration(seconds: 0))
                              : Duration(milliseconds: dimDuration),
                          child: Container(
                            color: Colors.black,
                          ),
                        ),
                      ),
                      autodimvaluewidget(data: data, enabled: true),
                    ],
                  );
                } else {
                  return autodimvaluewidget(data: data, enabled: false);
                }
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ]),
      ),
    );
  }

  Widget autodimvaluewidget({
    int data = 0,
    bool enabled = false,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            showAutoDimTimer
                ? Column(children: [
                    Text("autodim controlled by autodimstream"),
                    Text(data.toString()),
                    Text(
                        "status: ${enabled ? "active" : "inactive"}, ${allowDim ? "enabled" : "disabled"}")
                  ])
                : SizedBox.shrink(),
            if (showOnScreenLog)
              ValueListenableBuilder<String>(
                valueListenable: logNotif,
                builder: (context, value, child) {
                  return Text(value);
                },
              ),
          ],
        ),
      ),
    );
  }

  void dismissAlerts() async {
    alerts = {"time": DateTime.now().millisecondsSinceEpoch};
    //player.stop();
    log("dismissed alerts with time: ${alerts["time"]}");
  }

  bool isSecondsAway(int millisecondsSinceEpoch, int seconds) {
    final targetTime =
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    final now = DateTime.now();
    final inSeconds = targetTime.difference(now).inSeconds.abs();
    final status = inSeconds >= seconds;
    log("$inSeconds >= $seconds: $status");
    return status;
  }

  Future<AudioPlayer> playAlert(String id, int volume) async {
    AudioPlayer player = await playSound(context, id, volume);
    return player;
  }
}

class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    // Draw a simple arrow
    Path arrowPath = Path()
      ..moveTo(20, 20) // Starting point
      ..lineTo(80, 20) // Top horizontal line
      ..lineTo(60, 10) // Right diagonal line
      ..moveTo(80, 20) // Top point
      ..lineTo(60, 30) // Left diagonal line
      ..lineTo(20, 30) // Bottom line
      ..close();

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
