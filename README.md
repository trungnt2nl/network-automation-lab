# Network Automation, Monitoring & Configuration Backup Lab

Lab tự động hóa vận hành mạng: **LibreNMS** giám sát thiết bị và cổng qua SNMP, **Oxidized** sao lưu cấu hình qua SSH và lưu phiên bản bằng Git, **Ansible** chuẩn hóa cấu hình hàng loạt. Ba công cụ nối thành một vòng: Ansible thay đổi cấu hình, Oxidized ghi lại từng thay đổi (có diff), LibreNMS cho biết thiết bị còn sống không và hiển thị cấu hình/lịch sử.

> Môi trường: VMware Workstation trên Windows host. Ubuntu Server VM chạy Docker (LibreNMS, Oxidized) và Ansible. Thiết bị mạng: Cisco IOL (1 switch L2, 2 router) trong EVE-NG.

## Mục tiêu

- Triển khai LibreNMS và Oxidized bằng Docker Compose, giám sát trạng thái thiết bị và cổng bằng SNMP.
- Tự động sao lưu cấu hình theo lịch, lưu từng phiên bản trong Git và xem được thay đổi (diff).
- Viết playbook Ansible chuẩn hóa cấu hình nền cho nhiều thiết bị cùng lúc, chạy lặp lại không gây thay đổi thừa (idempotent).
- Kết hợp giám sát và quản lý phiên bản cấu hình để phát hiện, truy vết và khôi phục khi cấu hình bị sửa lệch chuẩn.

## Sơ đồ

```
        [ NMS - Ubuntu Server ]  192.168.141.131
        LibreNMS :8000 | Oxidized :8888 | Ansible
                    |
          VMware NAT 192.168.141.0/24 (gateway .2)
                    |
        [ EVE-NG, Cloud0 (pnet0) ]
                    |
                  [ SW1 ] 192.168.141.61
                  /      \
          e0/1  /          \  e0/2
              [ R1 ]      [ R2 ]
        192.168.141.62   192.168.141.63
```

Chi tiết và sơ đồ Mermaid: [01-topology/topology.md](01-topology/topology.md).

## Công nghệ

LibreNMS, MariaDB 10.11, Redis 7, Oxidized, Ansible (collection `cisco.ios`, `ansible.netcommon`), Git, Docker Compose, SNMPv2c, SSH, EVE-NG, Cisco IOL.

## Luồng hoạt động

1. LibreNMS (container `dispatcher`) hỏi SNMP từng thiết bị theo chu kỳ để lấy trạng thái thiết bị, cổng, băng thông. Không phản hồi thì thiết bị chuyển trạng thái Down.
2. Oxidized đăng nhập SSH, chạy `show running-config` theo chu kỳ (hoặc khi được yêu cầu), so với bản trước và tạo commit Git nếu có thay đổi.
3. LibreNMS đọc cấu hình và lịch sử từ Oxidized, hiển thị ở tab **Config** của từng thiết bị.
4. Ansible đẩy cấu hình chuẩn lên cả nhóm thiết bị; thiết bị nào đã đúng chuẩn thì không bị đụng đến.

## Cấu trúc repo

```
.
├── 01-topology/             sơ đồ, quy hoạch IP
├── 02-device-baseline/      SSH, SNMP trên thiết bị Cisco
├── 03-librenms/             LibreNMS bằng Docker, thêm thiết bị, kiểm thử sự cố
├── 04-oxidized/             Oxidized, kho Git, tích hợp LibreNMS
├── 05-ansible/              inventory, vault, playbook chuẩn hóa
├── 06-change-tracking/      theo dõi thay đổi, phát hiện lệch và khôi phục
├── 07-troubleshooting/      lỗi gặp phải và cách xử lý
├── docker/                  compose.yml, .env.example, cấu hình Oxidized mẫu
├── ansible/                 ansible.cfg, inventory, group_vars, playbook
├── scripts/                 oxfetch.sh (ép Oxidized sao lưu và chờ commit mới)
└── interview-notes.md       câu hỏi ôn phỏng vấn
```

Mỗi thư mục giai đoạn có `README.md` (thiết kế, lệnh, kiểm tra) và `evidence/` (ảnh chụp, output).

## Kết quả đạt được

Ngày thực hiện: 27 đến 28/10/2026. Cột **Bằng chứng** ghi file trong repo; phần chưa có bằng chứng được đánh dấu ☐ và **không** tính là đã đạt.

| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| SSH vào SW1, R1, R2 từ máy NMS | Đạt | [02-device-baseline](02-device-baseline/README.md) |
| SNMP walk (`sysName`) cả 3 thiết bị | Đạt | `02-device-baseline/evidence/snmpwalk.txt` |
| LibreNMS chạy bằng Docker, đăng nhập được, kiểm tra Validate | Đạt (đã sửa lỗi lệch múi giờ DB) | `07-troubleshooting/evidence/` |
| Thêm 3 thiết bị vào LibreNMS, nhận diện Cisco IOS, thấy cổng, location, contact | Đạt | `03-librenms/evidence/` |
| LibreNMS phát hiện sự cố: R2 chuyển Down, cổng `et0/2` của SW1 khi tắt | Đạt | `03-librenms/evidence/` |
| Alert rule và cảnh báo hiện trong menu Alerts | ☐ Chưa có bằng chứng | |
| Oxidized sao lưu cấu hình cả 3 thiết bị vào Git | Đạt | `04-oxidized/evidence/` |
| Tích hợp Oxidized vào LibreNMS (tab Config) | Đạt (đã kiểm tra trên SW1) | `04-oxidized/evidence/librenms-config-tab-sw1.png` |
| Ansible kết nối cả 3 thiết bị, chạy `show ip interface brief` | Đạt | `05-ansible/evidence/` |
| Playbook chuẩn hóa: chạy lần 1 thay đổi, chạy lại `changed=0` ở cả 3 thiết bị | Đạt | `05-ansible/evidence/` |
| Oxidized ghi lại thay đổi do người và do Ansible tạo ra (diff trong Git) | Đạt | `06-change-tracking/evidence/` |
| Kịch bản lệch cấu hình trên R1 và khôi phục bằng Ansible | Đạt | `06-change-tracking/evidence/` |
| Kịch bản "tắt nhầm cổng, LibreNMS báo R1 Down, truy vết bằng Git" đầy đủ | ☐ Chưa có bằng chứng | |
| Terraform (tùy chọn) | ☐ Chưa thực hiện | |

### Phạm vi khôi phục cấu hình

"Khôi phục" ở đây nghĩa là: dùng diff trong Git để xác định dòng nào đổi, rồi đưa thiết bị về chuẩn bằng playbook Ansible hoặc lệnh hoàn tác đúng dòng đó. Chưa thực hiện thay toàn bộ cấu hình từ một commit cũ (ví dụ `configure replace`).

## Bài học rút ra

Xem [07-troubleshooting](07-troubleshooting/README.md): lỗi xác thực Ansible do paramiko thử hết khóa SSH, lệnh `no ip domain lookup` hiển thị khác nhau giữa router và switch làm playbook không idempotent, lệch múi giờ giữa MariaDB và PHP trong LibreNMS, `sleep` cố định làm mất bằng chứng của Oxidized.

## Cải tiến dự kiến

- Dùng tài khoản riêng `automation` cho Ansible và Oxidized thay vì chung với `admin` (hiện log thay đổi không phân biệt người và máy).
- Nâng SNMPv2c lên SNMPv3 (xác thực và mã hóa).
- Cấu hình Alert Transport (email, Slack) và để Oxidized lấy danh sách thiết bị trực tiếp từ LibreNMS.
- Dùng Terraform (Docker provider) hoặc OpenTofu để triển khai stack giám sát.

## Lưu ý bảo mật

- Lab cô lập trong mạng ảo. SNMPv2c gửi community không mã hóa và `ssh: secure: false` của Oxidized **chỉ dùng cho lab**.
- Không đưa lên GitHub: `docker/.env`, `docker/oxidized/config`, kho Git `docker/oxidized/oxidized.git` (chứa cấu hình thật, community SNMP và hash mật khẩu), `ansible/group_vars/cisco/vault.yml`. `.gitignore` đã chặn các file này. Repo chỉ có file `.example`.
- Ảnh chụp và output đã thay community SNMP bằng `<SNMP_COMMUNITY>`. Trước khi đăng ảnh mới, che community, hash mật khẩu và mật khẩu.
- Địa chỉ IP trong repo là IP riêng (RFC 1918).
