#!/usr/bin/env python3
import datetime as dt
import json
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PM_DIR = ROOT / "docs" / "pm"
CFG = PM_DIR / "pm_config.json"


def run_git(args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    if r.returncode != 0:
        err = (r.stderr or b"").decode("utf-8", errors="replace").strip()
        raise RuntimeError(err or "git command failed")
    return (r.stdout or b"").decode("utf-8", errors="replace").strip()


def load_config():
    with CFG.open("r", encoding="utf-8-sig") as f:
        return json.load(f)


def parse_commits(days):
    fmt = "%H|%an|%ae|%ad|%s"
    raw = run_git(["log", f"--since={days} days ago", f"--pretty=format:{fmt}", "--date=iso"])
    commits = []
    if not raw:
        return commits
    for line in raw.splitlines():
        parts = line.split("|", 4)
        if len(parts) != 5:
            continue
        h, an, ae, ad, sub = parts
        commits.append({"hash": h, "author": an, "email": ae, "date": ad, "subject": sub})
    return commits


def parse_git_dt(s):
    try:
        d = dt.datetime.fromisoformat(s.replace(" ", "T", 1))
    except ValueError:
        return None
    if d.tzinfo is not None:
        d = d.astimezone().replace(tzinfo=None)
    return d


def map_member(commit, cfg):
    author = commit["author"].strip().lower()
    email = commit["email"].strip().lower()
    for m in cfg["members"]:
        authors = {x.strip().lower() for x in m.get("authors", [])}
        emails = {x.strip().lower() for x in m.get("emails", [])}
        if (authors and author in authors) or (emails and email in emails):
            return m["name"]
    return "未匹配成员"


def only_between(text, start_tag, end_tag, new_block):
    s = text.find(start_tag)
    e = text.find(end_tag)
    if s == -1 or e == -1 or e < s:
        return text
    s2 = s + len(start_tag)
    return text[:s2] + "\n" + new_block.rstrip() + "\n" + text[e:]


def write_auto(file_name, start_tag, end_tag, block):
    p = PM_DIR / file_name
    txt = p.read_text(encoding="utf-8")
    new_txt = only_between(txt, start_tag, end_tag, block)
    p.write_text(new_txt, encoding="utf-8")


def date_today():
    return dt.datetime.now().strftime("%Y-%m-%d")


def classify_task(subject):
    s = subject.lower()
    if s.startswith("feat"):
        return "功能"
    if s.startswith("fix"):
        return "修复"
    if s.startswith("refactor"):
        return "重构"
    if s.startswith("docs"):
        return "文档"
    return "其他"


def build_standup(commits, cfg):
    today = date_today()
    daily_cut = dt.datetime.now() - dt.timedelta(days=cfg.get("daily_window_days", 1))
    by_member = defaultdict(list)
    for c in commits:
        cdt = parse_git_dt(c["date"])
        if cdt is None:
            continue
        if cdt >= daily_cut:
            by_member[map_member(c, cfg)].append(c)

    lines = [f"### {today}", ""]
    for m in [x["name"] for x in cfg["members"]] + ["未匹配成员"]:
        items = by_member.get(m, [])
        lines.append(f"- {m}:")
        if not items:
            lines.append("  - 昨天：无提交")
            lines.append("  - 今天：补齐在做任务同步")
            lines.append("  - 阻塞：待确认")
            continue
        done = "; ".join([i["subject"] for i in items[:3]])
        lines.append(f"  - 昨天：{done}")
        lines.append("  - 今天：延续当前提交链路并收口")
        lines.append("  - 阻塞：如有跨模块依赖请补登记")
    return "\n".join(lines)


def build_sprint(commits, cfg):
    by_member = defaultdict(list)
    for c in commits:
        by_member[map_member(c, cfg)].append(c)
    maxn = cfg.get("max_tasks_per_member", 5)
    lines = [f"- 更新时间：{date_today()}", "- 最近 7 天执行摘要："]
    for m in [x["name"] for x in cfg["members"]] + ["未匹配成员"]:
        lines.append(f"  - {m}:")
        items = by_member.get(m, [])[:maxn]
        if not items:
            lines.append("    - 无提交")
            continue
        for c in items:
            lines.append(f"    - [{classify_task(c['subject'])}] {c['subject']} ({c['hash'][:7]})")
    return "\n".join(lines)


def build_release(commits, cfg):
    lines = [f"### {date_today()}", "", "| 成员 | 提交 | 摘要 |", "|---|---|---|"]
    for c in commits[:80]:
        m = map_member(c, cfg)
        lines.append(f"| {m} | `{c['hash'][:7]}` | {c['subject'].replace('|','/')} |")
    if len(lines) == 4:
        lines.append("| - | - | 今日无提交 |")
    return "\n".join(lines)


def build_risks(commits, cfg):
    by_member = defaultdict(int)
    daily_cut = dt.datetime.now() - dt.timedelta(days=cfg.get("daily_window_days", 1))
    for c in commits:
        cdt = parse_git_dt(c["date"])
        if cdt is None:
            continue
        if cdt >= daily_cut:
            by_member[map_member(c, cfg)] += 1

    lines = [f"- 扫描日期：{date_today()}"]
    for m in [x["name"] for x in cfg["members"]]:
        n = by_member.get(m, 0)
        if n == 0:
            lines.append(f"- 高风险：{m} 今日无提交，存在节奏中断风险")
        elif n >= 8:
            lines.append(f"- 中风险：{m} 今日提交 {n} 次，建议检查是否任务切分过碎")
        else:
            lines.append(f"- 低风险：{m} 今日提交 {n} 次")
    unmatched = by_member.get("未匹配成员", 0)
    if unmatched > 0:
        lines.append(f"- 中风险：存在 {unmatched} 条未匹配成员提交，请补全 pm_config 映射")
    return "\n".join(lines)


def build_backlog(commits):
    counters = defaultdict(int)
    examples = {}
    for c in commits:
        k = classify_task(c["subject"])
        counters[k] += 1
        examples.setdefault(k, c["subject"])
    priority = ["修复", "功能", "重构", "文档", "其他"]
    lines = ["- 机器建议（按最近提交结构）："]
    for k in priority:
        if counters[k] > 0:
            lines.append(f"  - {k}: {counters[k]} 条，示例：{examples[k]}")
    if len(lines) == 1:
        lines.append("  - 暂无提交数据")
    return "\n".join(lines)


def main():
    cfg = load_config()
    commits = parse_commits(cfg.get("lookback_days", 7))
    write_auto("standup.md", "<!-- AUTO:STANDUP:START -->", "<!-- AUTO:STANDUP:END -->", build_standup(commits, cfg))
    write_auto("sprint.md", "<!-- AUTO:SPRINT:START -->", "<!-- AUTO:SPRINT:END -->", build_sprint(commits, cfg))
    write_auto("release.md", "<!-- AUTO:RELEASE:START -->", "<!-- AUTO:RELEASE:END -->", build_release(commits, cfg))
    write_auto("risks.md", "<!-- AUTO:RISKS:START -->", "<!-- AUTO:RISKS:END -->", build_risks(commits, cfg))
    write_auto("backlog.md", "<!-- AUTO:BACKLOG:START -->", "<!-- AUTO:BACKLOG:END -->", build_backlog(commits))
    print("PM 自动文档已更新")


if __name__ == "__main__":
    main()
