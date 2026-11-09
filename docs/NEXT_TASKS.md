# AgriTwin — งานถัดไป

แต่ละงานเล็กพอจะสั่ง Codex หรือ Claude ได้ทีละข้อ ให้ใช้คำสั่งรูปแบบ "ทำงาน `<ID>` ตาม docs/NEXT_TASKS.md และ AGENTS.md"
เมื่อเสร็จแล้วให้เปลี่ยน `[ ]` เป็น `[x]` และแนบหลักฐานตาม Definition of Done ในแผน Sprint (log, screenshot หรือผล test)

**นอกขอบเขตรอบนี้:** Camera/360, NPK/pH/EC + BLE, AI Insight, 3D ห้ามเพิ่มจนกว่าจะมีงานใหม่ระบุชัด

## สถานะ Slice 1 (9 พ.ย. 2569)

- [x] Contract v1 + JSON Schema + ตัวอย่าง
- [x] FastAPI + Alembic migration 0001 + MQTT ingest (validation, กันซ้ำ, กักข้อมูลผิดรูป, quality flag)
- [x] REST: health, devices, devices/{id}/latest, dashboard/latest
- [x] Simulator (`--bad`, `--duplicate`) + smoke test แบบ end-to-end
- [x] Backend tests 27 ข้อ (contract + ingest/API + migration down/up) ผ่านบน Linux ด้วย PostgreSQL 16
- [x] Flutter Dashboard (ธีมกลาง, loading/empty/error/stale, ป้ายข้อมูลจำลอง, ค่า suspect) + tests
- [x] Git: แยก branch ตามส่วนงานและ merge เข้า `main` พร้อมเตรียม tag `v0.1.0` (รายการที่ยังไม่ทดสอบอยู่ใน `CHANGELOG.md`)
- [ ] **V-1 ยังไม่ได้คอมไพล์ Flutter** (Flutter SDK เข้าถึงไม่ได้ในสภาพแวดล้อมที่ใช้สร้าง) ต้องรันบน Windows ก่อนทำงานอื่น
- [ ] **V-3 รัน `docker compose up` จริงบน Windows** ยืนยัน healthcheck และการสร้าง `agritwin_test` จาก init script

## ลำดับงานแนะนำ (ช่วงเวลาที่ยังใช้ Claude ได้อีกราว 6 วัน และสอบหัวข้อ 14 พ.ย.)

| วัน | งาน | เป้าหมาย |
|---|---|---|
| 1 (9 พ.ย.) | Slice 1 | ✔ เสร็จฝั่งโค้ด |
| 2 | V-1, V-2, UI-1 (เมื่อได้ภาพ Kaset App) | slice รันจริงบน Windows และมีหลักฐาน |
| 3 | GW-1 (คุยกับคนทำ Hardware), BE-1 | ตัดสินเส้นทาง Gateway และเพิ่ม API ประวัติ |
| 4 | APP-1, BE-2 | กราฟย้อนหลังและหน้าดูข้อมูลที่ถูก reject |
| 5 (13 พ.ย.) | เตรียม demo สอบหัวข้อ | ใช้ข้อมูลจำลองที่ติดป้ายชัดเจน และไม่อ้างว่าระบบเสร็จ |
| 6 | GW-2, BE-3 | contract v1.1 (RSSI/SNR) และ MQTT auth |

## P0 — ยืนยัน Slice 1

- [ ] **V-1 Flutter compile & test บน Windows**
  ทำ: `flutter create --platforms=web,android,windows --project-name agritwin_app .` ใน `app/` จากนั้น `flutter pub get`, `flutter analyze`, `flutter test`
  เสร็จเมื่อ: analyze ไม่มี issue, test ผ่านทั้งหมด และ `flutter run -d chrome` แสดงค่าจาก simulator ถ้ามี error ให้แก้ในโค้ดโดยไม่เปลี่ยน API contract
- [ ] **V-2 หลักฐาน S1**
  ทำ: บันทึก screenshot ของ Dashboard, output ของ `pytest -v`, output ของ smoke test และ `ingest_counts` จาก /health
  เสร็จเมื่อ: ไฟล์หลักฐานอยู่ใน `docs/evidence/s1/`
- [ ] **APP-0 Android: อนุญาต HTTP ในเครือข่ายท้องถิ่น**
  ทำ: เพิ่ม `android:usesCleartextTraffic="true"` ใน `android/app/src/main/AndroidManifest.xml` (เฉพาะช่วง dev) และตรวจว่ามี permission `INTERNET`
  เสร็จเมื่อ: Android emulator ใช้ `--dart-define=API_BASE_URL=http://10.0.2.2:8000` แล้วเห็นข้อมูล

## UI

- [ ] **UI-1 ปรับดีไซน์ตาม Kaset App** — *รอภาพหน้าจอ/สเปกจากเจ้าของโปรเจกต์ ห้ามเดาดีไซน์*
  ทำ: แก้ค่าใน `app/lib/core/theme/tokens.dart` (สี ระยะ มุมโค้ง ขนาดตัวอักษร), ฟอนต์ไทย และ layout ของ `DeviceCard`/`SensorTile` ให้ตรงภาพอ้างอิง
  เสร็จเมื่อ: เทียบ screenshot แบบ before/after กับภาพอ้างอิงแล้ว และ widget test เดิมยังผ่าน
- [ ] **APP-1 กราฟย้อนหลัง** (ต้องทำ BE-1 ก่อน) แตะ SensorTile แล้วเปิดกราฟ 24 ชม./7 วัน มีสถานะ loading/empty/error ครบ และยังแสดงป้ายข้อมูลจำลอง
- [ ] **APP-2 หยุด polling เมื่อแอปอยู่เบื้องหลัง** (`AppLifecycleListener`)

## Backend

- [ ] **BE-1 History API** `GET /api/v1/devices/{id}/readings?sensor_type=&from=&to=&limit=` (limit สูงสุด 5000, เรียงตามเวลา) พร้อม test และอัปเดต DATA_CONTRACT.md
- [ ] **BE-2 Rejects API** `GET /api/v1/ingest/rejects?limit=50` สำหรับ debug ตอนต่อ Gateway จริง
- [ ] **BE-3 MQTT auth + ACL** ตั้ง Mosquitto ให้ใช้ `password_file` + `acl_file` โดย gateway publish ได้เฉพาะ `agritwin/+/devices/+/telemetry` และ backend subscribe ได้ ใส่ secret ใน `.env` เท่านั้น
- [ ] **BE-4 Farm / Plot / Device assignment** (S3) ทำ migration 0002 + CRUD + audit fields และผูก device กับ plot ตามช่วงเวลา
- [ ] **BE-5 ตาราง latest** เมื่อ `sensor_readings` มีมากกว่า ~1 ล้านแถว หรือ `/dashboard/latest` ช้ากว่า 200 ms

## Gateway / IoT (ทำร่วมกับคนทำ Hardware)

- [ ] **GW-1 เลือกเส้นทาง Gateway** ระหว่างแบบ A (serial bridge) หรือ B (LoRaWAN + ChirpStack) ตาม `docs/ARCHITECTURE.md`
  เสร็จเมื่อ: มีสคริปต์ bridge/adapter ที่ publish contract v1 ด้วย `source: "gateway"`, เก็บคิวเมื่อ MQTT หลุดแล้วส่งซ้ำ และ smoke test ผ่านด้วยข้อมูลจริง 1 node
- [ ] **GW-2 Contract v1.1: link quality** เพิ่ม `link: {rssi, snr}` แบบไม่บังคับ เพื่อทดสอบระยะ 500 ม.–1 กม. ตามแผน
- [ ] **GW-3 Device heartbeat topic** `agritwin/{env}/devices/{id}/status`

## Ops

- [ ] **OPS-1 Deploy ขึ้น Home Server** เพิ่ม service `api` ใน docker-compose, `MQTT_ENV=prod`, ตั้ง backup PostgreSQL รายวัน และทดสอบ restore
- [ ] **OPS-2 Git workflow** ใช้ branch `feat/<task-id>-<สั้นๆ>` ต่องาน, merge เข้า `main` เมื่อ test ผ่าน และพิจารณาตั้ง repo เป็น private (ตอนนี้เป็น public)
