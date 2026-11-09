# AgriTwin

**Vertical Slice 1 (v0.1.0)**


แพลตฟอร์มติดตามพื้นที่เกษตรหลายแปลงด้วย IoT (โครงการวิจัย RMUTI) — **ต้นแบบระหว่างพัฒนา ข้อมูลที่แสดงตอนนี้เป็นข้อมูลจำลอง**

Slice นี้พิสูจน์เส้นทางข้อมูลหลักตั้งแต่ต้นจนจบ:

```
simulator ──MQTT──▶ Mosquitto ──▶ FastAPI (ingest) ──▶ PostgreSQL ──REST──▶ Flutter Dashboard
```

| ทำแล้ว | ยังไม่ทำ (ดู `docs/NEXT_TASKS.md`) |
|---|---|
| Contract v1 (device ID, เวลา, ชนิดเซนเซอร์, ค่า, หน่วย, source) | Home Gateway จริง (LoRa) |
| ตรวจ schema, กันข้อมูลซ้ำ, กักข้อมูลผิดรูป, quality flag | กราฟย้อนหลัง, Farm/Plot |
| Dashboard ค่าล่าสุด + ป้าย "ข้อมูลจำลอง" + สถานะออนไลน์ | ดีไซน์ตาม Kaset App (รอภาพอ้างอิง) |
| Migration up/down, test, smoke test | MQTT auth, deploy Home Server |

ไม่อยู่ในรอบนี้: Camera/360, NPK, AI, 3D

## โครงสร้างโปรเจกต์

```
agritwin/
├─ README.md               ← ไฟล์นี้
├─ AGENTS.md               ← กติกาสำหรับ Codex / AI coding tools
├─ docs/
│  ├─ ARCHITECTURE.md      ← สถาปัตยกรรม เหตุผล และทางเลือกที่ตัดออก
│  ├─ DATA_CONTRACT.md     ← MQTT payload + REST API
│  └─ NEXT_TASKS.md        ← งานถัดไปแบบแบ่งย่อย
├─ contracts/              ← JSON Schema + ตัวอย่าง payload (ส่งให้ทีม Hardware)
├─ infra/                  ← docker-compose: PostgreSQL 16 + Mosquitto 2
├─ backend/                ← FastAPI + SQLAlchemy + Alembic + MQTT ingest
│  ├─ app/  contract.py  ingest.py  mqtt_worker.py  api.py  models.py  config.py  main.py
│  ├─ migrations/          ← Alembic
│  ├─ scripts/smoke_test.py
│  └─ tests/
├─ simulator/simulate.py   ← จำลอง Field Node/Gateway ส่ง MQTT
└─ app/                    ← Flutter (lib/, test/; platform folders สร้างด้วย flutter create)
```

## ติดตั้งบน Windows (ครั้งแรก)

| โปรแกรม | หมายเหตุ | ตรวจด้วย |
|---|---|---|
| Git | git-scm.com | `git --version` |
| Python 3.12 | python.org ติ๊ก "Add python.exe to PATH" | `py -3.12 --version` |
| Docker Desktop | ใช้ WSL 2 ต้องเปิด virtualization ใน BIOS และต้องใช้สิทธิ์ admin ตอนติดตั้ง | `docker compose version` |
| Flutter SDK (stable) | docs.flutter.dev → Windows และใช้ Chrome รันแบบ web ได้เลย (ถ้ารันแบบ Windows desktop ต้องมี Visual Studio + "Desktop development with C++") | `flutter doctor` |

ถ้า PowerShell ไม่ยอมให้ activate venv ให้รันครั้งเดียว: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## รันระบบทีละขั้น (PowerShell เปิด 4 หน้าต่าง ทุกหน้าต่างเริ่มที่โฟลเดอร์ `agritwin`)

**หน้าต่าง 1 — ฐานข้อมูลและ MQTT broker**
```powershell
copy infra\.env.example infra\.env                   # ครั้งแรก: แก้ POSTGRES_PASSWORD เป็นรหัสของคุณเอง
docker compose -f infra/docker-compose.yml up -d
docker compose -f infra/docker-compose.yml ps        # ต้องเห็น postgres (healthy) และ mosquitto
```

**หน้าต่าง 2 — Backend API**
```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
copy .env.example .env                                # แก้ change-me ใน DATABASE_URL/TEST_DATABASE_URL ให้ตรง infra\.env
alembic upgrade head                                  # สร้างตาราง
uvicorn app.main:app --reload --port 8000
```
เปิด http://localhost:8000/api/v1/health แล้วต้องเห็น `"database":"up","mqtt":"connected"` ส่วนเอกสาร API อยู่ที่ http://localhost:8000/docs

**หน้าต่าง 3 — Simulator**
```powershell
backend\.venv\Scripts\python simulator\simulate.py --devices 2 --interval 10
```

**หน้าต่าง 4 — Flutter**
```powershell
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```
Android emulator ใช้ `API_BASE_URL=http://10.0.2.2:8000` ส่วนมือถือจริงให้รัน uvicorn ด้วย `--host 0.0.0.0` (ค่าเริ่มต้นฟังแค่ `127.0.0.1`) แล้วใช้ IP ของ PC ในวง LAN และอนุญาตพอร์ต 8000 ใน Windows Firewall
HTTP client ของ Dart (`package:http`) ไม่ได้อ่านนโยบาย cleartext ของ Android จึงเรียก API แบบ `http://` ได้ทั้ง build แบบ debug และ release (ทดสอบบน emulator แล้ว) ส่วน `usesCleartextTraffic` ใน build แบบ debug/profile มีผลกับระบบเครือข่ายของ Android เอง เช่น WebView ดังนั้นตอนใช้งานจริงต้องตั้ง `API_BASE_URL` เป็น `https://` (ดู APP-0)

## ทดสอบทีละขั้น

| # | ทดสอบ | คำสั่ง | ผลที่ต้องได้ |
|---|---|---|---|
| 1 | Backend unit + integration + migration | `cd backend` → `pytest -v` | ผ่านทั้งหมด (integration test ใช้ฐาน `agritwin_test` และจะล้างข้อมูลในฐานนั้นทุกครั้ง) |
| 2 | End-to-end MQTT → DB → API | `cd backend` → `python scripts/smoke_test.py` (ต้องรัน API อยู่) | `PASS: value travelled ...` |
| 3 | ข้อมูลผิดรูปถูกกัก | `simulator\simulate.py --count 1 --bad` | `/api/v1/health` ค่า `rejected` เพิ่มขึ้น และ Dashboard ไม่เปลี่ยน |
| 4 | ข้อมูลซ้ำถูกข้าม | `simulator\simulate.py --count 1 --duplicate` | ค่า `duplicate` เพิ่มขึ้น |
| 5 | อุปกรณ์ offline | หยุด simulator แล้วรอ 3 นาที | การ์ดเปลี่ยนเป็น "ออฟไลน์" |
| 6 | API ล่ม | หยุด uvicorn | แอปยังแสดงค่าเดิมพร้อมแถบเตือน "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้" |
| 7 | Flutter | `cd app` → `flutter analyze` และ `flutter test` | ไม่มี issue และ test ผ่าน |

ดูข้อความที่ถูก reject ได้ด้วยคำสั่ง:
```powershell
docker compose -f infra/docker-compose.yml exec postgres psql -U agritwin -c "SELECT received_at, error FROM ingest_rejects ORDER BY id DESC LIMIT 10;"
```

## ปัญหาที่พบบ่อย

- **พอร์ต 5433 หรือ 1883 ถูกใช้อยู่**: แก้ฝั่งซ้ายของ `ports` ใน `infra/docker-compose.yml` และแก้ `DATABASE_URL`/`MQTT_PORT` ใน `backend/.env` ให้ตรงกัน
- **ไม่ใช้ Docker**: ติดตั้ง PostgreSQL 16 และ Mosquitto for Windows เอง สร้าง user/db `agritwin` และ `agritwin_test` แล้วแก้ `DATABASE_URL` เป็นพอร์ต 5432
- **`mqtt":"disconnected"`**: broker ไม่ทำงาน ให้ตรวจด้วย `docker compose -f infra/docker-compose.yml logs mosquitto`
- **ล้างข้อมูลทั้งหมด**: `docker compose -f infra/docker-compose.yml down -v` (ลบข้อมูลถาวร)

## ความปลอดภัยของ Git

- `infra/.env` และ `backend/.env` เก็บรหัสผ่านจริงและ**ไม่ถูก commit** (ดู `.gitignore`) ใน Git มีเฉพาะ `*.env.example` ที่ใช้ค่า `change-me`
- ก่อน commit ให้ตรวจด้วย `git status` ว่าไม่มีไฟล์ `.env` อยู่ในรายการ

## ทำงานต่อด้วย Codex / เครื่องมืออื่น

1. ให้เครื่องมืออ่าน `AGENTS.md` ก่อน (Codex อ่านไฟล์นี้อัตโนมัติ)
2. สั่งทีละงาน เช่น "ทำงาน BE-1 ตาม docs/NEXT_TASKS.md"
3. ให้รัน `pytest` และ `flutter test` ทุกครั้งก่อนบอกว่างานเสร็จ
