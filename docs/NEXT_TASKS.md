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
- [x] Flutter บน Windows: `flutter test` ผ่าน 9/9 และแก้ info จาก `flutter analyze` แล้ว
- [x] `CLAUDE.md` import `AGENTS.md` เพื่อให้ Claude Code ใช้กติกาเดียวกับ Codex
- [x] แก้คำสั่ง regenerate JSON Schema ให้ใช้บน Windows PowerShell ได้ (`python -m app.contract --write`)
- [x] **V-1** `flutter analyze` ได้ 0 issue และ `flutter run -d chrome` แสดงค่าจาก simulator พร้อมป้าย "ข้อมูลจำลอง" (เจ้าของโปรเจกต์ตรวจหน้าจอแล้ว)
- [x] **V-3** `docker compose up` บน Windows: postgres healthy, Mosquitto ทำงาน และ init script สร้าง `agritwin_test` แล้ว
- [x] Backend บน Windows (Python 3.12.10): `alembic upgrade head`, `pytest` ผ่าน 29 ข้อ, smoke test และ simulator `--bad`/`--duplicate` ผ่าน
- [x] แก้แถบ "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (Connection closed before full header was received)" ที่ขึ้นเป็นครั้งคราวบน Android: รอบ poll 5 วินาทีชนกับเวลาที่ uvicorn ปิด keep-alive connection (`--timeout-keep-alive` ค่าเริ่มต้น 5 วินาที) ตอนนี้ `AgriTwinApi` retry GET หนึ่งครั้งบน connection ใหม่ (web ไม่เคยเจอปัญหานี้เพราะ browser retry เอง)

## ปัญหาที่รู้แล้ว (พบตอนยืนยันบน Windows และ Android 9–10 พ.ย. 2569)

- **History API ยังไม่รวมข้อมูลเป็นช่วง (BE-1):** ส่งได้สูงสุด 5000 ค่าต่อครั้ง ถ้าข้อมูลถี่และขอช่วงยาวจะได้แค่ 5000 ค่าล่าสุด (`truncated: true`) เช่น simulator ที่ส่งทุก 10 วินาที 5000 ค่าคิดเป็นราว 14 ชั่วโมง ส่วนเซนเซอร์ที่ส่งทุก 60 วินาทีจะมีราว 10,080 ค่าใน 7 วัน ดูข้อเสนอ BE-6
- **History API ที่ไม่ระบุ `sensor_type`:** index `(device_id, sensor_type, measured_at)` ใช้ได้ไม่เต็มที่ เพราะต้องเรียงข้อมูลทุกชนิดของอุปกรณ์นั้น ตอนนี้ข้อมูลยังน้อยจึงไม่มีปัญหา ถ้าช้าให้พิจารณาเพิ่ม index `(device_id, measured_at)` ด้วย migration ใหม่
- **release build ยังเรียก `http://` ได้:** HTTP client ของ Dart ไม่ได้อ่านนโยบาย cleartext ของ Android ตอน deploy จริง (OPS-1) จึงต้องตั้ง `API_BASE_URL` เป็น `https://`
- **`localhost` ช้าบน Windows:** `localhost` resolve เป็น `::1` ก่อน แต่ uvicorn ฟังแค่ IPv4 โปรแกรมที่ไม่ใช่ browser (Python, PowerShell) จึงเสียเวลาราว 2 วินาทีต่อ connection ใหม่ ถ้าเรียกจากสคริปต์ให้ใช้ `http://127.0.0.1:8000` (Chrome ไม่มีปัญหานี้)
- **มือถือจริงต้องเปิด host ของ API:** uvicorn ค่าเริ่มต้นฟังแค่ `127.0.0.1` ถ้าจะทดสอบกับมือถือจริงใน LAN ต้องรันด้วย `--host 0.0.0.0` และเปิดพอร์ต 8000 ใน Windows Firewall (emulator ใช้ `10.0.2.2` ได้เลย) เขียนขั้นตอนไว้ใน README แล้ว
- **Docker เปิดพอร์ตบนทุก interface:** 1883 และ 5433 ผูกกับ `0.0.0.0` เครื่องอื่นใน LAN จึงส่งข้อความเข้า Mosquitto แบบ anonymous ได้จนกว่าจะทำ BE-3 (หรือผูกพอร์ตกับ `127.0.0.1` ใน compose ระหว่าง dev)
- **pytest warning:** Starlette 1.10 (dependency ทางอ้อมที่ไม่ได้ pin) เตือนว่าการใช้ `httpx` กับ `TestClient` เลิกแนะนำแล้ว ควรพิจารณา pin `starlette` หรือย้ายตามคำแนะนำก่อนที่ test จะพัง
- **ไฟล์ generated ขึ้น modified:** `flutter pub get` เขียน `app/windows/flutter/generated_*` ใหม่ด้วย LF ทำให้ `git status` ขึ้น modified ทั้งที่เนื้อหาไม่เปลี่ยน แก้ได้ด้วย rule ใน `.gitattributes`

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

- [x] **V-1 Flutter run บน Windows** (platform folders อยู่ใน repo แล้ว ไม่ต้องรัน `flutter create` อีก)
  ทำ: `cd app` → `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
  เสร็จเมื่อ: analyze ได้ 0 issue (test ผ่านแล้ว 9/9) และหน้า Dashboard แสดงค่าจาก simulator พร้อมป้าย "ข้อมูลจำลอง"
  ผล (9 พ.ย. 2569): analyze 0 issue, test 9/9 และเจ้าของโปรเจกต์ยืนยันว่าหน้า Dashboard แสดงถูกต้อง
- [ ] **V-2 หลักฐาน S1**
  ทำ: บันทึก screenshot ของ Dashboard, output ของ `pytest -v`, output ของ smoke test และ `ingest_counts` จาก /health
  เสร็จเมื่อ: ไฟล์หลักฐานอยู่ใน `docs/evidence/s1/`
- [x] **APP-0 Android: อนุญาต HTTP ในเครือข่ายท้องถิ่น**
  ทำ: เพิ่ม `android:usesCleartextTraffic="true"` ใน `android/app/src/main/AndroidManifest.xml` (เฉพาะช่วง dev) และตรวจว่ามี permission `INTERNET`
  เสร็จเมื่อ: Android emulator ใช้ `--dart-define=API_BASE_URL=http://10.0.2.2:8000` แล้วเห็นข้อมูล
  ผล (9 พ.ย. 2569): ใส่ `INTERNET` ใน `main/AndroidManifest.xml` และใส่ `usesCleartextTraffic` เฉพาะใน manifest ของ `debug`/`profile` (แทนการใส่ใน main) แล้วทดสอบบน emulator Android 17 (API 37) ครบ 4 แบบ: debug ทั้งก่อนและหลังแก้แสดงข้อมูลได้, release ก่อนแก้ขึ้น `SocketException: Operation not permitted` ส่วน release หลังแก้แสดงข้อมูลได้ สรุปว่าส่วนที่จำเป็นจริงคือ `INTERNET` เพราะ HTTP client ของ Dart ไม่ได้อ่านค่า cleartext ของ Android

## UI

- [ ] **UI-1 ปรับดีไซน์ตาม Kaset App** — *รอภาพหน้าจอ/สเปกจากเจ้าของโปรเจกต์ ห้ามเดาดีไซน์*
  ทำ: แก้ค่าใน `app/lib/core/theme/tokens.dart` (สี ระยะ มุมโค้ง ขนาดตัวอักษร), ฟอนต์ไทย และ layout ของ `DeviceCard`/`SensorTile` ให้ตรงภาพอ้างอิง
  เสร็จเมื่อ: เทียบ screenshot แบบ before/after กับภาพอ้างอิงแล้ว และ widget test เดิมยังผ่าน
- [ ] **APP-1 กราฟย้อนหลัง** (ต้องทำ BE-1 ก่อน) แตะ SensorTile แล้วเปิดกราฟ 24 ชม./7 วัน มีสถานะ loading/empty/error ครบ และยังแสดงป้ายข้อมูลจำลอง
- [ ] **APP-2 หยุด polling เมื่อแอปอยู่เบื้องหลัง** (`AppLifecycleListener`)

## Backend

- [x] **BE-1 History API** `GET /api/v1/devices/{id}/readings?sensor_type=&from=&to=&limit=` (limit สูงสุด 5000, เรียงตามเวลา) พร้อม test และอัปเดต DATA_CONTRACT.md
  ผล (10 พ.ย. 2569): `from` รวมขอบ `to` ไม่รวมขอบ, `limit` ค่าเริ่มต้น 1000 (1–5000), ข้อมูลเกิน limit ได้ค่าล่าสุดพร้อม `truncated`, 404/422 ตามเอกสาร มี test 21 ข้อ (pytest รวม 55 ข้อ) และ pytest จะหยุดเองถ้า `TEST_DATABASE_URL` ไม่ได้ชี้ไปที่ฐาน `*_test`
- [ ] **BE-2 Rejects API** `GET /api/v1/ingest/rejects?limit=50` สำหรับ debug ตอนต่อ Gateway จริง
- [ ] **BE-3 MQTT auth + ACL** ตั้ง Mosquitto ให้ใช้ `password_file` + `acl_file` โดย gateway publish ได้เฉพาะ `agritwin/+/devices/+/telemetry` และ backend subscribe ได้ ใส่ secret ใน `.env` เท่านั้น
- [ ] **BE-4 Farm / Plot / Device assignment** (S3) ทำ migration 0002 + CRUD + audit fields และผูก device กับ plot ตามช่วงเวลา
- [ ] **BE-5 ตาราง latest** เมื่อ `sensor_readings` มีมากกว่า ~1 ล้านแถว หรือ `/dashboard/latest` ช้ากว่า 200 ms
- [ ] **BE-6 รวมข้อมูลย้อนหลังเป็นช่วง** (ข้อเสนอจาก BE-1) เพิ่มพารามิเตอร์ เช่น `bucket=1h` ให้ History API ส่งค่าเฉลี่ย/ต่ำสุด/สูงสุดต่อช่วง เพื่อให้กราฟ 7 วันครอบคลุมทั้งช่วงแม้ข้อมูลเกิน 5000 ค่า และยังบอกได้ว่าแต่ละช่วงมีข้อมูลที่ไม่ใช่ `gateway` หรือไม่

## Gateway / IoT (ทำร่วมกับคนทำ Hardware)

- [ ] **GW-1 เลือกเส้นทาง Gateway** ระหว่างแบบ A (serial bridge) หรือ B (LoRaWAN + ChirpStack) ตาม `docs/ARCHITECTURE.md`
  เสร็จเมื่อ: มีสคริปต์ bridge/adapter ที่ publish contract v1 ด้วย `source: "gateway"`, เก็บคิวเมื่อ MQTT หลุดแล้วส่งซ้ำ และ smoke test ผ่านด้วยข้อมูลจริง 1 node
- [ ] **GW-2 Contract v1.1: link quality** เพิ่ม `link: {rssi, snr}` แบบไม่บังคับ เพื่อทดสอบระยะ 500 ม.–1 กม. ตามแผน
- [ ] **GW-3 Device heartbeat topic** `agritwin/{env}/devices/{id}/status`

## Ops

- [ ] **OPS-1 Deploy ขึ้น Home Server** เพิ่ม service `api` ใน docker-compose, `MQTT_ENV=prod`, ตั้ง backup PostgreSQL รายวัน และทดสอบ restore
- [ ] **OPS-2 Git workflow** ใช้ branch `feat/<task-id>-<สั้นๆ>` ต่องาน, merge เข้า `main` เมื่อ test ผ่าน และพิจารณาตั้ง repo เป็น private (ตอนนี้เป็น public)
