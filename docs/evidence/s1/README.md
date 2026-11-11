# หลักฐาน V-2: Vertical Slice 1

หลักฐานชุดนี้สร้างเมื่อ 11 พฤศจิกายน 2569 เวลา 21:00 น. (Asia/Bangkok) จาก detached worktree ที่ commit
`125d912d13467b154c50c41c65e8a743e3ebc9ec` (`docs: GW-1 gateway integration plan for the hardware teammate`)

## ขอบเขตและคำชี้แจง

- ข้อมูลบน Dashboard มาจาก `simulator` และ smoke test (`source: "test"`) ทั้งหมด ไม่ใช่ผลวัดจากแปลงจริง
- ยังไม่ได้เชื่อม Home Gateway, Field Node หรือ LoRa จริง และไม่มีผลทดสอบระยะ 500 ม.–1 กม.
- smoke test พิสูจน์เฉพาะ MQTT → FastAPI → PostgreSQL → REST API และจบที่ API ไม่ได้เปิด Flutter
- Flutter ถูกยืนยันแยกต่างหากด้วย `flutter analyze`, `flutter test` และ release web build ที่เรียก API ชุดเดียวกัน ภาพหน้าจอจึงเป็นหลักฐาน UI เพิ่มเติม ไม่ใช่ส่วนหนึ่งของ smoke test

## การแยกจากระบบพัฒนาเดิม

ตรวจโค้ดก่อนรันแล้วพบว่า integration tests จะ downgrade/upgrade และล้างทุกตารางในฐานที่ `TEST_DATABASE_URL` ชี้ไป
ส่วน smoke test จะเขียน `smoke-test-node` ลงฐานข้อมูล จึงใช้ทรัพยากรชั่วคราวดังนี้:

| ส่วน | ค่าที่ใช้ |
|---|---|
| PostgreSQL | container ชั่วคราวใน tmpfs, host `127.0.0.1:55433` |
| Demo database | `agritwin_v2_demo` |
| Test database | `agritwin_v2_test` (แยกจาก demo และลงท้าย `_test`) |
| Mosquitto | container ชั่วคราว, host `127.0.0.1:51883` |
| FastAPI | `127.0.0.1:18000`, topic environment `v2demo` |
| Flutter web | release build บน `127.0.0.1:18080` |

ไม่ได้อ่าน แก้ หรือล้างฐานพัฒนาเดิม และไม่ได้แก้ `.env`, firewall, shared Docker Compose หรือ service เดิม

## ผล

| รายการ | ผล |
|---|---|
| Backend `pytest -v` | 55 passed, 1 warning, 5.07 วินาที |
| Database guard | header ยืนยัน `agritwin_v2_test @ 127.0.0.1:55433`; migration down/up ผ่าน |
| Flutter analyze | No issues found |
| Flutter test | All tests passed, 65 test cases |
| Smoke test | PASS: value travelled MQTT → API → PostgreSQL → REST |
| Health หลังทดสอบ | database up, MQTT connected; accepted 16, duplicate 10, rejected 5, errors 0 |
| ข้อมูลใน demo DB | simulator 84 readings, test 2 readings, gateway 0 readings; Alembic `0001` |
| Dashboard | release web build แสดง 3/3 online และป้าย “ข้อมูลจำลอง” ชัดเจน |

warning เดียวของ pytest คือ `StarletteDeprecationWarning` เรื่อง `httpx` กับ `TestClient` ซึ่งเป็น known issue ใน
`docs/NEXT_TASKS.md`; ไม่ได้ปิดบังหรือแก้ dependency ในงานหลักฐานนี้

## ไฟล์หลักฐาน

- `pytest-2026-11-11.txt` — output เต็มของ backend tests
- `flutter-2026-11-11.txt` — output ของ analyze และ test
- `smoke-test-2026-11-11.txt` — smoke test, simulator และขอบเขตว่าจบที่ REST API
- `health-2026-11-11.json` — `/api/v1/health` หลังทดสอบ
- `environment-2026-11-11.txt` — commit, เวลา, เวอร์ชัน และ isolated bindings
- `dashboard-simulated-2026-11-11.png` — Dashboard จาก release web build

เพื่อไม่เผยชื่อบัญชีผู้ใช้และ absolute path เฉพาะเครื่อง ไฟล์ output แทนเฉพาะ prefix ดังกล่าวด้วย
`<worktree>` และ `<project-venv>` โดยไม่ตัดชื่อ test, warning, ผลลัพธ์ หรือ summary ออก

คู่มือสาธิตและ fallback อยู่ที่ `docs/DEMO_RUNBOOK.md`
