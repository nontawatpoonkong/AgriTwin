# AgriTwin — Architecture (Vertical Slice 1)

เป้าหมายของ slice นี้: **ข้อมูลเซนเซอร์จำลอง → MQTT → FastAPI → PostgreSQL → Flutter Dashboard (ค่าล่าสุด)**
ออกแบบให้คนพัฒนาคนเดียวรันและดูแลได้บนเครื่อง Windows เครื่องเดียว และย้ายไป Home Server (i7-10510U / 16 GB) ได้โดยไม่ต้องเปลี่ยนโครงสร้าง

## ภาพรวม

```
 ตอนนี้ (slice 1)                         ภายหลัง (S2+)
 ┌──────────────┐                         ┌────────────┐   LoRa    ┌──────────────────┐
 │ simulator/   │                         │ Field Node │ ───────▶  │ Home Gateway     │
 │ simulate.py  │                         └────────────┘           │ (bridge/adapter) │
 └──────┬───────┘                                                  └────────┬─────────┘
        │ publish JSON (contract v1)                                        │ publish JSON (contract v1) — เหมือนกัน
        ▼                                                                   ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ Mosquitto (MQTT broker)   topic: agritwin/{env}/devices/{device_id}/telemetry     │
 └──────────────────────────────────────┬──────────────────────────────────────────┘
                                        │ subscribe (QoS 1)
 ┌──────────────────────────────────────▼──────────────────────────────────────────┐
 │ FastAPI process (backend/)                                                        │
 │  ├─ mqtt_worker.py  รับข้อความ → ingest.py ตรวจ schema, กันข้อมูลซ้ำ, กักข้อมูลผิดรูป  │
 │  └─ api.py          REST /api/v1/...  (Flutter เรียก)                              │
 └──────────────────────────────────────┬──────────────────────────────────────────┘
                                        │ SQLAlchemy + Alembic
                               ┌────────▼────────┐
                               │ PostgreSQL 16   │ devices, telemetry_messages,
                               └─────────────────┘ sensor_readings, ingest_rejects
                                        ▲
                                        │ HTTP GET ทุก 5 วินาที
                               ┌────────┴────────┐
                               │ Flutter app     │ Dashboard ค่าล่าสุด
                               └─────────────────┘
```

## การตัดสินใจหลักและเหตุผล

| เรื่อง | เลือก | เหตุผล |
|---|---|---|
| จุดรวมข้อมูลจากอุปกรณ์ | **MQTT topic + JSON payload กลาง (contract v1)** | Simulator, Gateway แบบ serial และ ChirpStack adapter ต่างส่ง payload รูปเดียวกัน backend จึงไม่ต้องรู้ว่าข้อมูลมาจากไหน |
| ตัวรับ MQTT | **อยู่ใน process เดียวกับ FastAPI** | คนเดียวดูแลง่าย สั่งรันครั้งเดียว ส่วนตรรกะ ingest แยกอยู่ใน `ingest.py` ถ้าภายหลังต้องแยกเป็น service ก็ย้ายได้ทันที |
| Flutter รับข้อมูล | **REST polling ทุก 5 วินาที** | เซนเซอร์ส่งทุก 10–60 วินาที polling จึงพอ ใช้ได้ทั้ง web, Android และ Windows โดยไม่ต้องเปิด broker สู่ภายนอก |
| ฐานข้อมูล | **PostgreSQL ธรรมดา + index (device, sensor, time)** | ตรงกับข้อกำหนด และพอสำหรับ 1–2 แปลงต่อภาคเรียน (ราวหลักแสนแถว) |
| Migration | **Alembic** (มี upgrade/downgrade) | ตรงกับเกณฑ์ S1 "migration up และ down" และมี test ยืนยัน |
| การรันตอนพัฒนา | **Docker เฉพาะ PostgreSQL + Mosquitto** ส่วน API/Flutter รันตรงบนเครื่อง | reload เร็ว debug ง่ายบน Windows ใช้ compose ไฟล์เดียวกันบน Home Server ได้ |
| State ใน Flutter | **ChangeNotifier + ListenableBuilder** | 1 หน้าจอยังไม่จำเป็นต้องใช้ Riverpod/Bloc ไม่มี dependency เพิ่ม |
| การแยกข้อมูลจริงกับข้อมูลจำลอง | **field `source` ใน payload** (`simulator`/`gateway`/`test`) | ตาม DoD ของแผน Sprint แอปจะแสดงป้าย "ข้อมูลจำลอง" อัตโนมัติ |
| ความถูกต้องของข้อมูล | ผิดรูป → `ingest_rejects`, ค่าผิดช่วง → เก็บแต่ `quality=suspect`, ซ้ำ → ข้ามด้วย `message_id` | ตาม DoD "ข้อมูลผิดรูปถูกกักและไม่ปะปน" และรองรับกรณี Gateway ส่งซ้ำ |
| ค่าล่าสุด | เรียงตาม `measured_at` ไม่ใช่เวลาที่รับ | ข้อมูลเก่าที่ Gateway ส่งตามหลังจากคิวจะไม่ทับค่าที่ใหม่กว่า |

## ทางเลือกที่ตัดออก (และจะกลับมาพิจารณาเมื่อไร)

| ทางเลือก | เหตุผลที่ตัด | กลับมาพิจารณาเมื่อ |
|---|---|---|
| Flutter ต่อ MQTT ตรง | ต้องเปิด broker สู่แอป จัดการสิทธิ์ยากขึ้น web ต้องใช้ WebSocket | ต้องการ realtime ต่ำกว่า 1 วินาที |
| WebSocket / SSE จาก FastAPI | เพิ่มงานจัดการการเชื่อมต่อ ในขณะที่ polling เพียงพอ | มีหลายหน้าจอที่ต้องอัปเดตสด |
| แยก ingest worker เป็นอีก service | มี process ให้ดูแลเพิ่ม | ข้อมูลเข้าเยอะ หรือ API ต้องรันหลาย worker |
| TimescaleDB / InfluxDB | เพิ่มระบบที่ต้องเรียนรู้ เกินขนาดข้อมูลจริง | ข้อมูลหลายล้านแถว หรือ query ช่วงเวลายาวช้า |
| ChirpStack ตั้งแต่ตอนนี้ | ยังไม่ได้ซื้อฮาร์ดแวร์ และเอกสารยังไม่ยืนยันว่าใช้ LoRaWAN หรือ LoRa แบบ serial | Hardware ยืนยันเส้นทางใน S2 (ดู GW-1) |
| Node-RED / Telegraf เป็นตัวกลาง | เพิ่มระบบอีกชั้นที่ต้องดูแล | ไม่มีแผน |
| Docker สำหรับ API ตอนพัฒนา | reload ช้า debug บน Windows ยากขึ้น | ตอน deploy ขึ้น Home Server (OPS-1) |
| ระบบ Login/JWT, Farm/Plot | ไม่จำเป็นต่อ slice แรก | S3 ตามแผน Sprint |
| Riverpod/Bloc, go_router | ยังมีแค่ 1 หน้าจอ | เมื่อมีหน้าจอมากกว่า 2–3 หน้า |
| Firebase/Supabase | stack ถูกกำหนดแล้ว และข้อมูลควรอยู่บน Home Server | ไม่มีแผน |

## เส้นทางเชื่อม Home Gateway จริง (ยังไม่ทำ)

เอกสารสองฉบับยังไม่ตรงกัน: แผนจัดซื้อใช้ **LoRaWAN Gateway + ChirpStack** แต่แผน Sprint ใช้ **Gateway bridge จาก serial ไป MQTT** สถาปัตยกรรมนี้รองรับได้ทั้งสองแบบโดยไม่ต้องแก้ backend

- **แบบ A — LoRa แบบ serial:** สคริปต์บน Gateway อ่าน serial → สร้าง payload v1 (`source: "gateway"`) → publish ไป topic เดียวกับ simulator หากเน็ตหลุดให้เก็บคิวไว้แล้วส่งซ้ำ (backend กันข้อมูลซ้ำด้วย `message_id`)
- **แบบ B — LoRaWAN + ChirpStack:** adapter subscribe `application/+/device/+/event/up` จาก ChirpStack → แปลงข้อมูลที่ decode แล้วเป็น payload v1 → publish ไป topic เดียวกัน (ใช้ `devEui` + `fCnt` สร้าง `message_id`)

## ข้อจำกัดที่รู้แล้ว

- รหัสผ่าน PostgreSQL อ่านจาก `infra/.env` และ `backend/.env` ซึ่งไม่เข้า Git
- Mosquitto ตอนนี้เปิดให้เชื่อมแบบ anonymous สำหรับพัฒนาเท่านั้น ต้องตั้งรหัสผ่านและ ACL ก่อนเปิดให้เครื่องอื่นเข้าถึง (BE-3)
- อุปกรณ์จะถูกลงทะเบียนอัตโนมัติเมื่อส่งข้อความแรก ยังไม่มีขั้นตอนยืนยันตัวตนอุปกรณ์
- ค่าล่าสุดใช้ `DISTINCT ON` จากตาราง readings ทั้งหมด ถ้าข้อมูลโตมากควรเพิ่มตาราง latest (BE-5)
