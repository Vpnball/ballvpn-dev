# ⚡ BallVPN NAT & SNAT Auto Setup Script

สคริปต์นี้สร้างขึ้นสำหรับระบบ **BallVPN**, **Looktow VPN**, และระบบ VPN ใด ๆ ที่ต้องการตั้งค่า NAT อัตโนมัติ
เหมาะกับ VPS Ubuntu (18.04 / 20.04 / 22.04)

---

## ✅ ฟังก์ชันหลัก
- คงกฎ `REDIRECT UDP 53 → 5300` แค่ 1 บรรทัด
- ล้าง DNAT เก่า `6000–19999 → 5667`
- ตั้ง DNAT ใหม่ `22000–28000 → :5667` (ไม่ระบุ IP)
- ตั้ง SNAT เฉพาะ `10.8.0.0/16 → IP ภายใน`
- ตรวจจับ interface (`ens3`, `eth0`, ฯลฯ) และ IP อัตโนมัติ
- บันทึกถาวร `/etc/iptables/rules.v4`

---

## ⚙️ วิธีใช้งาน (สั้นมาก)

> แทนที่ `<YOUR_GH_USER>` ด้วยชื่อผู้ใช้ GitHub ของคุณ เช่น `ballvpn-dev`

### curl
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ballvpn-dev/ballvpn-nat/refs/heads/main/ballvpn_nat.sh)"
```

### wget
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/ballvpn-dev/ballvpn-nat/refs/heads/main/ballvpn_nat.sh)"
```

---

## 🔍 ตรวจสอบผลลัพธ์
```bash
iptables -t nat -L PREROUTING -n -v | egrep 'dpt:53|dpts:22000:28000|dpts:6000:19999'
iptables -t nat -L POSTROUTING -n -v | grep '10\.8\.0\.0/16'
```

---

## 🧠 สำหรับนักพัฒนา
ต้องการเพิ่ม port หรือ subnet เพิ่มในอนาคต สามารถแก้ไขไฟล์ `ballvpn_nat.sh` ได้โดยตรง  
และ commit ใหม่ จะอัปเดตอัตโนมัติในคำสั่ง curl/wget ด้านบน

---

## 🇬🇧 English (Quick)
This script configures NAT rules for BallVPN / Looktow VPN on Ubuntu:
- Keep a single `REDIRECT UDP 53 → 5300`
- Remove any `DNAT 6000–19999 → 5667`
- Ensure single `DNAT 22000–28000 → :5667`
- Ensure single `SNAT 10.8.0.0/16 → IF internal IP`
- Save to `/etc/iptables/rules.v4`

### One-liner
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ballvpn-dev/ballvpn-nat/refs/heads/main/ballvpn_nat.sh)"
```

---

## 📜 License
MIT License © 2025 BallVPN / Looktow VPN
