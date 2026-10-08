# Worked examples

1. P0 đang chảy máu + nền tảng cần thiết
2. Kiến trúc "hữu ích" không được hoãn target
3. Một item nuốt item khác mà không xóa risk
4. Unknown cần nhánh Scout ngắn

## 1. P0 đang chảy máu + nền tảng cần thiết

**Input.** X là P0: checkout đôi khi charge hai lần. Fix bền cần idempotency key lưu atomic.
Y là P2: thêm shared idempotency store, ước 3 ngày. Feature flag tắt auto-retry mất 1 giờ.

**Nhân–quả.**

1. Duplicate charge đang tiếp diễn → chờ Y 3 ngày là thiệt hại không chấp nhận được.
2. Tắt auto-retry chặn được đường duplicate đã biết → mitigation M chạy trước.
3. Criteria "request retry không charge hai lần" cần record idempotency atomic → Y là
   **necessary**, không chỉ "sạch hơn".
4. Vậy Y sau M, trước implementation X.
5. Flag làm giảm availability và là tạm → cleanup C chỉ sau khi validation production pass.
6. X vẫn P0 và *mở* tới khi có `ACCEPT <sha>` cho F với evidence từ V.

**Sequence.**

| Horizon | Item | Disposition / write | Done evidence |
|---|---|---|---|
| Now | M: tắt auto-retry | Engineer, write, **lease** | metric duplicate ngừng tăng trên đường đã biết |
| Now | O: telemetry phân biệt retry bị từ chối vs thanh toán mới | Engineer, write — **xếp sau M** (cùng checkout) hoặc worktree riêng | dashboard tách được hai loại |
| Next | Y: idempotency store atomic | Engineer, write | concurrency test: một charge cho key lặp |
| Next | F: nối checkout với Y | Engineer, write; Reviewer read-only trên SHA (chạm boundary payment) | load/failure test pass; canary 0 duplicate |
| Later | C: bật lại retry, gỡ flag | Engineer, write | retry hồi phục, không duplicate |

Ghi chú: M và O cùng là writer; trong shared checkout thì là *xếp hàng*, không phải song song.
Muốn song song thật → hai worktree, contract cho tên metric/field dùng chung trong brief trước.

## 2. Kiến trúc "hữu ích" không được hoãn target

**Input.** X là P1: export invoice lỗi với tên khách non-ASCII. Fix encoding thẳng: 1 ngày.
Y: đề xuất viết lại reporting service, 6 tuần.

**Foundation test.** Criteria của X đạt và test được không cần Y. Y có thể tăng maintainability
nhưng không ràng buộc nào bắt buộc. 6 tuần export hỏng > 1 ngày đường thẳng. → Y là **useful**
hoặc **speculative**, không necessary.

**Sequence.** (1) Scout `xia` Quick: seam encoding ở đâu, fixture nào đang có. (2) Engineer
writer: thêm fixture tên Việt/Nhật/Ả Rập đang fail, sửa boundary encoding, chạy regression.
(3) Người giao việc `ACCEPT <sha>`. (4) Y thành proposal riêng với outcome + evidence riêng.

Nguyên nhân: đường thẳng thỏa X an toàn. Hệ quả: Y không có quyền chặn X chỉ vì kiến trúc đẹp hơn.

## 3. Một item nuốt item khác mà không xóa risk

**Input.** X là P0: admin có thể vô tình để lộ workspace private. Y là P2: thay permission editor
mới, sẽ bỏ control nguy hiểm và thỏa mọi criteria của X.

**Sai.** Đóng X *resolved* ngay, để Y ở P2 → metric bảo risk lộ đã hết trong khi editor cũ vẫn
chạy.

**Đúng.** (1) Copy criteria của X vào Y, hoặc giữ X là P0 parent outcome. (2) X ghi *tracked by
Y*, không *resolved*. (3) Chuyển urgency P0 sang scope tương ứng của Y. (4) Thêm bước xác nhận
tạm nếu giảm risk thật. (5) Đóng P0 chỉ khi editor mới đã deploy và exposure test pass — trong SLP
là `ACCEPT <sha>` với `Verification` chứa test đó, và người yêu cầu accept vì deploy là external
side effect.

## 4. Unknown cần nhánh Scout ngắn

**Input.** X là P1: search latency vượt target lúc peak. Một đề xuất: index mới Y. Chưa biết
bottleneck ở index lookup hay authorization downstream.

**Nhân–quả.** Build Y ngay là speculative vì chưa biết nút thắt. Một item D — trace + load test có
time box 4 giờ — phân biệt được hai đường.

**Nhánh.**

1. Now: Scout `xia` Deep + Engineer read-only chạy D trên rig `/tmp`, ghi latency theo stage dưới
   tải đại diện. Không write.
2. Nếu index lookup > ngưỡng thỏa thuận → brief writer implement + benchmark Y.
3. Nếu authorization chiếm phần lớn → tối ưu/cache đường authorization thay vì Y.
4. Không bên nào trội → về bước 1 với evidence trace mới.

D là work item hợp lệ vì giải một unknown có tên và có quyết định gắn kèm. "Điều tra
performance" không time box, không evidence target, không điều kiện rẽ → không phải plan item.
