#!/usr/bin/env python3
"""Repo lint.

L1   a commit changed game code and not the feature file the verify skill maps to it.
L2b  a key of the verify driver's _state() is missing from the State fields line of SKILL.md.
L3   a doc comment names its caller, or the same doc comment sits in two files.
L4   a test asserts a pinned read: a collision bit, a binding count, or a node list index.

A fixture file ends in .fixture so Godot and the parse check skip it.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent / "lint" / "fixtures"
FIXTURE_SUFFIX = ".fixture"
VERIFY = ".claude/skills/verify"
FEATURES = VERIFY + "/features/"
DRIVER = VERIFY + "/driver.gd"
SKILL = VERIFY + "/SKILL.md"

ANY_FEATURE = "<any feature file or SKILL.md>"
FEATURE_MAP: dict[str, list[str]] = {
    "game/weapon/": ["pistol.md", "melee.md", "buys.md", "perks.md"],
    "game/station/door.gd": ["doors.md"],
    "game/station/power_switch.gd": ["doors.md", "perks.md"],
    "game/station/cache.gd": ["doors.md"],
    "game/station/perk_machine.gd": ["perks.md"],
    "game/station/upgrade_machine.gd": ["perks.md"],
    "game/station/machine.gd": ["perks.md"],
    "game/station/": ["buys.md", "perks.md", "doors.md"],
    "game/player/": ["movement.md"],
    "game/zombie/": ["rounds.md", "death-restart.md"],
    "game/round_director.gd": ["rounds.md"],
    "game/points.gd": ["buys.md", "rounds.md"],
    "game/perks.gd": ["perks.md"],
    "game/level/secret.gd": ["doors.md"],
    "game/level/sigil.gd": ["doors.md"],
    "game/level/": ["README.md", "doors.md", "buys.md", "perks.md", "movement.md"],
    "game/hud.gd": [ANY_FEATURE],
    "game/game.gd": [ANY_FEATURE],
    "game/rules.gd": [ANY_FEATURE],
}
L1_IGNORED = (".uid", ".gdshader", ".tres", "lamp.tscn", "game/layers.gd", "game/main.tscn")
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
TRAILER = re.compile(r"^Verify-map: unchanged \(.+\)$", re.M)

CALLER = re.compile(
    r"^\s*##?\s.*\b(?:[A-Z_][\w.]*|_\w+|[a-z_]+\(\))\s+(?:(?:also|only)\s+)?"
    r"(?:sets?|calls?|seeds?|reads?|uses?|connects?|overrides?|replaces?)\s+(?:it|this|them|these)\b"
)
CALLER_TESTS = re.compile(r"^\s*##?\s.*\b(?:[Tt]ests?|[Cc]allers?)\s+(?:call|set|seed|read|use|write)\b")
DOC_COMMENT = re.compile(r"^\s*##\s*(.+?)\s*$")
MIN_DUPLICATE_LENGTH = 12

ASSERT_CALL = re.compile(r"\b(?:check|ok|eq|near|between)\(")
PINNED_READS: list[tuple[re.Pattern[str], str, str]] = [
    (
        re.compile(r"\bcollision_(?:layer|mask)\b"),
        "reads a collision bit",
        "Assert what the player observes: the prompt, the interact result, a ray hit, or movement.",
    ),
    (
        re.compile(r"InputMap\.action_get_events\([^)]*\)\.size\(\)"),
        "counts the bindings of an action",
        "Press the binding and assert that the action fires.",
    ),
    (
        re.compile(r"\b(?:stations|machines|spawns\(\)|get_children\(\)|zones|children)\[\d+\]"),
        "indexes a node list by a literal",
        "Find the node by type or name, not by its place in the scene.",
    ),
]


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    what: str
    fix: str
    kind: str = ""

    def render(self) -> str:
        return f"FAIL lint {self.rule}: {self.path}:{self.line}: {self.what}. {self.fix}"

    def key(self) -> str:
        return f"{self.rule}{' ' + self.kind if self.kind else ''} {self.path}:{self.line}"


@dataclass(frozen=True)
class AllowedDuplicate:
    path: str
    text: str
    reason: str


_BUILD_CHILDREN = "The children that _build() adds. They have no owner, so the editor does not save them in the scene."
_BUILD_RAY = "The interact area stands out from the wall, so the ray finds it before the wall."
_BUILD_REASON = "A real why, copied into each station by _build(). PR 8 builds the level in code and deletes the copies."
ALLOWED_DUPLICATES: tuple[AllowedDuplicate, ...] = (
    AllowedDuplicate("game/level/sigil.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/cache.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/door.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/machine.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/power_switch.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/wall_buy.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/machine.gd", _BUILD_RAY, _BUILD_REASON),
    AllowedDuplicate("game/station/wall_buy.gd", _BUILD_RAY, _BUILD_REASON),
)


class Tree:
    def __init__(self, root: Path, suffix: str = "") -> None:
        self.root = root
        self.suffix = suffix

    def paths(self, pattern: str) -> list[str]:
        found = self.root.glob(pattern + self.suffix)
        return sorted(p.relative_to(self.root).as_posix().removesuffix(self.suffix) for p in found if p.is_file())

    def lines(self, path: str) -> list[str] | None:
        file = self.root / (path + self.suffix)
        return file.read_text(encoding="utf-8").splitlines() if file.is_file() else None


def lint_l3(tree: Tree, allowed: tuple[AllowedDuplicate, ...]) -> list[Finding]:
    findings: list[Finding] = []
    sites: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for path in tree.paths("game/**/*.gd") + [p for p in [DRIVER] if tree.lines(p) is not None]:
        for number, text in enumerate(tree.lines(path) or [], 1):
            if CALLER.search(text) or CALLER_TESTS.search(text):
                findings.append(Finding("L3", path, number, f"the comment names its caller ({text.strip()})", "Delete the comment, or state a why the code cannot show.", "caller"))
            match = DOC_COMMENT.match(text)
            if match and len(match.group(1)) >= MIN_DUPLICATE_LENGTH:
                sites[match.group(1)].append((path, number))
    permitted = {(a.path, a.text) for a in allowed}
    for text, places in sites.items():
        if len({path for path, _ in places}) < 2:
            continue
        for path, number in places:
            if (path, text) in permitted:
                continue
            others = ", ".join(f"{p}:{n}" for p, n in places if (p, n) != (path, number))
            findings.append(Finding("L3", path, number, f"the doc comment is the same as in {others} (## {text})", "Delete the copies, or state a why that is specific to this line.", "duplicate"))
    seen_texts = {(path, text) for text, places in sites.items() for path, _ in places}
    for entry in allowed:
        if (entry.path, entry.text) not in seen_texts:
            findings.append(Finding("L3", entry.path, 1, "an ALLOWED_DUPLICATES entry matches no comment", "Delete the entry from ALLOWED_DUPLICATES in tools/lint.py.", "allow"))
    return sorted(findings, key=lambda f: (f.path, f.line, f.kind))


def lint_l4(tree: Tree) -> list[Finding]:
    findings: list[Finding] = []
    for path in tree.paths("tests/**/*.gd"):
        for number, text in enumerate(tree.lines(path) or [], 1):
            if text.lstrip().startswith("#") or not ASSERT_CALL.search(text):
                continue
            for pattern, what, fix in PINNED_READS:
                if pattern.search(text):
                    findings.append(Finding("L4", path, number, f"the assertion {what}", fix))
    return findings


def state_keys(driver: list[str]) -> list[tuple[str, int]]:
    start = next((i for i, text in enumerate(driver) if text.startswith("func _state(")), None)
    if start is None:
        return []
    keys: list[tuple[str, int]] = []
    depth = 0
    for index in range(start + 1, len(driver)):
        text = driver[index]
        if text.startswith("func "):
            break
        if depth == 1:
            match = re.match(r'\s*"(\w+)"\s*:', text)
            if match:
                keys.append((match.group(1), index + 1))
        assigned = re.match(r'\s*\w+\["(\w+)"\]\s*=', text)
        if assigned and depth == 0:
            keys.append((assigned.group(1), index + 1))
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text.split("#", 1)[0])
        depth += sum(code.count(c) for c in "{[(") - sum(code.count(c) for c in "}])")
        depth = max(depth, 0)
    return keys


def lint_l2b(tree: Tree, must_exist: bool) -> list[Finding]:
    driver = tree.lines(DRIVER)
    skill = tree.lines(SKILL)
    if driver is None or skill is None:
        if must_exist:
            return [Finding("L2b", DRIVER if driver is None else SKILL, 1, "the file the rule reads is missing", "Update DRIVER and SKILL in tools/lint.py to the new path.")]
        return []
    line = next((text for text in skill if text.startswith("State fields:")), None)
    if line is None:
        return [Finding("L2b", SKILL, 1, "SKILL.md has no line that starts with State fields:", "Restore the State fields line, or update the rule in tools/lint.py.")]
    documented = set(re.findall(r"`(\w+)`", line))
    return [
        Finding("L2b", DRIVER, number, f"`{key}` is a _state() key and the State fields line of SKILL.md does not list it", "Add the key to the State fields line in SKILL.md with its meaning.")
        for key, number in state_keys(driver)
        if key not in documented
    ]


def lint_tree(tree: Tree, allowed: tuple[AllowedDuplicate, ...], must_exist: bool) -> list[Finding]:
    return lint_l2b(tree, must_exist) + lint_l3(tree, allowed) + lint_l4(tree)


@dataclass(frozen=True)
class CommitInfo:
    sha: str
    message: str
    changed: dict[str, bool]
    feature_files: frozenset[str]

    def to_json(self) -> str:
        data = {"sha": self.sha, "message": self.message, "changed": self.changed, "feature_files": sorted(self.feature_files)}
        return json.dumps(data, indent=2, sort_keys=True) + "\n"

    @staticmethod
    def from_json(text: str) -> CommitInfo:
        raw: object = json.loads(text)
        if not isinstance(raw, dict):
            raise ValueError("a commit fixture must be a JSON object")
        sha, message, changed, features = raw.get("sha"), raw.get("message"), raw.get("changed"), raw.get("feature_files")
        if not (isinstance(sha, str) and isinstance(message, str) and isinstance(changed, dict) and isinstance(features, list)):
            raise ValueError("a commit fixture needs sha, message, changed, and feature_files")
        flags: dict[str, bool] = {}
        for path, flag in changed.items():
            if not (isinstance(path, str) and isinstance(flag, bool)):
                raise ValueError("changed maps a path to a boolean")
            flags[path] = flag
        names = [name for name in features if isinstance(name, str)]
        return CommitInfo(sha, message, flags, frozenset(names))


def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True).stdout


def code_changes(diff: str) -> dict[str, bool]:
    result: dict[str, bool] = {}
    current = ""
    for text in diff.splitlines():
        header = re.match(r"diff --git a/(\S+) b/(\S+)", text)
        if header:
            current = header.group(2)
            result[current] = False
        elif text[:1] in "+-" and not text.startswith(("+++", "---")):
            body = text[1:].strip()
            if body and not body.startswith("#"):
                result[current] = True
    return result


def commit_info(repo: Path, sha: str) -> CommitInfo:
    has_parent = len(git(repo, "rev-list", "--parents", "-n", "1", sha).split()) > 1
    parent = sha + "^1" if has_parent else EMPTY_TREE
    names = git(repo, "diff", "--name-only", parent, sha).split()
    code = code_changes(git(repo, "diff", "-U0", parent, sha, "--", "game"))
    features = frozenset(p.removeprefix(FEATURES) for p in git(repo, "ls-tree", "-r", "--name-only", sha, "--", FEATURES).split())
    return CommitInfo(sha, git(repo, "log", "-1", "--format=%B", sha), {n: code.get(n, False) for n in names}, features)


def describe(need: tuple[str, ...]) -> str:
    if need == (ANY_FEATURE,):
        return f"any file in {FEATURES} or {SKILL}"
    return ", ".join(FEATURES + n for n in need)


def lint_l1(commit: CommitInfo) -> list[Finding]:
    if "README.md" not in commit.feature_files or TRAILER.search(commit.message):
        return []
    docs = {p.removeprefix(FEATURES) for p in commit.changed if p.startswith(FEATURES)}
    skill_touched = SKILL in commit.changed
    missing: dict[tuple[str, ...], list[str]] = defaultdict(list)
    for path, code in sorted(commit.changed.items()):
        if not path.startswith("game/") or path.endswith(L1_IGNORED) or not code:
            continue
        prefix = max((k for k in FEATURE_MAP if path.startswith(k)), default=None)
        if prefix is None:
            continue
        wanted = FEATURE_MAP[prefix]
        if wanted == [ANY_FEATURE]:
            if not (docs or skill_touched):
                missing[(ANY_FEATURE,)].append(path)
            continue
        names = [w for w in wanted if w in commit.feature_files] or ["<new feature file>"]
        need = set(names) - docs
        if need:
            missing[tuple(sorted(need))].append(path)
    short = commit.sha[:7]
    return [
        Finding(
            "L1",
            paths[0],
            1,
            f"commit {short} changed {', '.join(paths)} and did not change {describe(need)}",
            "Read each file and update it to match the new behavior. If the player-visible behavior is unchanged, "
            "add the commit trailer `Verify-map: unchanged (<reason>)`.",
        )
        for need, paths in missing.items()
    ]


def default_range(repo: Path) -> str | None:
    for base in ("origin/main", "main"):
        if subprocess.run(["git", "-C", str(repo), "rev-parse", "--verify", "-q", base], capture_output=True).returncode == 0:
            return f"{base}..HEAD"
    return None


def parse_expected(text: str) -> set[str]:
    return {line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")}


def run_fixtures() -> tuple[list[str], int]:
    out: list[str] = []
    failures = 0
    for kind in ("bad", "good"):
        for case in sorted(p for p in (FIXTURES / kind).iterdir() if p.is_dir()):
            name = f"{kind}/{case.name}"
            expected = parse_expected((case / "expect.txt").read_text(encoding="utf-8"))
            found: list[Finding] = []
            if (case / "commit.json").is_file():
                found += lint_l1(CommitInfo.from_json((case / "commit.json").read_text(encoding="utf-8")))
            if (case / "tree").is_dir():
                found += lint_tree(Tree(case / "tree", FIXTURE_SUFFIX), (), must_exist=False)
            got = {f.key(): f for f in found}
            problems = [f"FAIL lint fixture {name}: expected {k} and the rule did not report it. The rule no longer catches this bad commit." for k in sorted(expected - got.keys())]
            problems += [f"FAIL lint fixture {name}: reported {k}, which expect.txt does not list. Fix the rule, or list the finding in expect.txt." for k in sorted(got.keys() - expected)]
            if kind == "bad" and not expected:
                problems.append(f"FAIL lint fixture {name}: a bad fixture must expect at least one finding.")
            if problems:
                failures += 1
                out += problems
                continue
            out.append(f"OK: lint fixture {name}: {len(got)} expected finding(s)" if got else f"OK: lint fixture {name}: no findings")
            out += [f"  caught {f.rule} {f.path}:{f.line}: {f.what}. {f.fix}" for f in found]
    return out, failures


def cmd_check(repo: Path, commit_range: str | None) -> int:
    findings = lint_tree(Tree(repo), ALLOWED_DUPLICATES, must_exist=True)
    scope = commit_range or default_range(repo)
    checked = 0
    if scope is not None:
        for sha in reversed(git(repo, "log", "--no-merges", "--format=%H", scope).split()):
            findings += lint_l1(commit_info(repo, sha))
            checked += 1
    for finding in findings:
        print(finding.render())
    if findings:
        return 1
    print(f"OK: lint (L2b, L3, L4 on the tree; L1 on {checked} commit(s) in {scope or 'no range, no main branch found'})")
    lines, failures = run_fixtures()
    print("\n".join(lines))
    return 1 if failures else 0


def cmd_l1(repo: Path, sha: str) -> int:
    findings = lint_l1(commit_info(repo, sha))
    print("\n".join(f.render() for f in findings) or f"OK: lint L1 {sha}")
    return 1 if findings else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Repo lint with fixtures that replay each bad commit.")
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="the repository to read (default: the current directory)")
    sub = parser.add_subparsers(dest="command")
    check = sub.add_parser("check", help="run every rule on the repo, then on the fixtures (the default)")
    check.add_argument("--range", dest="commit_range", help="the commits for L1 (default: origin/main..HEAD)")
    l1 = sub.add_parser("l1", help="run rule L1 on one commit of the repo")
    l1.add_argument("sha")
    capture = sub.add_parser("capture-l1", help="write the L1 facts of one commit as a fixture")
    capture.add_argument("sha")
    capture.add_argument("out", type=Path)
    args = parser.parse_args()
    repo: Path = Path(git(args.repo, "rev-parse", "--show-toplevel").strip())
    if args.command == "l1":
        return cmd_l1(repo, args.sha)
    if args.command == "capture-l1":
        args.out.write_text(commit_info(repo, args.sha).to_json(), encoding="utf-8")
        return 0
    return cmd_check(repo, getattr(args, "commit_range", None))


if __name__ == "__main__":
    sys.exit(main())
