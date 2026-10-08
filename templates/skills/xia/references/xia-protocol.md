# Xia Protocol — luồng chi tiết

Chỉ đọc sau khi đã chọn skill `xia`.

## Hợp với việc gì

- repo lạ, hoặc phần repo chưa ai trong team chạm;
- yêu cầu mơ hồ về *cái đã có*;
- tích hợp nhạy version (framework major, SDK, CLI);
- việc có thể đã được repo hoặc framework hỗ trợ sẵn;
- change risk cao mà một giả định sai làm mất cả lượt writer.

Không hợp: sửa nhỏ hiển nhiên, rename cơ học, implement khi brief đã được chốt trên research cũ.

## 1. Map repo

Bắt đầu từ contract và docs nếu có: `CLAUDE.md`, `README.md`, doc kiến trúc / workflow / packaging.

Phân loại repo **từ evidence**: app, service, package, plugin, library, CLI, infra, automation,
monorepo hỗn hợp.

Dựng stack ledger từ artifact:

- manifest, lockfile, workspace file, `tsconfig*`;
- `pyproject.toml`, requirements, `Cargo.toml`, `go.mod`;
- Dockerfile, compose, plugin manifest, MCP config;
- `.claude/`, `.github/workflows`, script, test, entrypoint.

Ghi: ngôn ngữ, runtime, framework, hình dạng packaging, tool chính, service ngoài, lệnh
verification. Kiểm version binary thật (`node --version`, `python3 --version`, …) khi hành vi
runtime phụ thuộc version và kiểm rẻ.

## 2. Tìm reuse local trước

Đọc code kề feature, test, script, docs, workflow, experiment, config, env validation. Tool tìm
kiếm (Grep/Glob, `gkg` nếu có) là gia tốc; **file chứng minh hành vi mới là evidence**.

Bước này phải trả lời:

- cái gì đã có;
- cái gì dùng lại được;
- extension point nào đang mở;
- cái gì thật sự thiếu.

## 3. Pattern upstream

Chỉ sau khi local rõ. Nguồn ưu tiên: repo framework/library, starter chính thức, ví dụ tích hợp
gần với repo. Mục tiêu là **proof dùng lại được**, không phải cảm hứng chung.

Trên Claude Code: `WebFetch` raw file GitHub, hoặc `gh api` / `gh repo view` nếu có. Không tải cả
repo về checkout đang làm việc; cần clone thì clone vào `/tmp`.

## 4. Docs chính thức đúng version

Ưu tiên domain chính thức, docs khớp version repo, hướng dẫn stable — trừ khi beta/canary là điểm
đang hỏi.

Trên Claude Code: MCP Context7 (`resolve-library-id` → `query-docs`) hoặc skill `docs-seeker`
nếu có; fallback `WebFetch`/`WebSearch` trỏ domain chính thức. Ghi rõ docs đang đọc là version nào.

Phải trả lời:

- framework/library đã hỗ trợ capability này chưa;
- API/workflow khuyến nghị hiện tại;
- caveat version cho repo này;
- risk migration / incompatibility.

Local và docs mâu thuẫn → local là sự thật hiện hành; ghi mâu thuẫn vào brief.

## Vai trò tool

| Cần | Đường chính | Quy tắc |
|---|---|---|
| Sự thật repo hiện tại | Read / Grep / Glob / Bash trên file thật | bắt buộc, làm trước |
| Pattern công khai | WebFetch GitHub, `gh` | best-effort, không chặn |
| Docs hiện hành | Context7 / docs-seeker, WebFetch domain chính thức | ưu tiên đúng version |
| Tổng hợp | research brief | tách Local / Upstream / Docs / Inference |

## Câu hỏi — cho người giao việc, không cho người yêu cầu

Scout không có kênh hỏi người yêu cầu. Câu hỏi đi vào mục *Follow-up* của brief khi:

- các đường đi khác nhau đáng kể về hành vi sản phẩm, risk vận hành, chi phí migration;
- evidence repo mâu thuẫn với yêu cầu theo cách đổi đề xuất;
- version/môi trường chưa chắc và điều đó đổi đường implement.

Ngoài ra: đưa đề xuất có evidence, không hỏi.

## Red flag

- Đoán stack từ tên thư mục, branding, hoặc trí nhớ.
- Nhảy sang web trước khi có evidence local.
- Không thấy trên upstream → bỏ luôn bước upstream.
- Dùng docs lệch version mà không nói.
- Gộp bốn nhãn thành một câu chuyện.
- Bắt đầu sửa file trước khi brief xong khi research chưa waive.
- Đề xuất một đường mà không nói đường bị loại.

Smell test: brief phải trả lời được *có gì, dùng lại gì, docs nói gì, đi đường nào*.
