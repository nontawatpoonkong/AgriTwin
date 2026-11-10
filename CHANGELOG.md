# Changelog

## Unreleased

### Added
- `CLAUDE.md` ที่ import `AGENTS.md` ด้วยบรรทัด `@AGENTS.md` เพื่อให้ Claude Code โหลดกติกาชุดเดียวกับ Codex ทุกครั้ง (แก้กติกาที่ `AGENTS.md` ที่เดียว)
- Android: ตั้ง `usesCleartextTraffic` เฉพาะใน manifest ของ debug/profile เพื่อให้ระบบเครือข่ายของ Android เอง (เช่น WebView) คุยกับ API แบบ HTTP ตอนพัฒนาได้ ส่วน HTTP client ของ Dart ไม่ได้อ่านค่านี้ และเรียก `http://` ได้อยู่แล้ว (APP-0)
- History API `GET /api/v1/devices/{device_id}/readings` กรองตาม `sensor_type` และช่วงเวลา `from` (รวมขอบ) ถึง `to` (ไม่รวมขอบ) มี `limit` 1–5000 (ค่าเริ่มต้น 1000) เรียงจากเก่าไปใหม่ ถ้าเกิน limit จะได้ค่าล่าสุดพร้อม `truncated: true` ทุกค่ามี `source` และ `quality` (BE-1)
- pytest หยุดทันทีถ้า `TEST_DATABASE_URL` ไม่ได้ชี้ไปที่ฐานที่ชื่อลงท้าย `_test` หรือชี้ไปฐานเดียวกับ `DATABASE_URL` และแสดงชื่อฐานเป้าหมาย (ไม่แสดงรหัสผ่าน) ในหัว output ของ pytest
- กราฟย้อนหลัง: แตะการ์ดเซนเซอร์บน Dashboard เพื่อเปิดกราฟ 24 ชม./7 วันจาก History API มีค่าล่าสุด/ต่ำสุด/สูงสุด, สถานะ loading/empty/error/stale, ป้าย "ข้อมูลจำลอง", ข้อความเตือนเมื่อข้อมูลถูกตัด, เครื่องหมายค่าผิดปกติ และไม่ลากเส้นข้ามช่วงที่ข้อมูลหาย วาดด้วย CustomPainter โดยไม่เพิ่ม package และใช้ธีมเดิม (APP-1)

### Fixed
- คำสั่ง regenerate JSON Schema ใช้บน Windows ได้แล้ว: `python -m app.contract --write` (ใน `backend/`) เขียน `contracts/telemetry.v1.schema.json` เป็น UTF-8 ไม่มี BOM และใช้ LF เอง เดิมใช้ `>` redirect ซึ่ง PowerShell 5.1 บันทึกเป็น UTF-16 หรือ UTF-8 แบบมี BOM ทำให้ `json.loads` อ่านไม่ได้และ test schema ไม่ผ่าน (เพิ่ม test 2 ข้อ)
- Android: build แบบ release ไม่มี permission `INTERNET` (เดิมมีแค่ใน manifest ของ debug/profile) จึงเรียก API ไม่ได้และขึ้น `SocketException: Operation not permitted` เพิ่มไว้ใน `main/AndroidManifest.xml` แล้ว (APP-0)
- README: ขั้นตอนทดสอบกับมือถือจริงขาด `--host 0.0.0.0` ของ uvicorn (ค่าเริ่มต้นฟังแค่ `127.0.0.1`)
- แอปบน Android/desktop ขึ้นแถบ "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (Connection closed before full header was received)" เป็นครั้งคราว เพราะรอบ poll 5 วินาทีชนกับเวลาที่ uvicorn ปิด keep-alive connection (5 วินาที) ตอนนี้ `AgriTwinApi` retry คำขอ GET หนึ่งครั้งเมื่อเกิด error ระดับ connection แต่ไม่ retry กรณี timeout หรือ HTTP error (เพิ่ม test 5 ข้อ รวม test ที่ใช้ server จริงตัด connection ก่อนส่ง header)

### ทดสอบแล้วบน Windows (9 พ.ย. 2569: Windows 11, Python 3.12.10, Docker Engine 29.9.2 + Compose v5.6.1, Flutter 3.41.6)
- `docker compose up -d`: `postgres:16` healthy, `eclipse-mosquitto` 2.1.2 ทำงาน และ init script สร้าง `agritwin_test` แล้ว (V-3)
- Backend: `alembic upgrade head` (0001), `pytest` ผ่าน 29 ข้อ, `scripts/smoke_test.py` PASS และ simulator `--bad`/`--duplicate` ให้ตัวนับ rejected/duplicate ตรงตามคาด
- Flutter: `flutter analyze` 0 issue, `flutter test` 9/9 และ `flutter run -d chrome` แสดงค่าจาก simulator พร้อมป้าย "ข้อมูลจำลอง" เจ้าของโปรเจกต์ตรวจหน้าจอแล้วว่าแสดงถูกต้อง รวมถึงภาษาไทย (V-1)
- Android emulator (Android 17 / API 37, AVD `AgriTwin_API_37`) กับ `API_BASE_URL=http://10.0.2.2:8000`: APK ทั้ง debug และ release หลังแก้ APP-0 แสดงค่าจาก simulator พร้อมป้าย "ข้อมูลจำลอง" ส่วน release ก่อนแก้เรียก API ไม่ได้ (APP-0)
- 10 พ.ย. 2569: History API กับฐาน dev จริง (ได้ 200/404/422 ตามเอกสาร) และกราฟย้อนหลังใน web build บน Chrome ของ Claude desktop กับ API จริง: เปิดจาก tile ได้ และช่วง 24 ชม./7 วันส่ง `from` ถูกต้อง (BE-1, APP-1) ยังไม่ได้ลองกราฟบน Android

### ข้อจำกัดที่พบเพิ่ม
- ดูหัวข้อ "ปัญหาที่รู้แล้ว" ใน `docs/NEXT_TASKS.md`: `localhost` ช้าบน Windows, มือถือจริงต้องรัน uvicorn ด้วย `--host 0.0.0.0`, พอร์ต Docker เปิดบนทุก interface, deprecation warning ของ Starlette และ release build ยังใช้ `http://` ได้

## v0.1.0 — 2026-11-09 — Vertical Slice 1 (simulated data)

เส้นทางข้อมูลแรกที่ทำงานครบ: simulator → MQTT → FastAPI ingest → PostgreSQL → REST → Flutter Dashboard
**ทุกค่าที่แสดงเป็นข้อมูลจำลอง ยังไม่ใช่ผลวัดจริงจากแปลง**

### Added
- Telemetry contract v1.0 (`backend/app/contract.py`, `contracts/telemetry.v1.schema.json`) ครอบคลุม device ID, เวลาวัด, sensor type, value, unit และ source
- FastAPI backend: MQTT ingest (schema validation, idempotency ด้วย `message_id`, quarantine ไป `ingest_rejects`, quality flag `ok`/`suspect`)
- PostgreSQL schema ผ่าน Alembic migration `0001` (upgrade + downgrade)
- REST API v1: `/health`, `/devices`, `/devices/{id}/latest`, `/dashboard/latest`
- Simulator (`--bad`, `--duplicate`) และ end-to-end smoke test
- Flutter Dashboard: ค่าล่าสุดต่ออุปกรณ์, สถานะออนไลน์/ออฟไลน์, ป้าย "ข้อมูลจำลอง", ค่า suspect และสถานะ loading/empty/error/stale (ใช้ธีมกลาง ยังไม่ใช่ดีไซน์ Kaset App)
- docker-compose สำหรับ PostgreSQL 16 + Mosquitto 2 (รหัสผ่านอ่านจาก `infra/.env` ที่ไม่ commit)
- เอกสาร: README (Windows), ARCHITECTURE, DATA_CONTRACT, NEXT_TASKS, AGENTS.md
- Flutter platform scaffolding (android, web, windows) + `pubspec.lock` ที่สร้างบน Windows

### Fixed
- `flutter analyze`: แก้ info `unintended_html_in_doc_comment` ใน `lib/core/config.dart`

### ทดสอบแล้ว (Linux, Python 3.13, PostgreSQL 16.15, Mosquitto 2.0.18 แบบติดตั้งตรง ไม่ใช้ Docker)
- `pytest` ผ่าน 27 ข้อ ครอบคลุม contract, ingest, API, การกันข้อมูลซ้ำ, quarantine, ข้อมูลที่มาไม่เรียงลำดับ, สถานะ offline และ migration down/up
- `scripts/smoke_test.py` ผ่าน (MQTT → API → PostgreSQL → REST)
- Simulator `--bad --duplicate` ให้ผลถูกต้อง (accepted/duplicate/rejected ตรงตามคาด) และ CORS preflight ตอบ 200
- `infra/postgres/init-test-db.sh` และ `infra/mosquitto/mosquitto.conf` ใช้งานได้กับ PostgreSQL/Mosquitto ที่ติดตั้งตรง
- `docker compose config` ผ่าน และจะหยุดพร้อมข้อความเตือนถ้าไม่ได้ตั้ง `POSTGRES_PASSWORD`

### ทดสอบแล้วบน Windows (รายงานโดยเจ้าของโปรเจกต์ 9 พ.ย. 2569)
- `flutter create`, `flutter pub get` ผ่าน
- `flutter test` ผ่าน 9/9 (widget + API client)
- `flutter analyze` พบ info 1 รายการ แก้แล้วใน commit `90f7699` แต่**ยังไม่ได้รัน analyze ซ้ำหลังแก้**

### ยังไม่ได้ทดสอบ
- **Flutter UI จริง**: ยังไม่ได้รัน `flutter run` กับ API และ simulator จริง จึงยังไม่เคยเห็นหน้าจอจริง (รวมถึงการแสดงผลภาษาไทยด้วย)
- **Backend บน Windows**: คำสั่ง PowerShell, venv, Python 3.12, `pytest` และ smoke test บน Windows
- **Docker containers จริง**: ยังไม่ได้รัน `docker compose up` (ตรวจแค่ config) ทั้ง image `postgres:16`/`eclipse-mosquitto:2`, healthcheck และ init script ภายใน container
- Android emulator/มือถือจริง (ต้องทำ APP-0 เรื่อง cleartext HTTP), Windows desktop build
- Home Gateway/LoRa/อุปกรณ์จริง, การรันต่อเนื่องนาน, ปริมาณข้อมูลมาก, MQTT reconnect เมื่อ broker restart

### ข้อจำกัดที่รู้แล้ว
- MQTT เปิด anonymous (เฉพาะ dev) ต้องทำ BE-3 ก่อนเปิดให้เครื่องอื่นเข้าถึง
- อุปกรณ์ถูกลงทะเบียนอัตโนมัติ ยังไม่มี Farm/Plot (S3)
- ดีไซน์ยังไม่ตรง Kaset App (รอภาพอ้างอิง งาน UI-1)
