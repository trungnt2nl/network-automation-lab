# Topology và quy hoạch IP

## Sơ đồ

```mermaid
flowchart TB
    NMS["NMS - Ubuntu Server<br/>192.168.141.131<br/>LibreNMS, Oxidized, Ansible"]
    NAT["VMware NAT<br/>192.168.141.0/24<br/>gateway 192.168.141.2"]
    EVE["EVE-NG VM<br/>pnet0 = 192.168.141.196"]
    CLOUD["Cloud0 (pnet0)"]
    SW1["SW1 - Cisco IOL L2<br/>192.168.141.61"]
    R1["R1 - Cisco IOL<br/>192.168.141.62"]
    R2["R2 - Cisco IOL<br/>192.168.141.63"]

    NMS --- NAT
    NAT --- EVE
    EVE --- CLOUD
    CLOUD ---|e0/0| SW1
    SW1 ---|e0/1 - e0/0| R1
    SW1 ---|e0/2 - e0/0| R2
```

## Quy hoạch IP

| Thiết bị | Vai trò | IP | Ghi chú |
|---|---|---|---|
| NMS (Ubuntu Server) | Máy giám sát và tự động hóa | 192.168.141.131/24 | Gateway 192.168.141.2, card `ens33` |
| EVE-NG VM | Chạy các node IOL | 192.168.141.196/24 | Card `pnet0` nằm trên mạng NAT |
| SW1 | Switch L2 | 192.168.141.61/24 | IP quản trị trên `Vlan1`, `ip default-gateway 192.168.141.2` |
| R1 | Router | 192.168.141.62/24 | `Ethernet0/0`, default route tới `.2` |
| R2 | Router | 192.168.141.63/24 | `Ethernet0/0`, default route tới `.2` |

Các IP `.61` đến `.63` nằm ngoài dải DHCP mặc định của VMware NAT (`.128` đến `.254`), nên không trùng với máy khác.

## Vì sao thiết kế như vậy

- Máy NMS dùng luôn mạng NAT đang có (có Internet để kéo image Docker), nên không cần thêm card mạng hay định tuyến giữa hai mạng.
- `Cloud0` của EVE-NG ứng với card đầu tiên của VM EVE-NG, vốn nằm trên mạng NAT. Nối `e0/0` của SW1 vào `Cloud0` đưa cả lab vào cùng subnet với NMS.
- Toàn bộ thiết bị trong một subnet, không cần định tuyến, nên lỗi dễ khoanh vùng và dễ giải thích.
- Topology tối thiểu (1 switch, 2 router) đủ để thể hiện giám sát, sao lưu và tự động hóa theo nhóm (`switches`, `routers`).
