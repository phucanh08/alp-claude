#!/usr/bin/env python3
"""Nháp khung prompt/brief từ prompt thô (deterministic).

    augment_prompt.py "<prompt thô>" [--mode brief|prompt] [--disposition X] [--task-id ID]

--mode brief   (mặc định) khung brief 13 trường Lead -> Peer theo lead.md
--mode prompt  khung 7 khối cho Human -> Lead

Script chỉ điền phần suy được từ từ khóa. Base, Owned scope, Boundary ruling vẫn là việc của Lead:
mọi chỗ chưa biết in `<TODO: ...>`.
"""

from __future__ import annotations

import argparse
import re
from textwrap import dedent

DISPOSITION_KEYWORDS = {
    "scout": [
        "research", "khảo sát", "tìm hiểu", "map", "compare", "so sánh", "docs", "tài liệu",
        "reuse", "có sẵn", "đã có", "latest", "version", "look up", "investigate", "điều tra",
    ],
    "reviewer": [
        "review", "audit", "critique", "inspect", "evaluate", "assess", "kiểm tra", "đánh giá",
        "rà soát",
    ],
    "architect": [
        "design", "thiết kế", "architecture", "kiến trúc", "schema", "migration", "trade-off",
        "contract", "public api", "boundary",
    ],
    "engineer": [
        "implement", "fix", "sửa", "thêm", "add", "refactor", "bug", "test", "feature", "code",
        "function", "endpoint", "viết",
    ],
}

DEEP_MARKERS = [
    "careful", "cẩn thận", "deep", "thorough", "kỹ", "high stakes", "production", "critical",
    "security", "bảo mật", "migration", "schema", "public api", "xóa data", "delete data",
]
QUICK_MARKERS = ["quick", "nhanh", "nhỏ", "typo", "rename", "one-line", "một dòng", "format"]

WRITE_BY_DISPOSITION = {
    "engineer": "yes",
    "architect": "<TODO: yes|no — Lead quyết>",
    "reviewer": "no",
    "scout": "no",
}

TOOL_RULES = {
    "engineer": "Đọc file và dependency liên quan trước khi sửa. Thay đổi nhỏ nhất đúng. Kiểm bằng lệnh hẹp nhất có ích trước khi mở rộng.",
    "scout": "Read-only. Evidence local trước, upstream sau, docs đúng version sau cùng. Gắn nhãn Local/Upstream/Docs/Inference. Không sửa file.",
    "reviewer": "Đọc đúng SHA (git show sha:path, git diff base sha), không đọc working tree. Finding kèm path:line và severity. Không nhận verdict của Lead làm tiền đề.",
    "architect": "Nêu ownership + lifecycle cho mỗi abstraction đề xuất. So sánh ít nhất hai phương án. Không đúc contract mà CLAUDE.md đánh dấu nếu brief chưa ruling.",
}

OUTPUT_CONTRACT = {
    "engineer": "Handoff 6 ô: Outcome, Candidate (SHA + base), Scope, Verification (lệnh + output thật), Unknown/risk, Ownership.",
    "scout": "Handoff 6 ô (bỏ Candidate; Ownership: n/a) + research brief theo template xia.",
    "reviewer": "Handoff 6 ô (bỏ Candidate) + finding theo severity, mỗi finding path:line trên đúng SHA.",
    "architect": "Handoff 6 ô + phương án đề xuất với ownership/lifecycle, trade-off, và câu hỏi cần Lead ruling.",
}

TASK_TYPE_KEYWORDS = {
    "research": DISPOSITION_KEYWORDS["scout"],
    "review": DISPOSITION_KEYWORDS["reviewer"],
    "planning": ["plan", "roadmap", "strategy", "kế hoạch", "lộ trình", "outline", "sequence"],
    "writing": ["write", "rewrite", "draft", "email", "memo", "blog", "copy", "tone", "soạn"],
    "coding": DISPOSITION_KEYWORDS["engineer"] + DISPOSITION_KEYWORDS["architect"],
}


def _score(text: str, table: dict[str, list[str]]) -> dict[str, int]:
    lowered = text.lower()
    return {key: sum(1 for kw in kws if kw in lowered) for key, kws in table.items()}


def detect_disposition(prompt: str) -> str:
    """Disposition cho brief Lead -> Peer. Hòa hoặc không khớp -> engineer."""
    scores = _score(prompt, DISPOSITION_KEYWORDS)
    best, best_score = max(scores.items(), key=lambda kv: kv[1])
    return best if best_score > 0 else "engineer"


def detect_task_type(prompt: str) -> str:
    """Loại việc cho prompt Human -> Lead. Không khớp -> coding."""
    scores = _score(prompt, TASK_TYPE_KEYWORDS)
    best, best_score = max(scores.items(), key=lambda kv: kv[1])
    return best if best_score > 0 else "coding"


def infer_depth(prompt: str) -> str:
    lowered = prompt.lower()
    if any(m in lowered for m in DEEP_MARKERS):
        return "Deep"
    if any(m in lowered for m in QUICK_MARKERS):
        return "Quick"
    return "Standard"


def normalize(prompt: str) -> str:
    return re.sub(r"\s+", " ", prompt).strip()


def build_brief(raw_prompt: str, disposition: str | None = None, task_id: str | None = None) -> str:
    """Khung brief 13 trường theo lead.md. Lead điền các <TODO>."""
    objective = normalize(raw_prompt)
    disp = disposition or detect_disposition(objective)
    depth = infer_depth(objective)
    write = WRITE_BY_DISPOSITION[disp]
    is_writer = write == "yes"
    concurrency = "exclusive-writer" if is_writer else "read-only"
    lease = "required" if is_writer else "n/a"
    candidate = "candidate SHA + base + branch + root" if is_writer else "(read-only: bỏ Candidate)"
    return dedent(
        f"""\
        Project / Task ID      {task_id or '<TODO: task id>'}
        Repository root        <TODO: abs path checkout chính hoặc worktree Lead đã tạo>
        Base                   <TODO: SHA thật, không phải chữ HEAD>
        Disposition            {disp.capitalize()}  (depth: {depth}; write: {write})
        Objective              {objective}
        Owned scope            <TODO: path/glob>
        Excluded scope         <TODO: path/glob, và boundary CLAUDE.md không được chạm>
        Boundary ruling        <TODO: ruling cho boundary bị chạm, hoặc: none / BLOCKED khi chạm>
        Authority              được: sửa trong owned scope, commit local{'' if is_writer else ' — KHÔNG (read-only)'}; cấm: push, deploy, gọi service ngoài, sửa config global
        Concurrency            {concurrency}
        Commit lease           {lease}
        Verification           <TODO: lệnh cụ thể từ CLAUDE.md>; tài nguyên độc quyền (port/DB/full suite): <TODO: cấp|không>
        Model                  inherit
        Tool rules             {TOOL_RULES[disp]}
        Handoff contract       {OUTPUT_CONTRACT[disp]}
                               Candidate: {candidate}
        Done                   handoff đủ 6 ô, Ownership: released; REOPEN/DEPENDENCY/BLOCKED kèm evidence + tầng
        """
    ).rstrip()


def build_prompt(raw_prompt: str) -> str:
    """Khung 7 khối cho Human -> Lead."""
    objective = normalize(raw_prompt)
    task = detect_task_type(objective)
    depth = infer_depth(objective)
    return dedent(
        f"""\
        Objective:
        - {objective}
        - Xong nghĩa là: <TODO: một câu outcome quan sát được>

        Context:
        - Đọc trước: <TODO: file / doc / log / issue>
        - Ràng buộc: <TODO: boundary trong CLAUDE.md, non-goal>
        - Chưa biết: <TODO: giả định cần xác nhận>

        Work Style:
        - Loại việc: {task}; depth: {depth}
        - Rộng trước để hiểu hệ, sâu ở chỗ risk; first-principles trước khi đổi; mắt mới trước khi chốt.

        Tool Rules:
        - Tra được từ repo thì tra, không đoán. Không push/deploy/gọi ngoài nếu chưa được cấp.

        Output Contract:
        - Lead: Task Contract (goal-griller) → sequence → brief; Peer: handoff 6 ô; Lead chấm ACCEPT/REJECT <sha>.

        Verification:
        - Proof: <TODO: lệnh + kết quả mong đợi>

        Done Criteria:
        - <TODO: điều kiện dừng>; dừng hỏi Human khi: <TODO>
        """
    ).rstrip()


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Nháp khung brief/prompt từ prompt thô.")
    p.add_argument("prompt", help="Prompt thô")
    p.add_argument("--mode", choices=["brief", "prompt"], default="brief")
    p.add_argument("--disposition", choices=sorted(DISPOSITION_KEYWORDS), help="Ép disposition (mode brief)")
    p.add_argument("--task-id", help="Task ID (mode brief)")
    return p.parse_args()


def main() -> None:
    a = parse_args()
    if a.mode == "brief":
        print(build_brief(a.prompt, a.disposition, a.task_id))
    else:
        print(build_prompt(a.prompt))


if __name__ == "__main__":
    main()
