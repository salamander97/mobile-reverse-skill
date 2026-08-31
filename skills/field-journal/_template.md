# [日期] [项目简称]

## 场景分类
<!-- Phân tích ngược APK / ký JS / phân tích nhị phân / kiểm thử xâm nhập / CTF / phân tích bắt gói / khác -->

## 目标概述
<!-- Mô tả trong một câu đang thực hiện việc gì -->

## Scope 摘要（脱敏）
<!-- Loại auth.basis / network_profile.mode / in_scope (không ghi domain/IP thật) -->
- auth_basis:
- network_profile:
- asset_types: []

## 角色
<!-- lead / cie / cpe / cre / … xem skills/ops/role-map.md -->
- lead_role: lead
- specialists: []

## 完整执行链路
<!-- Các bước đầy đủ từ khi nhận mục tiêu đến khi có kết quả, gồm cả đường vòng đã thử -->

1. ...
2. ...
3. ...

## Evidence 链摘要（脱敏）
<!-- Tối đa 3 mục: E-id + mẫu lệnh + loại kết luận; evidence đầy đủ nằm trong dự án người dùng -->
<!-- Các trường đồng nhất với quy ước của skills/case-review/scripts/review_case.py (xem hướng dẫn bên dưới) -->
| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-001 | info | observed | command | `checksec --file=./pwn1` | F-001 |
| E-002 | high | validated | command | `python3 exploit.py REMOTE` | F-001 |

> **契约对齐（review_case.py）**：若本次 case 产出了独立证据目录（`evidence/E-xxx.md`），
> 每条证据须满足 `skills/case-review/scripts/review_case.py` 的字段契约，否则 `--strict` 校验会 FAIL：
>
> - 标题：`### E-xxx`（须与文件名一致，如 `E-001.md` → `### E-001`）
> - `- severity:` ∈ critical / high / medium / low / info / n/a
> - `- status:` ∈ observed / candidate / validated / false_positive / accepted_risk
> - `- repro_command:` 必填（离线场景在 notes 中注明 offline/离线 可豁免）
> - `- content_hash:` sha256 或 n/a；填 sha256 时配套 `- artifact_path:`（case 内相对路径）
> - `- linked_workitem:` 可选，WI-xxx 必须真实存在
>
> 自检：`python skills/case-review/scripts/review_case.py <case_root> --verify-hashes --strict`

## Finding / Path 摘要
- top_finding:
- path_type: attack | callflow | solve
- path_one_liner:

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| ... | ... | ... | ... |

## 工具链发现
<!-- Đã dùng công cụ nào, công cụ nào hữu ích, vấn đề nào cần lưu ý và tương thích phiên bản -->

## 关键代码/命令

```
<!-- Dán các lệnh chính, hook script và logic giải mã thực tế đã dùng -->
```

## 对本包的改进建议
<!-- Định tuyến có chính xác không? Có thiếu bootstrap không? Có cần bổ sung tài liệu hay thêm công cụ vào manifest không? -->

## 可复用的模式/脚本片段
<!-- Nếu tạo được hook script, logic giải mã hoặc phương án xử lý có thể tái sử dụng, dán tại đây -->

## 进化动作
<!-- Sau lần ghi ngược này đã thực sự cập nhật những gì -->
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [ ] 新增了 pitfalls 记录
- [ ] 无需更新

## 环境信息
<!-- Ghi lại môi trường quan trọng tại thời điểm đó -->
- OS:
- 工具版本:
- 目标平台/版本:

## 脱敏要求

> **本文件可能随仓库同步到远程，必须脱敏。完整规范见 [`anonymization.md`](anonymization.md)（占位符总表 + 自动检测脚本）。**

- 目标域名/IP：用 `{target_domain}` / `{target_ip}` 替代（详见 `anonymization.md`）
- 真实 URL 路径：保留结构，替换域名
- Token/Cookie/密码/JWT/API key：用 `{token}` / `{password}` / `{api_key}` 占位
- 用户名/手机号/邮箱：用 `{username}` / `{phone}` / `{user_email}` 占位
- 内部 IP/端口：内网 IP 段保留前两段（`10.0.x.x`）
- 漏洞 payload：可保留技术内容，但替换目标特征参数（如 `?id={user_id}`）

提交前对照 `anonymization.md` 末尾的 **Field-Journal 必查项 checklist** 跑一遍正则扫描。

如果是私有仓库且确认不会公开，可以放宽以上限制，但仍建议脱敏。

## 索引同步（提交前最后一步）

写完本日志后，必须同步更新 `_index.md`：

1. 在「按场景分类」对应小节新增一行（含日期、关键词）
2. 在「高频成功模式（按技术）」对应技术下追加本文件名
3. 在「实体倒排（按目标特征）」对应实体下追加本文件名
4. 更新「累计统计」的总数与"最近更新"日期

---
<!-- [Thống kê cải tiến] Tổng số dự án đã hoàn thành: N | Mẫu mới lần này: X | Vấn đề toolchain đã sửa: Y -->
<!-- [Đóng góp cộng đồng] Sau khi hoàn tất, hỏi người dùng có muốn tạo PR vào repo chính không. Xem quy trình trong CONTRIBUTE-BACK.md -->
