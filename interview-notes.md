# Ôn phỏng vấn - Network Automation, Monitoring & Config Backup

Gợi ý trả lời ngắn, dùng ví dụ từ chính lab này. Chỉ nhận những gì bạn đã làm và có bằng chứng.

## Tóm tắt 30 giây

"Em dựng một lab gồm LibreNMS giám sát thiết bị Cisco bằng SNMP, Oxidized tự động sao lưu cấu hình vào Git, và Ansible chuẩn hóa cấu hình hàng loạt. Khi cấu hình bị sửa tay lệch chuẩn, Oxidized ghi lại diff, em dùng playbook Ansible đưa thiết bị về chuẩn và Oxidized ghi lại bản khôi phục. Em tự khoanh vùng lỗi Ansible không xác thực được trên thiết bị Cisco bằng cách tái hiện lỗi ngoài công cụ."

## SNMP và giám sát

**1. SNMPv1, v2c, v3 khác nhau thế nào?**
v1 và v2c xác thực bằng chuỗi community gửi không mã hóa (v2c thêm bộ đếm 64 bit và `GetBulk`). v3 có xác thực người dùng, mã hóa và kiểm tra toàn vẹn. Lab dùng v2c cho đơn giản, nên em giới hạn bằng quyền `RO` và ACL chỉ cho máy NMS; môi trường thật dùng v3.

**2. Polling khác trap thế nào?**
Polling: NMS chủ động hỏi theo chu kỳ (LibreNMS mặc định 5 phút), dễ kiểm soát nhưng có độ trễ. Trap: thiết bị chủ động báo khi có sự kiện, nhanh hơn nhưng có thể mất vì dùng UDP. Lab này dùng polling.

**3. LibreNMS phát hiện thiết bị Down như thế nào?**
Bằng ICMP ping và SNMP. Khi em tắt cổng nối R2, R2 không ping và không trả lời SNMP nữa nên chuyển Down.

**4. Admin down khác oper down?**
`ifAdminStatus` là trạng thái quản trị muốn (tắt bằng `shutdown`); `ifOperStatus` là trạng thái thực tế. Cổng tắt bằng `shutdown` là admin down nên LibreNMS không coi là lỗi; cổng mất tín hiệu mới là oper down và hiện đỏ.

**5. Vì sao giới hạn SNMP bằng ACL và chỉ cho `RO`?**
Community giống mật khẩu gửi không mã hóa. `RO` ngăn ai đó sửa thiết bị, ACL giới hạn nguồn hỏi để lộ community vẫn khó khai thác.

**6. Vì sao LibreNMS cần cả MariaDB và Redis?**
MariaDB lưu dữ liệu bền vững (thiết bị, cổng, luật cảnh báo, sự kiện). Redis là bộ nhớ tạm trên RAM cho cache, session và điều phối giữa các tiến trình polling; mất Redis chỉ phải tạo lại cache. Số liệu biểu đồ nằm ở file RRD.

## Sao lưu cấu hình

**7. Vì sao phải sao lưu cấu hình thiết bị mạng?**
Thiết bị hỏng hoặc bị sửa nhầm thì phải dựng lại nhanh. Có lịch sử còn biết thay đổi nào gây sự cố, lúc nào.

**8. Oxidized hoạt động thế nào?**
Đọc danh sách thiết bị (`router.db`), SSH vào, chạy `show running-config`, so với bản trước và commit vào Git nếu có thay đổi. Chạy theo chu kỳ (`interval`), có REST API để ép sao lưu.

**9. Vì sao lưu bằng Git?**
Mỗi thay đổi là một commit có thời gian và nội dung; `git diff` cho biết chính xác dòng nào đổi; có thể so sánh với bản tốt đã biết.

**10. Rủi ro bảo mật của bản sao lưu?**
Chứa community SNMP, hash mật khẩu. Vì vậy kho Git không đưa lên GitHub, dùng `.gitignore`, che thông tin trong ảnh.

## Ansible

**11. Ansible khác script thường thế nào?**
Agentless (SSH, không cài gì lên thiết bị), khai báo trạng thái mong muốn, có inventory để thao tác theo nhóm, và idempotent.

**12. Idempotent là gì? Em chứng minh thế nào?**
Chạy nhiều lần cho cùng kết quả, không thay đổi thừa. Em chạy playbook lần đầu `changed=2`, chạy lại `changed=0` trên cả 3 thiết bị. Ban đầu router còn `changed=1` do lệnh `no ip domain lookup` hiển thị khác switch; em sửa bằng biến theo nhóm.

**13. `--check --diff` để làm gì?**
Mô phỏng và hiện dòng sẽ thêm mà không đụng thiết bị. An toàn khi chạy lên thiết bị thật; cũng giúp em tìm dòng gây `changed` liên tục.

**14. Ansible Vault để làm gì?**
Mã hóa mật khẩu trong file biến (AES256) để không lưu mật khẩu dạng rõ trong repo. Vault password không bao giờ commit.

**15. `network_cli` là gì?**
Kiểu kết nối cho thiết bị mạng: Ansible mở SSH và gõ lệnh CLI. Cần `ansible_network_os` để chọn module đúng (ở đây `cisco.ios.ios`).

**16. Inventory và group_vars dùng để làm gì?**
Inventory chia thiết bị theo nhóm (`switches`, `routers`); `group_vars` gán biến theo nhóm. Em dùng nó để cùng một playbook chạy cho cả switch lẫn router dù cú pháp hiển thị khác nhau.

## Tình huống và khoanh vùng lỗi

**17. Kể một sự cố em đã gặp.**
Ansible báo `Failed to authenticate: transport shut down or saw EOF` trên cả 3 thiết bị dù mật khẩu đúng. Em loại dần: truyền mật khẩu trực tiếp vẫn lỗi; script paramiko đăng nhập được nên không phải thuật toán SSH. Em viết script thử 3 tổ hợp tùy chọn và tái hiện lỗi khi bật thử khóa SSH. Nguyên nhân: máy có khóa SSH, paramiko thử từng khóa, Cisco giới hạn số lần xác thực và cắt kết nối. Em đặt `look_for_keys = False` trong `ansible.cfg`.

**18. Kể kịch bản lệch cấu hình.**
Em sửa tay R1 (bỏ `logging buffered`, đổi banner). Oxidized tạo commit ghi lại diff. Em chạy lại playbook: chỉ R1 `changed=2`, hai thiết bị kia `changed=0`. Oxidized ghi bản khôi phục sau 1 phút. Sau đó chạy lại thì `changed=0`.

**19. Em thấy hạn chế gì của lab?**
- Người và Ansible cùng dùng tài khoản `admin`, nên log không phân biệt (cải tiến: tài khoản `automation`).
- SNMPv2c, chưa v3.
- Chưa cấu hình kênh gửi cảnh báo (email, Slack) và chưa có bằng chứng cho alert rule.
- Khôi phục theo từng dòng, chưa thay toàn bộ cấu hình từ commit cũ.
- Oxidized chạy mỗi giờ nên có độ trễ phát hiện.

## Terraform (nếu được hỏi)

Chưa dùng trong project. Nếu được hỏi: Terraform dựng hạ tầng (tạo, xóa tài nguyên, có file state), Ansible cấu hình bên trong. Có thể dùng Docker provider để triển khai stack LibreNMS và Oxidized thay `docker compose`; Ansible vẫn lo cấu hình thiết bị mạng.

## Câu hỏi nên hỏi lại nhà tuyển dụng

- Công ty giám sát hạ tầng bằng công cụ nào, SNMP hay streaming telemetry?
- Cấu hình thiết bị mạng hiện được sao lưu và quản lý thay đổi thế nào?
- Có đang dùng Ansible hay công cụ tự động hóa nào cho mạng không?
