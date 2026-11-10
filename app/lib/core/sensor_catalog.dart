import 'package:flutter/material.dart';

import 'theme/tokens.dart';

/// Display info per sensor_type (keys mirror backend/app/contract.py SENSOR_CATALOG).
class SensorInfo {
  const SensorInfo(this.labelTh, this.labelEn, this.icon, this.decimals, this.color, this.tint);

  final String labelTh;
  final String labelEn;
  final IconData icon;
  final int decimals;

  /// Icon colour and the soft background of its round badge.
  final Color color;
  final Color tint;
}

const Map<String, SensorInfo> sensorCatalog = {
  'soil_moisture': SensorInfo('ความชื้นดิน', 'Soil Moisture', Icons.water_drop_outlined, 1,
      AppTokens.sensorWater, AppTokens.sensorWaterTint),
  'soil_temperature': SensorInfo('อุณหภูมิดิน', 'Soil Temperature', Icons.thermostat_outlined, 1,
      AppTokens.sensorSoilHeat, AppTokens.sensorSoilHeatTint),
  'air_temperature': SensorInfo('อุณหภูมิอากาศ', 'Air Temperature', Icons.thermostat, 1,
      AppTokens.sensorAirHeat, AppTokens.sensorAirHeatTint),
  'air_humidity': SensorInfo('ความชื้นอากาศ', 'Air Humidity', Icons.opacity, 0,
      AppTokens.sensorHumidity, AppTokens.sensorHumidityTint),
  'rainfall': SensorInfo('ปริมาณฝน', 'Rainfall', Icons.umbrella_outlined, 1,
      AppTokens.sensorRain, AppTokens.sensorRainTint),
  'wind_speed': SensorInfo('ความเร็วลม', 'Wind Speed', Icons.air, 1,
      AppTokens.sensorWind, AppTokens.sensorWindTint),
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
    sensorCatalog[sensorType] ??
    SensorInfo(sensorType, sensorType, Icons.sensors, 1, AppTokens.primary, AppTokens.primaryTint);

int sensorRank(String sensorType) {
  final i = sensorOrder.indexOf(sensorType);
  return i == -1 ? sensorOrder.length : i;
}
