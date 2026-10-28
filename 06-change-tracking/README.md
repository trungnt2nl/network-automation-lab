# 06 - Theo dõi thay đổi, phát hiện lệch và khôi phục

Phần này khép vòng của project: **giám sát** (LibreNMS) cho biết *cái gì hỏng*, **quản lý phiên bản** (Oxidized + Git) cho biết *ai/lúc nào/dòng nào đã đổi*, **tự động hóa** (Ansible) đưa thiết bị về chuẩn.

Lệnh xem lịch sử và diff (từ thư mục gốc repo):

```
G="sudo git -c safe.directory=* --git-dir=docker/oxidized/oxidized.git"
$G log --oneline
$G log -p -1 -- R1                     # thay doi gan nhat cua R1
$G diff <commit-tot> HEAD -- R1        # so sanh voi ban tot da biet
```

Ép Oxidized sao lưu ngay sau mỗi thay đổi và chờ commit mới: `scripts/oxfetch.sh <THIET_BI>`.

## Kịch bản A: thay đổi có chủ đích của quản trị viên (SW1)

Thêm `description` cho hai cổng trên SW1 rồi `write memory`. Oxidized tạo commit `7140750`:

```diff
 interface Ethernet0/1
+ description TO-R1
  duplex auto
 !
 interface Ethernet0/2
+ description TO-R2
  duplex auto
```

Mỗi thay đổi có dấu thời gian, người commit và nội dung chính xác của dòng bị đổi.

## Kịch bản B: cấu hình bị sửa lệch chuẩn và khôi phục bằng Ansible (R1)

**Bối cảnh:** R1 đã được playbook chuẩn hóa (có `logging buffered 16384` và banner chuẩn). Có người sửa tay, làm lệch khỏi chuẩn (configuration drift).

**1. Sửa tay trên R1:**

```
configure terminal
no logging buffered
banner motd #SAI CAU HINH - SUA TAY#
end
write memory
```

**2. Oxidized ghi nhận** (commit `f8db112`, 14:49:28), diff cho thấy `-logging buffered 16384` và `+no logging buffered`, cùng banner đổi sang nội dung sai.

**3. Khôi phục bằng chính playbook chuẩn**, không sửa gì:

```
ansible-playbook playbooks/01-baseline.yml --ask-vault-pass
```

```
R1  : ok=2  changed=2  ...      <- chi R1 bi lech nen chi R1 duoc sua
R2  : ok=2  changed=0  ...
SW1 : ok=2  changed=0  ...
```

Playbook chỉ sửa thiết bị bị lệch, thiết bị đã đúng chuẩn không bị đụng đến.

**4. Oxidized ghi nhận bản khôi phục** (commit `abd0651`, 14:50:29, đúng 1 phút sau), diff đảo ngược đúng hai thay đổi ở trên:

```diff
-no logging buffered
+logging buffered 16384
...
-banner motd ^CSAI CAU HINH - SUA TAY^C
+banner motd ^C
+*** THIET BI LAB - CHI NGUOI DUOC PHAN QUYEN ***
+Moi thao tac deu duoc ghi log.
+^C
```

**5. Xác nhận ổn định:** chạy lại playbook, `changed=0` cho cả 3 thiết bị.

Diff đầy đủ cả hai commit: [evidence/drift-and-restore-R1.txt](evidence/drift-and-restore-R1.txt).

### Ghi chú về `Last configuration change ... by admin`

Diff có thêm dòng `! Last configuration change at 07:50:07 UTC Wed Oct 28 2026 by admin`. Thiết bị tự ghi lại **tài khoản** thực hiện thay đổi cuối. Vì người và Ansible cùng dùng `admin`, dòng này không cho biết thay đổi do ai. Đây là lý do nên dùng tài khoản riêng cho tự động hóa (mục cải tiến trong [README gốc](../README.md)).

## Kịch bản C: tắt nhầm cổng, LibreNMS báo, truy vết bằng Git

Kịch bản dự kiến: tắt `e0/1` trên SW1 (cổng nối R1), LibreNMS báo R1 Down, `git diff` chỉ ra dòng `+ shutdown` dưới `interface Ethernet0/1`, hoàn tác bằng `no shutdown` và diff về rỗng.

- [ ] **Chưa có bằng chứng:** chưa có ảnh R1 Down và diff `+ shutdown` cho kịch bản này, nên chưa tính là đạt.
- Gợi ý hoàn thiện: lịch sử Git của SW1 có hai commit nằm giữa mốc thêm `description` và mốc chạy playbook (`58ea466`, `0fdf251`, xem [04-oxidized/evidence/git-log.txt](../04-oxidized/evidence/git-log.txt)). Nếu hai commit này đến từ bài tắt/mở cổng thì `git show 58ea466 -- SW1` và `git show 0fdf251 -- SW1` sẽ cho đúng diff cần chụp. Chỉ dùng khi đã xác nhận nội dung thật của chúng. (Phần phát hiện Down bằng LibreNMS đã chứng minh ở [03-librenms](../03-librenms/README.md) bằng bài tắt cổng nối R2.)

## Giới hạn hiện tại

- Khôi phục theo từng dòng (hoàn tác đúng dòng đổi hoặc chạy lại playbook), chưa thay toàn bộ cấu hình từ một commit cũ (ví dụ `configure replace` cần thiết bị hỗ trợ và nơi lưu file cấu hình).
- Playbook hiện chỉ quản lý một tập cấu hình nền nhỏ. Dòng ngoài tập đó bị sửa lệch thì Ansible không phát hiện, chỉ Oxidized thấy qua diff.
- Oxidized chạy mỗi giờ theo `interval`, nên phát hiện thay đổi có độ trễ tối đa 1 giờ nếu không ép chạy.

## Bằng chứng

- [x] `evidence/drift-and-restore-R1.txt`: diff của commit lệch và commit khôi phục
- [x] `evidence/play-recap-restore.txt`: kết quả playbook khi khôi phục (R1 `changed=2`, hai thiết bị kia `changed=0`)
- [ ] Ảnh chụp màn hình hai diff cạnh nhau cho kịch bản B
- [ ] Bằng chứng kịch bản C
