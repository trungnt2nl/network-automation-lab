# 02 - Cấu hình nền trên thiết bị: SSH và SNMP

Mọi công cụ trong project cần hai đường vào thiết bị: **SSH** (quản trị, lấy cấu hình: Oxidized, Ansible) và **SNMP** (giám sát: LibreNMS). Thiết bị chỉ được thêm vào công cụ sau khi cả hai đường này đã kiểm tra thủ công từ máy NMS.

## Đặt IP quản trị

SW1 (switch L2, IP trên SVI):

```
interface vlan 1
 ip address 192.168.141.61 255.255.255.0
 no shutdown
ip default-gateway 192.168.141.2
no ip domain-lookup
```

R1 (R2 tương tự, IP `.63`):

```
interface ethernet 0/0
 ip address 192.168.141.62 255.255.255.0
 no shutdown
ip route 0.0.0.0 0.0.0.0 192.168.141.2
no ip domain-lookup
```

## SSH

```
ip domain-name lab.local
username admin privilege 15 secret <MAT_KHAU>
crypto key generate rsa modulus 2048
ip ssh version 2
line vty 0 4
 login local
 transport input ssh
 exec-timeout 10 0
```

- `ip domain-name` bắt buộc để Cisco tạo khóa RSA.
- `transport input ssh` chỉ cho SSH và chặn Telnet (Telnet gửi mật khẩu không mã hóa).
- `secret` lưu mật khẩu dạng băm.
- **Lưu ý:** lab này dùng tài khoản `admin` cho cả người, Oxidized và Ansible. Tài liệu hướng dẫn ban đầu đề xuất tài khoản riêng `automation`, nhưng thực tế lab chạy với `admin`. Hạn chế: log thiết bị (`Last configuration change ... by admin`) không phân biệt người và máy. Xem phần cải tiến trong [README gốc](../README.md).

## SNMP (chỉ đọc, giới hạn theo máy NMS)

```
ip access-list standard NMS-ONLY
 permit host 192.168.141.131
snmp-server community <SNMP_COMMUNITY> RO NMS-ONLY
snmp-server location EVE-LAB
snmp-server contact netadmin@lab.local
```

- `RO` (read-only): LibreNMS chỉ đọc được, không sửa được thiết bị.
- ACL `NMS-ONLY` chỉ cho phép máy NMS hỏi SNMP. Biết community mà từ máy khác vẫn không dùng được.
- Không dùng community đoán được như `public` hay `private`.
- SNMPv2c gửi community dạng văn bản thường. Môi trường thật dùng SNMPv3 (xác thực và mã hóa); lab dùng v2c cho đơn giản.

## Kiểm tra từ máy NMS

```
sudo apt install -y snmp
ping -c 2 192.168.141.61
ssh admin@192.168.141.61
snmpwalk -v2c -c <SNMP_COMMUNITY> 192.168.141.61 1.3.6.1.2.1.1.5
```

Kết quả `snmpwalk` (community đã che), xem [evidence/snmpwalk.txt](evidence/snmpwalk.txt):

```
iso.3.6.1.2.1.1.5.0 = STRING: "SW1.lab.local"
iso.3.6.1.2.1.1.5.0 = STRING: "R1.lab.local"
iso.3.6.1.2.1.1.5.0 = STRING: "R2.lab.local"
```

`sysName` có dạng `SW1.lab.local` vì thiết bị tự nối `ip domain-name` vào hostname. Đây là hành vi bình thường.

## Bằng chứng

- [x] `evidence/snmpwalk.txt`: SNMP trả về hostname cả 3 thiết bị
- [ ] Ảnh `ping` từ NMS tới 3 thiết bị
- [ ] Ảnh SSH vào thiết bị (che mật khẩu), hiện banner nếu đã chạy playbook
- [ ] Ảnh cấu hình SNMP/SSH trên thiết bị (che community và hash mật khẩu)
