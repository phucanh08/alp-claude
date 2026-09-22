"""Chạy: python3 -m pytest skills/prompt-leverage/scripts -q  (hoặc python3 test_augment_prompt.py)"""

import importlib.util
from pathlib import Path


def load():
    path = Path(__file__).resolve().parent / "augment_prompt.py"
    spec = importlib.util.spec_from_file_location("augment_prompt", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_detect_disposition_engineer_default():
    m = load()
    assert m.detect_disposition("Fix the repo bug and add a regression test.") == "engineer"
    assert m.detect_disposition("làm cái gì đó") == "engineer"


def test_detect_disposition_scout_and_reviewer():
    m = load()
    assert m.detect_disposition("Khảo sát repo xem đã có cơ chế retry chưa, docs nói gì") == "scout"
    assert m.detect_disposition("Review candidate abc123 cho finding bảo mật") == "reviewer"


def test_brief_writer_vs_readonly():
    m = load()
    writer = m.build_brief("Implement email verification endpoint", task_id="T-1")
    assert "Concurrency            exclusive-writer" in writer
    assert "Commit lease           required" in writer
    assert "Project / Task ID      T-1" in writer
    assert "Implement email verification endpoint" in writer

    scout = m.build_brief("Khảo sát xem framework có sẵn rate limit chưa")
    assert "Concurrency            read-only" in scout
    assert "Commit lease           n/a" in scout
    assert "Local/Upstream/Docs/Inference" in scout


def test_depth_and_prompt_mode():
    m = load()
    assert m.infer_depth("Carefully migrate the schema") == "Deep"
    assert m.infer_depth("fix typo") == "Quick"
    assert m.infer_depth("add endpoint") == "Standard"
    out = m.build_prompt("Research latest docs and cite sources")
    assert "Loại việc: research" in out
    assert "Done Criteria" in out
    assert "Research latest docs and cite sources" in out


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("ok", name)
