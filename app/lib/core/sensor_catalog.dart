import 'package:flutter/material.dart';

/// Display info per sensor_type (keys mirror backend/app/contract.py SENSOR_CATALOG).
class SensorInfo {
  const SensorInfo(this.labelTh, this.icon, this.decimals);

  final String labelTh;
  final IconData icon;
  final int decimals;
}

const Map<String, SensorInfo> sensorCatalog = {
  'soil_moisture': SensorInfo('ความชื้นดิน', Icons.water_drop_outlined, 1),
  'soil_temperature': SensorInfo('อุณหภูมิดิน', Icons.thermostat_outlined, 1),
  'air_temperature': SensorInfo('อุณหภูมิอากาศ', Icons.device_thermostat, 1),
  'air_humidity': SensorInfo('ความชื้นอากาศ', Icons.cloud_outlined, 0),
  'rainfall': SensorInfo('ปริมาณฝน', Icons.umbrella_outlined, 1),
  'wind_speed': SensorInfo('ความเร็วลม', Icons.air, 1),
};

/// Display order on the dashboard; unknown types go last.
const List<String> sensorOrder = [
  'soil_moisture',
  'soil_temperature',
  'air_temperature',
  'air_humidity',
  'rainfall',
  'wind_speed',
];

SensorInfo sensorInfo(String sensorType) =>
    sensorCatalog[sensorType] ?? SensorInfo(sensorType, Icons.sensors, 1);

int sensorRank(String sensorType) {
  final i = sensorOrder.indexOf(sensorType);
  return i == -1 ? sensorOrder.length : i;
}
