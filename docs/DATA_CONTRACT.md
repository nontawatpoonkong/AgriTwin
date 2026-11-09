# AgriTwin — Data Contract v1.0

แหล่งความจริงเดียวในโค้ด: `backend/app/contract.py`
JSON Schema สำหรับทีม Hardware/Gateway: `contracts/telemetry.v1.schema.json`
ตัวอย่าง: `contracts/examples/`

ถ้าจะเปลี่ยน contract ให้ทำตาม "การเปลี่ยนเวอร์ชัน" ท้ายเอกสาร และแจ้งทั้งฝั่งผู้ส่งและผู้รับ (ตามแผน Sprint ข้อ R11)

## 1. MQTT

| รายการ | ค่า |
|---|---|
| Topic | `agritwin/{env}/devices/{device_id}/telemetry` |
| `env` | `dev` (เครื่องพัฒนา), `prod` (Home Server) |
| QoS | 1 |
| Retain | false |
| Encoding | UTF-8 JSON |
| Backend subscribe | `agritwin/{env}/devices/+/telemetry` |

`device_id` ใน topic ต้องตรงกับ `device_id` ใน payload ไม่เช่นนั้นข้อความจะถูก reject

## 2. Telemetry payload

```json
{
  "schema_version": "1.0",
  "message_id": "node-01-1762693200-123",
  "device_id": "node-01",
  "seq": 123,
  "ts": "2026-11-09T13:00:00Z",
  "source": "gateway",
  "readings": [
    { "sensor_type": "soil_moisture", "value": 41.2, "unit": "%" },
    { "sensor_type": "soil_temperature", "value": 27.4, "unit": "°C" }
  ]
}
```

| Field | ชนิด | บังคับ | กฎ |
|---|---|---|---|
| `schema_version` | string | ✔ | ต้องเป็น `"1.0"` |
| `message_id` | string 1–128 | ✔ | ไม่ซ้ำกันทั่วระบบ ใช้กันข้อมูลซ้ำ แนะนำ `{device_id}-{unix_ts}-{seq}` หรือ UUID |
| `device_id` | string | ✔ | `^[a-z0-9][a-z0-9_-]{1,63}$` (ตัวพิมพ์เล็ก ตัวเลข `-` และ `_`) |
| `seq` | int ≥ 0 | – | frame counter ของ node ใช้ตรวจ packet หาย |
| `ts` | ISO 8601 | ✔ | **เวลาที่วัด** ต้องมี timezone (แนะนำ UTC `Z`) และห้ามเป็นอนาคตเกิน 5 นาที ส่วนเวลาในอดีตรับได้ (กรณีส่งจากคิว) |
| `source` | enum | ✔ | `gateway` = ข้อมูลจริง, `simulator` = ข้อมูลจำลอง, `test` = smoke test |
| `readings` | array 1–32 | ✔ | ใน 1 ข้อความ `sensor_type` แต่ละชนิดห้ามซ้ำ |
| `readings[].sensor_type` | enum | ✔ | ต้องอยู่ในตารางข้อ 3 |
| `readings[].value` | number | ✔ | ต้องเป็นตัวเลขจริง (ไม่รับ NaN/Infinity) |
| `readings[].unit` | string | ✔ | ต้องตรงกับหน่วยในตารางข้อ 3 ทุกตัวอักษร |

ไม่รับ field อื่นนอกเหนือจากตาราง (`extra=forbid`) ถ้าต้องการเพิ่ม field ให้เพิ่มเวอร์ชัน

## 3. Sensor catalog v1

| `sensor_type` | ชื่อไทย | `unit` | ช่วงที่สมเหตุสมผล (ถ้าออกนอกช่วงจะเป็น `suspect`) |
|---|---|---|---|
| `soil_moisture` | ความชื้นดิน | `%` | 0 – 100 |
| `soil_temperature` | อุณหภูมิดิน | `°C` | -10 – 70 |
| `air_temperature` | อุณหภูมิอากาศ | `°C` | -10 – 60 |
| `air_humidity` | ความชื้นอากาศ | `%RH` | 0 – 100 |
| `rainfall` | ปริมาณฝน (สะสมตั้งแต่ข้อความก่อนหน้า) | `mm` | 0 – 500 |
| `wind_speed` | ความเร็วลม | `m/s` | 0 – 60 |

`°C` คือ U+00B0 + `C` (UTF-8) หมายเหตุสำหรับ Hardware: ถ้า firmware แปลงหน่วยไม่ได้ ให้ Gateway เป็นผู้แปลงก่อน publish

## 4. ผลลัพธ์ของการรับข้อมูล

| กรณี | ผลลัพธ์ | เก็บที่ |
|---|---|---|
| ผ่านทุกกฎ | `accepted` | `telemetry_messages` (raw + provenance) และ `sensor_readings` |
| ค่าอยู่นอกช่วงสมเหตุสมผล | `accepted` พร้อม `quality = "suspect"` | `sensor_readings` (แอปแสดงกรอบเตือน) |
| `message_id` ซ้ำ | `duplicate` จะถูกข้าม | ไม่เก็บซ้ำ |
| JSON ผิด, schema ผิด, หน่วยผิด, topic ไม่ตรง | `rejected` | `ingest_rejects` (ไม่แสดงบน Dashboard) |

ดูข้อความที่ถูก reject ได้ด้วย SQL `SELECT received_at, topic, error FROM ingest_rejects ORDER BY id DESC LIMIT 20;`

## 5. REST API v1 (สำหรับ Flutter)

Base URL ตอนพัฒนา: `http://localhost:8000` และดูเอกสารแบบโต้ตอบได้ที่ `http://localhost:8000/docs`
เวลาทุกค่าเป็น ISO 8601 UTC

### `GET /api/v1/dashboard/latest` — Dashboard ใช้เส้นนี้เส้นเดียว

```json
{
  "server_time": "2026-11-09T13:35:40.208065Z",
  "offline_after_seconds": 180,
  "devices": [
    {
      "device_id": "sim-node-01",
      "display_name": null,
      "status": "online",
      "last_seen_at": "2026-11-09T13:35:38.149075Z",
      "last_source": "simulator",
      "readings": [
        {
          "sensor_type": "soil_moisture",
          "value": 48.1,
          "unit": "%",
          "quality": "ok",
          "source": "simulator",
          "measured_at": "2026-11-09T13:35:38Z"
        }
      ]
    }
  ]
}
```

- `status`: `online` ถ้าเซิร์ฟเวอร์ได้รับข้อความภายใน `offline_after_seconds` (ค่าเริ่มต้น 180 วินาที) ไม่เช่นนั้นเป็น `offline`
- `readings`: ค่าล่าสุดของแต่ละ `sensor_type` เรียงตาม `measured_at`
- แอปคำนวณ "อัปเดตเมื่อ x วินาทีที่แล้ว" จาก `server_time - last_seen_at` เพื่อไม่ให้ขึ้นกับนาฬิกาของมือถือ

### `GET /api/v1/devices` — รายการอุปกรณ์ (ไม่มีค่าเซนเซอร์)
### `GET /api/v1/devices/{device_id}/latest` — ค่าล่าสุดของอุปกรณ์เดียว (404 ถ้าไม่พบ)
### `GET /api/v1/health`

```json
{ "status": "ok", "database": "up", "mqtt": "connected",
  "ingest_counts": { "accepted": 5, "duplicate": 4, "rejected": 2, "errors": 0 },
  "server_time": "..." }
```

`ingest_counts` เป็นตัวนับตั้งแต่ API เริ่มทำงาน และจะรีเซ็ตเมื่อ restart

## 6. การเปลี่ยนเวอร์ชัน

- **เพิ่ม `sensor_type` ใหม่**: เพิ่มใน `SENSOR_CATALOG` + `app/lib/core/sensor_catalog.dart` + ตารางข้อ 3 ยังใช้ v1.0 ได้ (เป็นการขยายที่ไม่ทำให้ผู้ส่งเดิมพัง)
- **เพิ่ม field แบบไม่บังคับ** (เช่น `link.rssi`, `link.snr` สำหรับทดสอบระยะ LoRa): ใช้ `schema_version: "1.1"` และ backend ต้องรับทั้ง 1.0 และ 1.1
- **เปลี่ยนความหมายหรือลบ field**: ใช้ `2.0` และเปิด topic/handler ใหม่ควบคู่ไปจนกว่าทุกอุปกรณ์จะย้าย
- ทุกครั้งที่เปลี่ยน: รัน `python -m app.contract --write` (ใน `backend/`) และอัปเดตเอกสารนี้ ห้ามใช้ `>` redirect เพราะ PowerShell 5.1 บน Windows จะบันทึกไฟล์เป็น UTF-16 หรือ UTF-8 แบบมี BOM ซึ่ง JSON parser อ่านไม่ได้
