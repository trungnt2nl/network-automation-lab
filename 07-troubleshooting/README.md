# Troubleshooting

Mỗi lỗi: triệu chứng, kiểm tra, nguyên nhân, cách sửa, bài học. Ảnh và output lưu trong `evidence/`.

---

## 1. LibreNMS Validate báo lệch giờ giữa MySQL và PHP
- **Triệu chứng:** trang Validate hiện dòng đỏ `FAIL: Time between this server and the mysql database is off` với `Mysql time 14:41:21` và `PHP time 21:41:21` (lệch đúng 7 giờ).
- **Nguyên nhân:** container `librenms` đặt `TZ=Asia/Ho_Chi_Minh` (UTC+7) nhưng container `db` (MariaDB) không có `TZ` nên chạy UTC.
- **Cách sửa:** thêm `TZ: ${TZ}` vào `environment` của service `db` trong `compose.yml`, rồi `docker compose up -d` (chỉ tạo lại `db`, dữ liệu nằm trong volume nên không mất). Kiểm tra `docker exec librenms-db date`.
- **Bài học:** mọi thành phần của một hệ thống giám sát phải thống nhất múi giờ, nếu không dấu thời gian của số liệu, cảnh báo và log sẽ lệch.
- **Bằng chứng:** `evidence/librenms-validate-time-mismatch.png`

## 2. Ansible báo lỗi xác thực: transport shut down or saw EOF
- **Triệu chứng:** `ansible ... ios_command` thất bại giống hệt trên cả 3 thiết bị, dù `ssh` thủ công và mật khẩu đều đúng.
- **Các giả thuyết đã loại bỏ:**
  1. Mật khẩu sai: truyền thẳng mật khẩu bằng `-e` vẫn lỗi.
  2. Thuật toán SSH cũ không tương thích: script paramiko riêng đăng nhập được (`diffie-hellman-group-exchange-sha1`, `ssh-rsa`, `aes128-cbc`).
- **Chẩn đoán:** viết script paramiko thử 3 tổ hợp tùy chọn. Kết quả:

  | Trường hợp | Kết quả |
  |---|---|
  | A: không thử khóa SSH, không dùng agent | `LOGIN OK` |
  | B: có thử khóa, không dùng agent | `EOF` |
  | C: có thử khóa, có dùng agent | `EOF` |

- **Nguyên nhân:** máy NMS có khóa SSH sẵn. Mặc định Ansible (paramiko) thử từng khóa trước khi tới mật khẩu. Cisco IOS giới hạn số lần xác thực sai (mặc định 3) và cắt kết nối khi vượt, nên mật khẩu đúng cũng không kịp được thử.
- **Cách sửa:** thêm vào `ansible.cfg`:
  ```ini
  [paramiko_connection]
  look_for_keys = False
  ```
  Truyền biến `-e ansible_paramiko_look_for_keys=false` trên dòng lệnh **không** có tác dụng trong lab này, chỉ đặt trong `ansible.cfg` mới được.
- **Bài học:** lỗi "xác thực thất bại" không phải lúc nào cũng là sai mật khẩu. Tách riêng bằng một script nhỏ, đổi từng tùy chọn một để tái hiện lỗi ngoài công cụ, thay vì đoán.
- **Bằng chứng:** `evidence/ansible-paramiko-tests.txt`

## 3. Ansible bị từ chối vì tài khoản không tồn tại
- **Triệu chứng:** vẫn lỗi xác thực sau khi mật khẩu đã đúng.
- **Kiểm tra:** `show running-config | include ^username` trên SW1 chỉ thấy `username admin`; `grep '^username' docker/oxidized/config` cũng là `admin`.
- **Nguyên nhân:** hướng dẫn ban đầu dùng tài khoản `automation` nhưng thiết bị chỉ có `admin` (Oxidized cũng đang đăng nhập bằng `admin`).
- **Cách sửa:** đặt `ansible_user: admin` trong `group_vars/cisco/vars.yml`.
- **Bài học:** thống nhất tài khoản giữa các công cụ và kiểm tra trên thiết bị thay vì giả định. Hướng cải tiến: tạo tài khoản `automation` bằng chính playbook rồi chuyển cả Ansible lẫn Oxidized sang tài khoản đó.

## 4. Playbook không idempotent trên router: `changed=1` mỗi lần chạy
- **Triệu chứng:** SW1 `changed=0` nhưng R1 và R2 `changed=1` ở task đầu, kèm cảnh báo `To ensure idempotency and correct diff the input configuration lines should be similar to how they appear ... in the running configuration`.
- **Kiểm tra:** `show running-config | include domain`:
  - SW1: `no ip domain-lookup`
  - R1: `no ip domain lookup`
- **Nguyên nhân:** router nhận lệnh `no ip domain-lookup` nhưng lưu thành `no ip domain lookup`. Ansible so sánh **chuỗi chữ** với running-config nên nhìn router thấy "chưa có" và gửi lại mỗi lần.
- **Cách sửa:** biến theo nhóm `no_domain_lookup_line` (`group_vars/switches.yml` dùng dấu gạch, `group_vars/routers.yml` dùng dấu cách).
- **Bài học:** viết lệnh đúng dạng thiết bị hiển thị; dùng `--check --diff` để thấy dòng nào bị gửi lại.

## 5. `Attempting to decrypt but no vault secrets found` và lỗi bị giấu
- **Triệu chứng:** thử truyền mật khẩu bằng `-e` để bỏ qua vault, lệnh không in gì; thêm `--ask-vault-pass` mới chạy.
- **Nguyên nhân:** Ansible luôn nạp `group_vars/cisco/vault.yml` đã mã hóa nên luôn cần vault password. Việc không in ra gì do thêm `2>/dev/null`, Ansible in lỗi ra stderr nên bị che hết.
- **Bài học:** không chuyển hướng `2>/dev/null` khi đang chẩn đoán. Lỗi quan trọng thường nằm ở stderr.

## 6. Oxidized chưa kịp sao lưu: mất bằng chứng cấu hình lệch
- **Triệu chứng:** sau `curl .../node/next/R1` và `sleep 15`, `git diff` trống; Ansible lại khôi phục R1 ngay sau đó nên trạng thái lệch không được ghi vào Git.
- **Nguyên nhân:** `node/next` chỉ xếp thiết bị lên đầu hàng đợi; Oxidized xử lý sau một lúc, không cố định. `sleep` cố định đôi khi không đủ.
- **Cách sửa:** script `scripts/oxfetch.sh` chờ đến khi Git thực sự có commit mới (tối đa 2 phút). Làm lại kịch bản và ghi nhận được hai commit lệch/khôi phục.
- **Bài học:** chờ theo điều kiện thay vì theo thời gian.

## 7. Cổng bị `shutdown` nhưng LibreNMS không đỏ
- **Triệu chứng:** sau khi tắt `e0/2` trên SW1, bảng cổng ghi `Up 5, Down 0` và `et0/2` màu xám.
- **Giải thích:** `shutdown` là tắt chủ động (`ifAdminStatus = down`), LibreNMS coi là có chủ ý. Cổng xuống ngoài ý muốn (`ifOperStatus = down` với `ifAdminStatus = up`) mới hiện đỏ. Chi tiết trong [03-librenms](../03-librenms/README.md#admin-down-khác-oper-down).

## 8. Container ELK của Project 2 còn chạy trên cùng máy
- **Triệu chứng:** máy Ubuntu có sẵn mạng Docker và container cũ từ Project 2 (`br-...`).
- **Xử lý:** dừng container cũ (`docker stop $(docker ps -q)`) trước khi cài LibreNMS để nhường RAM; không xóa volume nên dữ liệu ELK vẫn còn.
- **Bài học:** kiểm tra tài nguyên (`free -h`, `df -h`) trước khi triển khai thêm dịch vụ.
