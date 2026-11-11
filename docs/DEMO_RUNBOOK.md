# AgriTwin — คู่มือเดโมสั้น

ชุดหลักฐานและขั้นตอนนี้อ้างอิงโค้ดที่ทดสอบจาก commit
`125d912d13467b154c50c41c65e8a743e3ebc9ec`

## ขอบเขตที่ต้องพูดก่อนเริ่ม

> เดโมนี้ใช้ข้อมูลจาก simulator เพื่อพิสูจน์เส้นทาง MQTT → FastAPI → PostgreSQL → Flutter
> ทุกค่าที่เห็นเป็นข้อมูลจำลอง ไม่ใช่ผลวัดจากแปลงจริง และยังไม่ได้ทดสอบ Home Gateway, LoRa หรือระยะ 500 ม.–1 กม.

## เตรียมระบบอย่างปลอดภัย

1. ใช้ฐาน demo แยกจากฐานพัฒนาและฐาน test แยกอีกฐานหนึ่ง ห้ามรัน pytest กับฐาน demo หรือฐานพัฒนา
2. สำหรับเดโม Chrome บนเครื่องเดียว ให้ bind PostgreSQL, MQTT, API และ Flutter ที่ `127.0.0.1` เท่านั้น
3. Mosquitto ปัจจุบันเป็น anonymous สำหรับพัฒนา จึงห้ามเปิดพอร์ต 1883 ออก LAN ระหว่างเดโม
4. ถ้าจำเป็นต้องใช้มือถือจริงบน LAN ให้จำกัด Windows Firewall เฉพาะอุปกรณ์/เครือข่ายที่ต้องใช้ และทำ BE-3
   (MQTT password + ACL) ก่อนอ้างว่าเป็นเส้นทาง Gateway จริง ห้ามเปลี่ยน firewall หรือ shared config ระหว่างเดโมโดยไม่ประเมินผลกระทบก่อน

ชุดหลักฐาน V-2 ใช้พอร์ตแยก: PostgreSQL `55433`, MQTT `51883`, API `18000`, Flutter `18080`
โดยทุกพอร์ต bind เฉพาะ loopback และใช้ฐาน `agritwin_v2_demo` / `agritwin_v2_test`

## Startup และ preflight

1. เปิด PostgreSQL และ Mosquitto ที่แยกไว้ แล้วตรวจว่า PostgreSQL healthy และ host binding เป็น `127.0.0.1`
2. ตั้ง `DATABASE_URL`, `MQTT_HOST`, `MQTT_PORT` และ `MQTT_ENV` ใน process ของ FastAPI โดยไม่แก้ `.env`
3. รัน migration กับฐาน demo แล้วเปิด API บนพอร์ตที่เลือก
4. เปิด `/api/v1/health` ต้องเห็น `database: "up"`, `mqtt: "connected"`, `errors: 0`
5. รัน simulator แบบจำกัดจำนวนรอบ เช่น:

   ```powershell
   backend\.venv\Scripts\python simulator\simulate.py --host 127.0.0.1 --port 51883 --env v2demo --devices 2 --count 5
   ```

6. เปิด Flutter ด้วย `API_BASE_URL` ของ API ชุดเดียวกัน แล้วรอให้ Dashboard แสดงอุปกรณ์และป้าย “ข้อมูลจำลอง”

## ลำดับเดโม 3–5 นาที

1. แสดง `/health` และชี้ว่า database/MQTT connected
2. รัน simulator หนึ่งรอบ แล้วชี้ output topic และ `source: simulator`
3. แสดง Dashboard: ค่าเซนเซอร์, online/offline, ป้าย “ข้อมูลจำลอง” และเวลาอัปเดต
4. เปิดกราฟ 24 ชม./7 วัน/30 วัน และชี้ว่าช่วงไม่มีข้อมูลจะไม่ถูกลากเส้นเชื่อม
5. ถ้าต้องแสดง validation ให้ใช้ `--bad --duplicate` แล้วดู `accepted/duplicate/rejected` ใน `/health`
6. ย้ำว่า smoke test จบที่ REST API; Flutter ได้รับการตรวจแยกด้วย tests และภาพหน้าจอ

## Offline fallback

ถ้า live stack ล้ม ห้ามเดาผลหรือเปลี่ยนไปอ้างว่าเป็นข้อมูลจริง:

1. เปิด `docs/evidence/s1/dashboard-simulated-2026-11-11.png`
2. เปิด `docs/evidence/s1/health-2026-11-11.json` และ `smoke-test-2026-11-11.txt`
3. ใช้ `docs/evidence/ui-2/app-states-2026-11-11.png` อธิบาย loading/error/stale/retry
4. บอกผู้ชมตรง ๆ ว่านี่คือหลักฐานบันทึกจาก commit ที่ระบุ ไม่ใช่ live measurement
5. ถ้ามีวิดีโอ ให้เก็บไว้ข้างหลักฐานพร้อมชื่อ commit และวันที่; ชุด V-2 นี้ยังไม่มีวิดีโอ

## จบเดโม

- หยุดเฉพาะ API, Flutter และ container ชั่วคราวของเดโม
- อย่ารัน `docker compose down -v` กับ shared project และอย่าล้างฐานพัฒนา
- เก็บ health, logs, screenshot และ commit ที่ใช้ไว้ใน `docs/evidence/s1/`
