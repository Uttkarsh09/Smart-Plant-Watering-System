import 'package:flutter/material.dart';

Widget sensorLabel(String label) {
  return Flexible(
    child: Container(
      height: 125,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      decoration: BoxDecoration(
        color: Colors.green[600],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          width: 2,
          color: Colors.white,
        ),
      ),
    ),
  );
}

Widget sensorData(num data) {
  return Flexible(
    child: Container(
      height: 125,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      alignment: Alignment.center,
      child: Text(
        "$data",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      decoration: BoxDecoration(
        color: Colors.lightGreen,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          width: 2,
          color: Colors.white,
        ),
      ),
    ),
  );
}

bool isOutOfSafeBounds(num data, int lowerBound, int upperBound) {
  if (data < lowerBound || data > upperBound) {
    return true;
  }
  return false;
}

Widget sensorLabelAndData(
  String labelName,
  num data, {
  bool showThresholdAlert = false,
  num threshold = 50,
  bool thresholdGreater = true,
  bool isRange = false,
  int lowerBound = 0,
  int upperBound = 0,
}) {
  return Flexible(
    flex: 2,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.green[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 3,
            color: showThresholdAlert &&
                    (isRange
                        ? isOutOfSafeBounds(data, lowerBound, upperBound)
                        : ((data >= threshold) == thresholdGreater))
                ? Colors.red
                : const Color(0xFFA5D6A7),
          )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            labelName,
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 26,
              fontFamily: 'Ubuntu',
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: Text("$data",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontFamily: "Ubuntu",
                )),
          )
        ],
      ),
    ),
  );
}
