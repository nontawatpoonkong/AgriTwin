# Changelog

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
