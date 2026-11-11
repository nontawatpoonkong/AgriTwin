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
- [x] แก้ปัญหาที่พบหลัง UI-2 (11 พ.ย. 2569):
  - การ์ดแนวโน้มบน Dashboard อัปเดตตามรอบ poll: เมื่อ poll ได้ค่าที่ใหม่กว่าจุดล่าสุดของกราฟ จะดึงเฉพาะค่าหลังจุดนั้นมาต่อท้าย (ไม่โหลด 24 ชม. ใหม่) รอบที่ไม่มีค่าใหม่หรือ poll ล้มไม่ยิงคำขอ ถ้าดึงไม่สำเร็จจะเก็บกราฟเดิมไว้และบอกใต้กราฟ
  - ข้อความ error บนจอเหลือเหตุผลสั้น ๆ ภาษาไทย ส่วนรายละเอียดทางเทคนิคไปอยู่ใน log
  - แก้ AGENTS.md ข้อ 6 ที่ยังเขียนว่าค่าใน `tokens.dart` เป็นค่าชั่วคราว
  - ผล: `flutter analyze` 0 issue, `flutter test` 60 ข้อ และ test ใหม่ของการ์ดแนวโน้มทั้ง 3 ข้อ fail กับโค้ดเดิม ตรวจบน Android emulator ครบทั้ง Dashboard และหน้ากราฟ รวมปุ่ม "ลองใหม่" (ภาพใน `docs/evidence/ui-2/`)

## ปัญหาที่รู้แล้ว (พบตอนยืนยันบน Windows และ Android 9–10 พ.ย. 2569)

- **History API ยังไม่รวมข้อมูลเป็นช่วง (BE-1):** ส่งได้สูงสุด 5000 ค่าต่อครั้ง ถ้าข้อมูลถี่และขอช่วงยาวจะได้แค่ 5000 ค่าล่าสุด (`truncated: true`) เช่น simulator ที่ส่งทุก 10 วินาที 5000 ค่าคิดเป็นราว 14 ชั่วโมง ส่วนเซนเซอร์ที่ส่งทุก 60 วินาทีจะมีราว 10,080 ค่าใน 7 วัน ดูข้อเสนอ BE-6
- **กราฟย้อนหลัง (APP-1):** ช่วงเวลาคิดจากนาฬิกาของเครื่องที่เปิดแอป ถ้านาฬิกาเพี้ยนช่วงจะเลื่อนตาม, หน้ากราฟไม่ดึงข้อมูลใหม่เอง (ต้องกดรีเฟรชหรือสลับช่วง), และแกนเวลาเริ่มที่ค่าแรกถึงค่าสุดท้ายที่มีจริง ไม่ใช่ทั้งช่วงที่เลือก (ข้อความเหนือกราฟบอกช่วงจริงไว้) ถ้าข้อมูลถูกตัดที่ 5000 ค่าจะมีข้อความเตือนใต้กราฟ
- **History API ที่ไม่ระบุ `sensor_type`:** index `(device_id, sensor_type, measured_at)` ใช้ได้ไม่เต็มที่ เพราะต้องเรียงข้อมูลทุกชนิดของอุปกรณ์นั้น ตอนนี้ข้อมูลยังน้อยจึงไม่มีปัญหา ถ้าช้าให้พิจารณาเพิ่ม index `(device_id, measured_at)` ด้วย migration ใหม่
- **release build ยังเรียก `http://` ได้:** HTTP client ของ Dart ไม่ได้อ่านนโยบาย cleartext ของ Android ตอน deploy จริง (OPS-1) จึงต้องตั้ง `API_BASE_URL` เป็น `https://`
- **`localhost` ช้าบน Windows:** `localhost` resolve เป็น `::1` ก่อน แต่ uvicorn ฟังแค่ IPv4 โปรแกรมที่ไม่ใช่ browser (Python, PowerShell) จึงเสียเวลาราว 2 วินาทีต่อ connection ใหม่ ถ้าเรียกจากสคริปต์ให้ใช้ `http://127.0.0.1:8000` (Chrome ไม่มีปัญหานี้)
- **มือถือจริงต้องเปิด host ของ API:** uvicorn ค่าเริ่มต้นฟังแค่ `127.0.0.1` ถ้าจะทดสอบกับมือถือจริงใน LAN ต้องรันด้วย `--host 0.0.0.0` และเปิดพอร์ต 8000 ใน Windows Firewall (emulator ใช้ `10.0.2.2` ได้เลย) เขียนขั้นตอนไว้ใน README แล้ว
- **Docker เปิดพอร์ตบนทุก interface:** 1883 และ 5433 ผูกกับ `0.0.0.0` เครื่องอื่นใน LAN จึงส่งข้อความเข้า Mosquitto แบบ anonymous ได้จนกว่าจะทำ BE-3 (หรือผูกพอร์ตกับ `127.0.0.1` ใน compose ระหว่าง dev)
- **pytest warning:** Starlette 1.10 (dependency ทางอ้อมที่ไม่ได้ pin) เตือนว่าการใช้ `httpx` กับ `TestClient` เลิกแนะนำแล้ว ควรพิจารณา pin `starlette` หรือย้ายตามคำแนะนำก่อนที่ test จะพัง
- **UI-2 ต่างจาก Figma โดยตั้งใจ:** การ์ดแนวโน้มอยู่เหนือรายการเซนเซอร์ (ใน Figma อยู่ใต้) เพราะแอปแสดงทุกอุปกรณ์ ถ้าวางไว้ล่างจะถูกดันลงไปไกล, ป้าย "ข้อมูลจำลอง" อยู่ที่แต่ละอุปกรณ์แทน chip "DEMO DATA" ที่หัวข้อ เพราะแต่ละอุปกรณ์อาจมี source ต่างกัน, หน่วยลมเป็น m/s ตาม contract (Figma เขียน กม./ชม.), แกน y ใช้ค่าต่ำสุด/กลาง/สูงสุดของข้อมูลแทนเลขกลม และหน้ากราฟมีปุ่มย้อนกลับเพราะยังไม่มีแถบเมนูล่าง
- **การ์ดแนวโน้มบน Dashboard:** แสดงความชื้นดินของอุปกรณ์แรกที่มีค่านี้เท่านั้น (เลือกเองไม่ได้) ตอนนี้อัปเดตตามรอบ poll แล้ว (ดูหัวข้อสถานะ) แต่ค่าที่เก่ากว่า 24 ชม. จะถูกตัดออกเฉพาะตอนมีค่าใหม่เข้ามา ถ้าอุปกรณ์หยุดส่งนาน ๆ กราฟอาจยังแสดงค่าที่เก่ากว่า 24 ชม. จนกว่าจะดึงรีเฟรช
- **ปุ่ม "ลองใหม่" ไม่มีสถานะกำลังโหลด:** ถ้ากดตอนรอบ poll ยังรอคำตอบอยู่ ปุ่มจะไม่ทำอะไร (`DashboardController.refresh` ข้ามเมื่อกำลังโหลด) บน Windows + emulator การเชื่อมพอร์ตที่ปิดอยู่ใช้เวลาราว 2 วินาทีต่อครั้ง (4 วินาทีรวม retry) ช่วงนั้นจึงกดไม่ติดบ่อย ควรทำให้ปุ่มแสดงว่ากำลังลองอยู่
- **Dashboard ยัง poll ขณะเปิดหน้ากราฟทับอยู่:** หน้า Dashboard ยังอยู่ใน stack จึง poll ทุก 5 วินาที และการ์ดแนวโน้มดึงค่าใหม่ต่อ (คำขอเล็ก) เกี่ยวกับงาน APP-2
- **รายละเอียด error อยู่ใน log:** จอแสดงแค่เหตุผลสั้น ๆ ภาษาไทย ส่วนชนิดและข้อความของ exception, URL, รหัส HTTP และ `detail` จาก error ของ API อยู่ใน console ของ `flutter run` หรือ `adb logcat -s flutter` (บรรทัด `AgriTwinApi: GET ... failed: ...`) ก่อนเขียน log จะปิด `user:password@` ใน URL และค่าของ query ที่ชื่อดูเหมือนรหัส (token, key, secret, password, auth, sig) เป็น `***` แล้วตัดเหลือ 300 ตัวอักษร ส่วน body ที่ไม่ใช่ JSON error ของ API (เช่น หน้า proxy หรือหน้า login Wi-Fi) และข้อความต้นฉบับใน `FormatException` จะไม่ถูกคัดลอกลง log หน้า error ตอนเปิดแอปยังแสดงที่อยู่เซิร์ฟเวอร์ไว้หนึ่งบรรทัด เพื่อให้เห็นเมื่อตั้ง `API_BASE_URL` ผิด
- **file key ของ Figma อยู่ในประวัติ Git:** ลบออกจากคอมเมนต์ใน `tokens.dart` แล้ว แต่ commit `580c58d` ที่ push ไปแล้วยังมี key อยู่ และแก้ประวัติที่ push แล้วไม่ได้ ถ้าไฟล์ Figma เปิดให้ "ทุกคนที่มีลิงก์" ดูได้ ใครเห็น key ก็เปิดแบบได้ จึงควรตั้งสิทธิ์แชร์ให้เฉพาะคนที่เชิญ (เจ้าของโปรเจกต์เป็นคนตัดสินใจ)
- **`message_id` จาก `devEui` + `fCnt` อาจชนกัน:** `ARCHITECTURE.md` (แบบ B) เสนอแบบนี้ แต่ frame counter เริ่มนับใหม่หลัง rejoin หรือ reboot ค่าใหม่จะถูกทิ้งเป็น duplicate ควรใช้ id ของ uplink จาก network server หรือเติมส่วนที่เปลี่ยนทุก session (ดู `docs/GW-1_GATEWAY_PLAN.md` หัวข้อ 1)
- **กราฟจาก simulator ดูเป็นกลุ่มแท่ง:** ข้อมูล dev มีช่วงที่ simulator ไม่ได้รันหลายชั่วโมง กราฟจึงไม่ลากเส้นข้ามช่วงนั้น (ตั้งใจ ไม่ใช่บั๊ก)
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
  สถานะ (11 พ.ย. 2569): ยังไม่มีโฟลเดอร์ `docs/evidence/s1/` ใน repo
  - **ผลที่มีบันทึกเป็นข้อความ:** CHANGELOG และ NEXT_TASKS บันทึกไว้ว่า pytest ผ่าน 29 ข้อ, smoke test PASS และ V-1 ผ่าน
  - **ไฟล์ชั่วคราวในเครื่องที่ใช้พัฒนา (ไม่อยู่ใน repo):** output ของ pytest และ smoke test จากคืนวันที่ 9 พ.ย. (ระหว่าง commit `799f2c3` ถึง `b35e569` ไม่ใช่ tag `v0.1.0` พอดี) และภาพ emulator ของ Dashboard รุ่น S1 แต่ `ingest_counts` ในไฟล์นั้นเป็น 0 ทั้งหมด เพราะเก็บก่อนส่งข้อมูล
  - ควรสร้างหลักฐานใหม่ที่ tag `v0.1.0` ใน worktree แยก แล้วระบุ commit กับวันที่ในแต่ละไฟล์
- [x] **APP-0 Android: อนุญาต HTTP ในเครือข่ายท้องถิ่น**
  ทำ: เพิ่ม `android:usesCleartextTraffic="true"` ใน `android/app/src/main/AndroidManifest.xml` (เฉพาะช่วง dev) และตรวจว่ามี permission `INTERNET`
  เสร็จเมื่อ: Android emulator ใช้ `--dart-define=API_BASE_URL=http://10.0.2.2:8000` แล้วเห็นข้อมูล
  ผล (9 พ.ย. 2569): ใส่ `INTERNET` ใน `main/AndroidManifest.xml` และใส่ `usesCleartextTraffic` เฉพาะใน manifest ของ `debug`/`profile` (แทนการใส่ใน main) แล้วทดสอบบน emulator Android 17 (API 37) ครบ 4 แบบ: debug ทั้งก่อนและหลังแก้แสดงข้อมูลได้, release ก่อนแก้ขึ้น `SocketException: Operation not permitted` ส่วน release หลังแก้แสดงข้อมูลได้ สรุปว่าส่วนที่จำเป็นจริงคือ `INTERNET` เพราะ HTTP client ของ Dart ไม่ได้อ่านค่า cleartext ของ Android

## UI

- [ ] **UI-1 ปรับดีไซน์ตาม Kaset App** — *รอภาพหน้าจอ/สเปกจากเจ้าของโปรเจกต์ ห้ามเดาดีไซน์*
  ทำ: แก้ค่าใน `app/lib/core/theme/tokens.dart` (สี ระยะ มุมโค้ง ขนาดตัวอักษร), ฟอนต์ไทย และ layout ของ `DeviceCard`/`SensorTile` ให้ตรงภาพอ้างอิง
  เสร็จเมื่อ: เทียบ screenshot แบบ before/after กับภาพอ้างอิงแล้ว และ widget test เดิมยังผ่าน
  หมายเหตุ (10 พ.ย. 2569): ค่าใน `tokens.dart` ตอนนี้มาจาก Figma concept ของโปรเจกต์ (UI-2) ไม่ใช่ Kaset App ถ้าได้ภาพ Kaset App มา ให้เจ้าของโปรเจกต์ตัดสินก่อนว่าจะยึดแบบไหน
- [x] **UI-2 จัด Dashboard และหน้ากราฟตาม Figma** ไฟล์ "AgriTwin — Mobile UI Concept | Research Proposal" ของเจ้าของโปรเจกต์ (Screen 01 Home, Screen 04 Sensor และเฟรม Design Tokens)
  ผล (10 พ.ย. 2569): ย้ายค่าสี ตัวอักษร ระยะ และมุมโค้งจากเฟรม Design Tokens เข้า `tokens.dart` (ค่าที่ Figma ไม่มี เช่น สีสถานะ suspect และสีแถบ stale เขียนกำกับว่า derived) Dashboard มี header, คำทักทายตามเวลา, การ์ดสรุปสถานะอุปกรณ์ (ใช้แทนพยากรณ์อากาศ เพราะระบบยังไม่มีข้อมูลอากาศ), การ์ดแนวโน้มความชื้นดิน 24 ชม. และการ์ดเซนเซอร์แบบมีไอคอนแยกตามอุปกรณ์ หน้ากราฟเปลี่ยนเป็น "ข้อมูลเซนเซอร์" มีการ์ดสถานะอุปกรณ์/แหล่งข้อมูล, ตัวเลือก 24 ชม./7 วัน/30 วัน, การ์ดกราฟ และค่าล่าสุดที่แตะเพื่อสลับเซนเซอร์ ไม่เพิ่ม package และไม่เปลี่ยน API contract (ค่าล่าสุดในหน้ากราฟใช้ `GET /api/v1/devices/{id}/latest` ที่มีอยู่แล้ว) ป้าย "ข้อมูลจำลอง" อยู่ทุกจุดที่แสดงข้อมูลที่ไม่ใช่ `gateway` และไม่ถูกตัดคำ `flutter analyze` 0 issue, `flutter test` 51 ข้อ (เพิ่ม layout test จอ 320 และ 412 dp ที่ขนาดตัวอักษร 1.0/1.3 กับชื่ออุปกรณ์ภาษาไทยยาว) ตรวจบน Android emulator กับ API + simulator จริงแล้ว ทั้งตอนมีข้อมูล, stale, error + ลองใหม่, ไม่มีข้อมูล และอุปกรณ์ออฟไลน์ (หน้ากราฟเพิ่งได้ลองบน Android ครั้งแรกในงานนี้)
  ยังไม่ได้ทำเพราะยังไม่มีข้อมูลรองรับ: พยากรณ์อากาศ, ตัวเลือกฟาร์ม/แปลง, กระดิ่งแจ้งเตือน, ชื่อและรูปผู้ใช้, แบตเตอรี่/RSSI (GW-2) ส่วนการ์ด AI, แท็บ NPK และหน้า Twin อยู่นอกขอบเขต
- [ ] **UI-3 แถบเมนูล่าง 5 แท็บตาม Figma** (หน้าหลัก/แปลง/Twin/ข้อมูล/AI) ทำเมื่อมีหน้าให้ไปจริง ตอนนี้มีแค่หน้าหลักกับหน้าข้อมูลเซนเซอร์ (ซึ่งต้องเลือกอุปกรณ์ก่อน) แท็บ Twin และ AI อยู่นอกขอบเขต ส่วนแท็บแปลงต้องรอ BE-4
- [ ] **UI-4 หน้าฟาร์ม/แปลง (Screen 02) และตัวเลือกฟาร์ม/แปลง** บน Dashboard และหน้าข้อมูล (ต้องทำ BE-4 ก่อน) เมื่อมีแปลงจริงจึงเปลี่ยนชื่อหน้าเป็น "ข้อมูลแปลง" ตาม Figma
- [ ] **UI-5 ฟอนต์และไอคอนตาม Figma** ตอนนี้ใช้ฟอนต์ของระบบ (Android ใช้ Noto Sans Thai อยู่แล้ว แต่ตัวเลขไม่ใช่ Inter) และใช้ Material Icons แทน SVG ใน Figma ถ้าจะให้ตรงต้อง bundle ฟอนต์ (แอปใหญ่ขึ้น) และเพิ่ม `flutter_svg` หรือแปลงไอคอนเป็น icon font ต้องขออนุมัติตาม AGENTS.md ข้อ 9 ก่อน
- [ ] **UI-6 แถบช่วงค่าที่ผู้ใช้ตั้งบนกราฟ** ("ช่วงที่ผู้ใช้ตั้ง 40–60%" ใน Screen 04) ต้องมีที่เก็บค่าตั้งต่อแปลงหรือเซนเซอร์ฝั่ง backend ก่อน
- [x] **APP-1 กราฟย้อนหลัง** (ต้องทำ BE-1 ก่อน) แตะ SensorTile แล้วเปิดกราฟ 24 ชม./7 วัน มีสถานะ loading/empty/error ครบ และยังแสดงป้ายข้อมูลจำลอง
  ผล (10 พ.ย. 2569): วาดกราฟด้วย CustomPainter (ไม่เพิ่ม package) ใช้ธีมเดิมและ token ใน `tokens.dart` มี loading/empty/error/stale, ป้าย "ข้อมูลจำลอง", ข้อความเมื่อข้อมูลถูกตัด, เครื่องหมายค่าผิดปกติ และไม่ลากเส้นข้ามช่วงที่ข้อมูลหาย เพิ่ม test 15 ข้อ (flutter test รวม 29 ข้อ) และลองใน web build กับ API จริงแล้ว ยังไม่ได้ลองบน Android
- [ ] **APP-2 หยุด polling เมื่อแอปอยู่เบื้องหลัง** (`AppLifecycleListener`)

## Backend

- [x] **BE-1 History API** `GET /api/v1/devices/{id}/readings?sensor_type=&from=&to=&limit=` (limit สูงสุด 5000, เรียงตามเวลา) พร้อม test และอัปเดต DATA_CONTRACT.md
  ผล (10 พ.ย. 2569): `from` รวมขอบ `to` ไม่รวมขอบ, `limit` ค่าเริ่มต้น 1000 (1–5000), ข้อมูลเกิน limit ได้ค่าล่าสุดพร้อม `truncated`, 404/422 ตามเอกสาร มี test 21 ข้อ (pytest รวม 55 ข้อ) และ pytest จะหยุดเองถ้า `TEST_DATABASE_URL` ไม่ได้ชี้ไปที่ฐาน `*_test`
- [ ] **BE-2 Rejects API** `GET /api/v1/ingest/rejects?limit=50` สำหรับ debug ตอนต่อ Gateway จริง
- [ ] **BE-3 MQTT auth + ACL** ตั้ง Mosquitto ให้ใช้ `password_file` + `acl_file` โดย gateway publish ได้เฉพาะ `agritwin/+/devices/+/telemetry` และ backend subscribe ได้ ใส่ secret ใน `.env` เท่านั้น
- [ ] **BE-4 Farm / Plot / Device assignment** (S3) ทำ migration 0002 + CRUD + audit fields และผูก device กับ plot ตามช่วงเวลา
- [ ] **BE-5 ตาราง latest** เมื่อ `sensor_readings` มีมากกว่า ~1 ล้านแถว หรือ `/dashboard/latest` ช้ากว่า 200 ms
- [ ] **BE-6 รวมข้อมูลย้อนหลังเป็นช่วง** (ข้อเสนอจาก BE-1) เพิ่มพารามิเตอร์ เช่น `bucket=1h` ให้ History API ส่งค่าเฉลี่ย/ต่ำสุด/สูงสุดต่อช่วง เพื่อให้กราฟ 7 วันครอบคลุมทั้งช่วงแม้ข้อมูลเกิน 5000 ค่า และยังบอกได้ว่าแต่ละช่วงมีข้อมูลที่ไม่ใช่ `gateway` หรือไม่
- [ ] **BE-7 Gateway ที่มีสิทธิ์และการเพิ่ม Field Node** (เสนอจาก GW-1 ทำหลังเลือกเส้นทาง)
  - **กติกาของผลิตภัณฑ์:** เซิร์ฟเวอร์ต้องยืนยันว่า Gateway มีสิทธิ์ก่อนยอมให้เพิ่ม Field Node ใหม่
  - **สิ่งที่ต้องทำ:** ที่ลงทะเบียน Gateway, หยุดเพิ่มอุปกรณ์อัตโนมัติสำหรับข้อมูล `source: "gateway"` (simulator และ test ยังเพิ่มอัตโนมัติได้), migration ที่มี downgrade และ test
  - **ยังไม่ตัดสิน:** วิธีผูก node กับ Gateway และนิยามของ "มีสิทธิ์" ซึ่งขึ้นกับเส้นทาง ถ้าต้องใส่ตัวระบุ Gateway ใน topic หรือ payload ต้องทำตาม DATA_CONTRACT.md §6 (ดู `docs/GW-1_GATEWAY_PLAN.md` หัวข้อ 2)

## Gateway / IoT (ทำร่วมกับคนทำ Hardware)

- [ ] **GW-1 เลือกเส้นทาง Gateway** ระหว่างแบบ A (serial bridge) หรือ B (LoRaWAN + ChirpStack) ตาม `docs/ARCHITECTURE.md`
  เสร็จเมื่อ: มีสคริปต์ bridge/adapter ที่ publish contract v1 ด้วย `source: "gateway"`, เก็บคิวเมื่อ MQTT หลุดแล้วส่งซ้ำ และ smoke test ผ่านด้วยข้อมูลจริง 1 node
  ความคืบหน้า (11 พ.ย. 2569): เขียนแผนแล้วที่ `docs/GW-1_GATEWAY_PLAN.md` ยังไม่ได้เลือกเส้นทางและยังไม่มีผลวัดระยะ
  - **ในแผนมี:** สิ่งที่ backend รับได้ตอนนี้, ตารางเปรียบเทียบ serial LoRa กับ LoRaWAN, เกณฑ์ทดสอบ 500 ม.–1 กม. ตามแผนจัดซื้อ, checklist และคำถาม 12 ข้อสำหรับคนทำ Hardware
  - **สิ่งที่รออยู่:** คำตอบจากคนทำ Hardware
  - **เอกสารยังไม่ตรงกัน:** แผน Sprint S2 ใช้ serial bridge ส่วนแผนจัดซื้อให้ LoRaWAN เป็นหลัก
- [ ] **GW-2 Contract v1.1: link quality** เพิ่ม `link: {rssi, snr}` แบบไม่บังคับ เพื่อทดสอบระยะ 500 ม.–1 กม. ตามแผน (แผนจัดซื้อขอ data rate, frame counter, แรงดันแบตเตอรี่ และ `gateway_id` ด้วย ให้ตัดสินพร้อม BE-7)
- [ ] **GW-3 Device heartbeat topic** `agritwin/{env}/devices/{id}/status`
- [ ] **GW-4 adapter แบบไม่มีวิทยุ (dry run)** ทำหลังตกลงเส้นทางและรูปแบบ frame หรือ codec กับคนทำ Hardware
  - **ทำ:** อ่าน frame ตัวอย่างหรือ event ตัวอย่างจาก network server แล้วสร้าง contract v1 (`source: "gateway"`) publish เข้า broker ของเครื่องพัฒนา
  - **เสร็จเมื่อ:** test ครอบคลุม accepted, duplicate, rejected, คิวตอน MQTT หลุด, `message_id` ไม่ชนหลัง node reboot และ `ts` ไม่เปลี่ยนเมื่อส่งจากคิว โดยไม่เปลี่ยน API contract
  - **เรื่องเวลา:** ถ้า node ไม่ส่งเวลาที่วัดหรืออายุของค่า `ts` จะเป็นเวลาที่ Gateway รับ ซึ่งเป็นค่าประมาณ ต้องบันทึกไว้ (ดู `docs/GW-1_GATEWAY_PLAN.md` หัวข้อ "เวลาที่วัด กับ เวลาที่รับ")

## Ops

- [ ] **OPS-1 Deploy ขึ้น Home Server** เพิ่ม service `api` ใน docker-compose, `MQTT_ENV=prod`, ตั้ง backup PostgreSQL รายวัน และทดสอบ restore
- [ ] **OPS-2 Git workflow** ใช้ branch `feat/<task-id>-<สั้นๆ>` ต่องาน, merge เข้า `main` เมื่อ test ผ่าน และพิจารณาตั้ง repo เป็น private (ตอนนี้เป็น public)
