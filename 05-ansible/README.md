# 05 - Ansible: chuẩn hóa cấu hình hàng loạt

**Ansible** SSH vào nhiều thiết bị cùng lúc và thực hiện việc mô tả trong playbook. Không cần cài gì lên thiết bị (agentless), và chạy lại nhiều lần vẫn cho cùng kết quả (idempotent).

## Cài đặt

```
sudo apt update
sudo apt install -y ansible
ansible-galaxy collection list | grep -E "cisco.ios|ansible.netcommon"
```

Phiên bản trong lab: ansible-core 2.20.1, paramiko 4.0.0, Python 3.14.4. Collection `cisco.ios` và `ansible.netcommon` đi kèm gói apt.

## Cấu trúc

```
ansible/
├── ansible.cfg                    inventory, tắt kiểm tra host key, tắt thử khóa SSH
├── inventory.ini                  nhóm switches, routers, cisco (cha của hai nhóm trên)
├── group_vars/
│   ├── cisco/vars.yml             kiểu kết nối network_cli, tài khoản, trỏ tới biến trong vault
│   ├── cisco/vault.yml.example    mẫu (file vault.yml thật được mã hóa, không commit)
│   ├── switches.yml               biến riêng cho switch
│   └── routers.yml                biến riêng cho router
└── playbooks/01-baseline.yml
```

- `ansible_connection: ansible.netcommon.network_cli`: kiểu kết nối dành cho thiết bị mạng. Ansible mở SSH và gõ lệnh CLI như người dùng.
- Mật khẩu để trong **Ansible Vault** (file mã hóa AES256), `vars.yml` chỉ trỏ tới biến `vault_ansible_password`.
- `look_for_keys = False` trong `ansible.cfg` là bắt buộc, xem [troubleshooting mục 2](../07-troubleshooting/README.md#2-ansible-báo-lỗi-xác-thực-transport-shut-down-or-saw-eof).

## Tạo vault và kiểm tra kết nối

```
cd ansible
EDITOR=nano ansible-vault create group_vars/cisco/vault.yml
# noi dung: vault_ansible_password: "<MAT_KHAU_THIET_BI>"

ansible cisco -m cisco.ios.ios_command -a "commands='show ip interface brief'" --ask-vault-pass
```

Kết quả: cả SW1, R1, R2 trả về `SUCCESS` kèm bảng giao diện của từng thiết bị. Xem [evidence/ansible-connectivity.txt](evidence/ansible-connectivity.txt).

## Playbook chuẩn hóa

[playbooks/01-baseline.yml](../ansible/playbooks/01-baseline.yml) áp dụng bộ cấu hình nền cho cả nhóm `cisco`:

- `service timestamps debug/log datetime msec` (log có thời gian)
- `no ip domain-lookup` (biến theo nhóm, xem bên dưới)
- `logging buffered 16384`
- `ip ssh version 2`
- banner `motd` cảnh báo truy cập

Cách làm an toàn:

```
# 1. xem truoc, khong dung vao thiet bi
ansible-playbook playbooks/01-baseline.yml --check --diff --ask-vault-pass
# 2. ap dung that
ansible-playbook playbooks/01-baseline.yml --ask-vault-pass
# 3. chay lai de chung minh idempotent: changed=0
ansible-playbook playbooks/01-baseline.yml --ask-vault-pass
```

- `ios_config` bỏ qua dòng đã có trên thiết bị, nên chỉ thay đổi khi cần.
- `save_when: modified` chỉ `write memory` khi có thay đổi thật.

### Kết quả

Lần chạy thật đầu tiên: `changed=2` (cả hai task) cho SW1, R1, R2, `failed=0`, `unreachable=0`.

Chạy lại ban đầu: SW1 `changed=0` nhưng R1 và R2 `changed=1`, vì lệnh `no ip domain-lookup` được router lưu thành `no ip domain lookup` (dấu cách), switch thì giữ nguyên dấu gạch. Ansible so sánh **chuỗi chữ** với `running-config`, nên router lần nào cũng bị gửi lại. Cách sửa: biến theo nhóm `no_domain_lookup_line` trong `group_vars/switches.yml` và `group_vars/routers.yml`.

Sau khi sửa: `changed=0` cho cả 3 thiết bị, xem [evidence/baseline-playbook-recaps.txt](evidence/baseline-playbook-recaps.txt).

```
PLAY RECAP ****************************************************************************
R1                         : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
R2                         : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
SW1                        : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Cảnh báo `ansible-pylibssh not installed, falling back to paramiko` và các `DEPRECATION WARNING` là thông báo, không ảnh hưởng kết quả (plugin paramiko đang được Ansible đánh dấu lỗi thời; thay bằng `ansible-pylibssh` là hướng nâng cấp).

## Bằng chứng

- [x] `evidence/ansible-connectivity.txt`: `ios_command` thành công trên 3 thiết bị
- [x] `evidence/baseline-playbook-recaps.txt`: các bảng `PLAY RECAP` (lần chạy thật, lần lệch dạng chữ, lần idempotent)
- [ ] Ảnh `--check --diff` trước khi áp dụng
- [ ] Ảnh banner hiện ra khi SSH vào thiết bị sau khi chạy playbook
