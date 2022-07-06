// ignore_for_file: non_constant_identifier_names

import "dart:io";
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import "package:fl_chart/fl_chart.dart";
import "sensor_data_widgets.dart";
import "utility_functions.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SafeArea(child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State createState() {
    return _HomeScreen();
  }
}

class _HomeScreen extends State {
  final HUMIDITY_THRESHOLD = 70;
  final SOIL_MOISTURE_THRESHOLD = 30;
  double temperature = 0.0;
  int humidity = 0;
  int soilMoisture = 0;
  bool isWatering = false;
  bool disableWateringButton = false;
  bool ignoreDisableUpdate = false;
  bool scilentHumidityAlert = false;
  List soilMoistureGraphData = [];

  late FirebaseDatabase database;
  late DatabaseReference ref;
  late DatabaseReference ledStatusRef;
  DatabaseReference isWateringRef =
      FirebaseDatabase.instance.ref('isWatering/');

  @override
  void initState() {
    ref = FirebaseDatabase.instance.ref("");
    database = FirebaseDatabase.instance;
    isWatering = false;
    for (int i = 0; i < 21; i++) {
      soilMoistureGraphData.add(0);
    }
    super.initState();

    ref.onValue.listen((DatabaseEvent event) {
      print("Firebase Listener");
      var data = event.snapshot.value as Map;
      print(data);

      final latestIsWatering = data["isWatering"];
      final latestHumidity = data["currentHumidity"];
      final latestSoilMoisture = data["currentSoilMoisture"];
      final latestTemperature = data["currentTemperature"];

      if (ignoreDisableUpdate == false) {
        if (latestIsWatering == true) {
          setState(() {
            isWatering = true;
            disableWateringButton = true;
          });
        } else {
          isWatering = false;
          disableWateringButton = false;
        }
      }

      if (humidity >= HUMIDITY_THRESHOLD) showHumidityAlert();

      setState(() {
        temperature = latestTemperature;
        humidity = latestHumidity;
        soilMoisture = latestSoilMoisture;

        soilMoistureGraphData.insert(0, soilMoisture);
        soilMoistureGraphData.removeLast();
      });
    });
  }

  void toggleIsWatering() {
    print("TOGGLING ISWATER");
    setState(() {
      ignoreDisableUpdate = !ignoreDisableUpdate;
      isWatering = !isWatering;
      ref.update({"isWatering": isWatering});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Plant Watering System"),
        backgroundColor: Colors.green[700],
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: Colors.green,
      //   onPressed: () {
      //     setState(() {});
      //   },
      // ),
      backgroundColor: Colors.white,
      body: _mainBody(),
    );
  }

  void showHumidityAlert() {
    if (scilentHumidityAlert) return;
    scilentHumidityAlert = true;

    showDialog(
        context: context,
        builder: (context) {
          if (Platform.isIOS) {
            return CupertinoAlertDialog(
              title: const Text("High Humidity"),
              content: const Text(
                  "High humidity can negatively affect the plant's health"),
              actions: [
                CupertinoDialogAction(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.pop(context, "OK");
                  },
                ),
              ],
            );
          } else {
            return AlertDialog(
              title: const Text("High Humidity"),
              content: const Text(
                  "High humidity can negatively affect the plant's health"),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.pop(context, "OK");
                  },
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        // side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        });
  }

  Widget _mainBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sensorLabelAndData("Temperature", temperature,
                showThresholdAlert: true,
                isRange: true,
                lowerBound: 0,
                upperBound: 50),
            sensorLabelAndData("Humidity", humidity,
                showThresholdAlert: true, threshold: HUMIDITY_THRESHOLD),
            sensorLabelAndData("Soil Moisture", soilMoisture,
                showThresholdAlert: true,
                threshold: SOIL_MOISTURE_THRESHOLD,
                thresholdGreater: false),
            Flexible(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 20),
                // color: isWatering ? Colors.green[900] : Colors.green[300],
                width: 300,
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: disableWateringButton
                      ? null
                      : () {
                          toggleIsWatering();
                        },
                  child: Text(
                    isWatering ? "WATERING" : "WATER PLANT",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  style: ButtonStyle(
                    backgroundColor: isWatering
                        ? MaterialStateProperty.all<Color>(
                            const Color(0xFF1B5E20))
                        : MaterialStateProperty.all<Color>(
                            const Color(0xFF81C784)),
                    padding: MaterialStateProperty.all<EdgeInsets>(
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        // side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              flex: 3,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 20,
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    // Setting AxisTitles() as empty as we do not want any labeling on y axis
                    bottomTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    // leftTitles: AxisTitles(),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: false,
                      ),
                      spots: getFLSpotsForGraph(soilMoistureGraphData),
                    ),
                  ],
                ),
                swapAnimationDuration:
                    const Duration(milliseconds: 50), // Optional
                // swapAnimationCurve: Curves.linear, // Optional
              ),
            ),
            const Flexible(flex: 1, child: Text("")),
            // Row(
            //   children: <Widget>[
            //     sensorLabel("Temperature"),
            //     sensorData(temperature),
            //   ],
            // ),
            // Row(
            //   children: <Widget>[
            //     sensorLabel("Humidity"),
            //     sensorData(humidity),
            //   ],
            // ),
            // Row(
            //   children: <Widget>[
            //     sensorLabel("Soil Moisture"),
            //     sensorData(soilMoisture),
            //   ],
            // ),
            // Container(
            //   margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 20),
            //   // color: isWatering ? Colors.green[900] : Colors.green[300],
            //   width: 300,
            //   alignment: Alignment.center,
            //   child: TextButton(
            //     onPressed: disableWateringButton
            //         ? null
            //         : () {
            //             toggleIsWatering();
            //           },
            //     child: Text(
            //       isWatering ? "WATERING" : "WATER PLANT",
            //       style: const TextStyle(
            //         color: Colors.white,
            //         fontSize: 20,
            //       ),
            //     ),
            //     style: ButtonStyle(
            //       backgroundColor: isWatering
            //           ? MaterialStateProperty.all<Color>(
            //               const Color(0xFF1B5E20))
            //           : MaterialStateProperty.all<Color>(
            //               const Color(0xFF81C784)),
            //       padding: MaterialStateProperty.all<EdgeInsets>(
            //         const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            //       ),
            //       shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            //         RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(10.0),
            //           // side: const BorderSide(color: Colors.green),
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            // humidity >= HUMIDITY_THRESHOLD
            //     ? Container(
            //         height: 50,
            //         padding: const EdgeInsets.all(5),
            //         alignment: Alignment.center,
            //         child: const Text(
            //           "HIGH HUMIDITY",
            //           style: TextStyle(
            //             color: Colors.white,
            //             fontSize: 25,
            //             fontWeight: FontWeight.w500,
            //           ),
            //         ),
            //         decoration: BoxDecoration(
            //           color: Colors.red,
            //           borderRadius: BorderRadius.circular(10),
            //         ),
            //       )
            //     : Container()
          ],
        ),
      ),
    );
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Container(
//   margin:
//       const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//   color: isWatering ? Colors.green[900] : Colors.green[300],
//   alignment: Alignment.center,
//   child: TextButton(
//     onPressed: disableWateringButton
//         ? null
//         : () {
//             toggleIsWatering();
//           },
//     child: const Text(
//       "Water Plant",
//       style: TextStyle(
//         color: Colors.white,
//       ),
//     ),
//   ),
// ),
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// Container(
//   margin:
//       const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//   // width: BoxWidthStyle.max,
//   color: Colors.orangeAccent,
//   alignment: Alignment.center,
//   child: TextButton(
//     onPressed: () {
//       ref.update({
//         "tempLED": true,
//       });
//     },
//     child: const Text("Turn on LED"),
//   ),
// ),

// Container(
//   margin:
//       const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//   color: Colors.orangeAccent,
//   alignment: Alignment.center,
//   child: TextButton(
//     onPressed: () {
//       ref.update({
//         "tempLED": false,
//       });
//     },
//     child: const Text("Turn off LED"),
//   ),
// ),
