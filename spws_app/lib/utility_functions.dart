import "package:fl_chart/fl_chart.dart";

List<FlSpot> getFLSpotsForGraph(List graphData) {
  List<FlSpot> newData = [];
  for (int i = 0; i < 21; i++) {
    newData.add(FlSpot(i * 1.0, graphData.elementAt(i) * 1.0));
  }
  return newData;
}
