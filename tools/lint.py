#!/usr/bin/env python3
"""Repo lint.

L1   a commit changed game code and not the feature file the verify skill maps to it. The map is the
     Code column of the features table in the verify skill's features/README.md.
L1m  the map cannot be read, or a path in that Code column does not exist, or a file under game/ has no Code path.
L2b  a key of the verify driver's _state() is missing from the State fields line of SKILL.md.
L3   a doc comment names its caller, or the same doc comment sits in two files.
L4   a test asserts a pinned read: a collision bit, a binding count, or a node list index.
     It reads one line. A read split over several lines, or held in a local variable first, is not caught.

A fixture file ends in .fixture so Godot and the parse check skip it.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
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
L1_IGNORED = (".uid", ".gdshader", ".tres", "lamp.tscn", "game/layers.gd", "game/main.tscn")
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
TRAILER = re.compile(r"^Verify-map: unchanged \(.+\)$")

CALLER = re.compile(
    r"^##?\s.*\b(?:[A-Z_][\w.]*|_\w+|[a-z_]+\(\))\s+(?:(?:also|only)\s+)?"
    r"(?:sets?|calls?|seeds?|reads?|uses?|connects?|overrides?|replaces?)\s+(?:it|this|them|these)\b"
)
CALLER_TESTS = re.compile(r"^##?\s.*\b(?:[Tt]ests?|[Cc]allers?)\s+(?:call|set|seed|read|use|write)\b")
CALLER_PASSIVE = re.compile(r"^##?\s.*\b(?:[Cc]alled|[Ss]et|[Uu]sed|[Rr]ead|[Ss]eeded|[Cc]onnected|[Oo]verridden)\s+by\s+\S")
DOC_COMMENT = re.compile(r"^\s*##\s*(.+?)\s*$")
MIN_DUPLICATE_LENGTH = 12

ASSERT_CALL = re.compile(r"\b(?:check|ok|eq|near|between)\(")
PINNED_READS: list[tuple[str, re.Pattern[str], str, str]] = [
    (
        "collision-bit",
        re.compile(r"\bcollision_(?:layer|mask)\b"),
        "reads a collision bit",
        "Assert what the player observes: the prompt, the interact result, a ray hit, or movement.",
    ),
    (
        "binding-count",
        re.compile(r"InputMap\.action_get_events\([^)]*\)\.size\(\)"),
        "counts the bindings of an action",
        "Press the binding and assert that the action fires.",
    ),
    (
        "binding-empty",
        re.compile(r"InputMap\.action_get_events\([^)]*\)\.is_empty\(\)"),
        "checks that an action has a binding",
        "Press the binding and assert that the action fires.",
    ),
    (
        "node-index",
        re.compile(r"\b(?:stations|machines|spawns\(\)|get_children\(\)|zones|children)\[\d+\]"),
        "indexes a node list by a literal",
        "Find the node by type or name, not by its place in the scene.",
    ),
    (
        "child-index",
        re.compile(r"\bget_child\(\d+\)"),
        "reads a child by a literal index",
        "Find the node by type, name, or text, not by its place in the scene.",
    ),
    (
        "group-index",
        re.compile(r"\bget_nodes_in_group\([^)]*\)\[\d+\]"),
        "indexes a group by a literal",
        "Find the node by type or name, not by its place in the group.",
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
_AREA_DEPTH = "The interact area stands out from the wall, so the ray finds it before the wall."
_BUILD_REASON = "The same doc comment sits on the _built variable of each script that has a _build(). PR 8 removes every entry of this table and its _built variables."
_AREA_REASON = "The same doc comment sits on the AREA_DEPTH constant of machine.gd and wall_buy.gd. PR 8 removes every entry of this table and keeps one copy."
ALLOWED_DUPLICATES: tuple[AllowedDuplicate, ...] = (
    AllowedDuplicate("game/level/sigil.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/cache.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/door.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/machine.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/power_switch.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/wall_buy.gd", _BUILD_CHILDREN, _BUILD_REASON),
    AllowedDuplicate("game/station/machine.gd", _AREA_DEPTH, _AREA_REASON),
    AllowedDuplicate("game/station/wall_buy.gd", _AREA_DEPTH, _AREA_REASON),
)


class Tree:
    def __init__(self, root: Path, suffix: str = "") -> None:
        self.root = root
        self.suffix = suffix

    def paths(self, pattern: str) -> list[str]:
        found = self.root.glob(pattern + self.suffix)
        return sorted(p.relative_to(self.root).as_posix().removesuffix(self.suffix) for p in found if p.is_file())

    def exists(self, path: str) -> bool:
        if path.endswith("/"):
            return (self.root / path).is_dir()
        return (self.root / (path + self.suffix)).is_file()

    def lines(self, path: str) -> list[str] | None:
        file = self.root / (path + self.suffix)
        return file.read_text(encoding="utf-8").splitlines() if file.is_file() else None


def split_comment(text: str) -> str | None:
    quote = ""
    index = 0
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = ""
        elif char in "\"'":
            quote = char
        elif char == "#":
            return text[index:]
        index += 1
    return None


def lint_l3(tree: Tree, allowed: tuple[AllowedDuplicate, ...]) -> list[Finding]:
    findings: list[Finding] = []
    sites: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for path in tree.paths("game/**/*.gd") + [p for p in [DRIVER] if tree.lines(p) is not None]:
        for number, text in enumerate(tree.lines(path) or [], 1):
            comment = split_comment(text)
            if comment is not None and (CALLER.search(comment) or CALLER_TESTS.search(comment) or CALLER_PASSIVE.search(comment)):
                findings.append(Finding("L3", path, number, f"the comment names its caller ({comment})", "Delete the comment, or state a why the code cannot show.", "caller"))
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
            for name, pattern, what, fix in PINNED_READS:
                if pattern.search(text):
                    findings.append(Finding("L4", path, number, f"the assertion {what}", fix, name))
    return findings


STATE_FUNC = re.compile(r"^(?:static\s+)?func _state\(")
TOP_LEVEL = re.compile(r"^(?:(?:static\s+)?(?:func|var|const|class|signal|enum)\b|@)")


def state_keys(driver: list[str]) -> list[tuple[str, int]]:
    start = next((i for i, text in enumerate(driver) if STATE_FUNC.match(text)), None)
    if start is None:
        return []
    keys: list[tuple[str, int]] = []
    depth = 0
    for index in range(start, len(driver)):
        text = driver[index]
        if index > start and TOP_LEVEL.match(text):
            break
        quote = ""
        begin = 0
        position = 0
        while position < len(text):
            char = text[position]
            if quote:
                if char == "\\":
                    position += 1
                elif char == quote:
                    quote = ""
                    literal = text[begin + 1 : position]
                    before, after = text[:begin], text[position + 1 :]
                    is_key = depth == 1 and re.match(r"\s*:", after) is not None
                    is_assign = depth == 0 and re.search(r"\w\[$", before) is not None and re.match(r"\]\s*=(?!=)", after) is not None
                    if re.fullmatch(r"\w+", literal) and (is_key or is_assign):
                        keys.append((literal, index + 1))
            elif char in "\"'":
                quote, begin = char, position
            elif char == "#":
                break
            elif char in "{[(":
                depth += 1
            elif char in "}])":
                depth = max(depth - 1, 0)
            position += 1
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
    keys = state_keys(driver)
    if not keys:
        return [Finding("L2b", DRIVER, 1, "the rule found no _state() function, or no key in it", "Keep a `func _state(` in the driver that returns a dictionary literal with string keys, or update state_keys in tools/lint.py.")]
    return [
        Finding("L2b", DRIVER, number, f"`{key}` is a _state() key and the State fields line of SKILL.md does not list it", "Add the key to the State fields line in SKILL.md with its meaning.", key)
        for key, number in keys
        if key not in documented
    ]


def lint_tree(tree: Tree, allowed: tuple[AllowedDuplicate, ...], must_exist: bool) -> list[Finding]:
    return lint_l2b(tree, must_exist) + lint_l3(tree, allowed) + lint_l4(tree) + lint_l1_map(tree)


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


def clean_env() -> dict[str, str]:
    """Git exports GIT_DIR and related variables to hooks. A child git that inherits them acts on the hook's repository, not the one named by -C."""
    return {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True, env=clean_env()).stdout


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


def has_verify_trailer(message: str) -> bool:
    parsed = subprocess.run(["git", "interpret-trailers", "--parse"], input=message, capture_output=True, text=True, check=True, env=clean_env()).stdout
    return any(TRAILER.match(line) for line in parsed.splitlines())


def absent_note(need: tuple[str, ...], commit: CommitInfo) -> str:
    absent = [FEATURES + n for n in need if n != ANY_FEATURE and n not in commit.feature_files]
    return f" (create {', '.join(absent)} and list it in {FEATURES}README.md)" if absent else ""


FeatureMap = dict[str, list[str]]
TABLE_LINK = re.compile(r"\]\(([^)\s]+)\)")
CELL_SPLIT = re.compile(r"(?<!\\)\|")
SEPARATOR_CELL = re.compile(r":?-+:?")
ROW_FIX = "Write the File cell as a link such as [name.md](name.md) and the Code cell as paths in backticks, or `none`. Write a pipe inside a cell as \\|."


@dataclass(frozen=True)
class MapRow:
    line: int
    name: str
    problem: str


def split_cells(text: str) -> list[str]:
    body = text.strip().removeprefix("|")
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [c.replace("\\|", "|").strip() for c in CELL_SPLIT.split(body)]


def header_name(cell: str) -> str:
    return re.sub(r"[*_`\s]", "", cell).lower()


def feature_target(href: str) -> str | None:
    if href == "../SKILL.md":
        return ANY_FEATURE
    name = href.removeprefix("./")
    if name.endswith(".md") and re.fullmatch(r"[\w-]+(?:/[\w-]+)*\.md", name):
        return name
    return None


def parse_feature_map(lines: list[str]) -> tuple[FeatureMap, list[tuple[str, int]], list[MapRow]]:
    result: FeatureMap = {}
    named: list[tuple[str, int]] = []
    bad: list[MapRow] = []
    columns: tuple[int, int] | None = None
    for number, raw in enumerate(lines, 1):
        text = raw.strip()
        if not text.startswith("|"):
            if columns is not None and text and CELL_SPLIT.search(text):
                bad.append(MapRow(number, text[:40], "the row does not start with a pipe"))
            else:
                columns = None
            continue
        cells = split_cells(text)
        if all(SEPARATOR_CELL.fullmatch(c) for c in cells if c) and any(cells):
            continue
        if columns is None:
            names = [header_name(c) for c in cells]
            if "code" in names and "file" in names:
                columns = (names.index("file"), names.index("code"))
            continue
        file_column, code_column = columns
        label = cells[0][:40]
        if max(file_column, code_column) >= len(cells):
            bad.append(MapRow(number, label, "the row has fewer cells than the header"))
            continue
        link = TABLE_LINK.search(cells[file_column])
        if link is None:
            bad.append(MapRow(number, label, "the File cell has no link"))
            continue
        target = feature_target(link.group(1))
        if target is None:
            bad.append(MapRow(number, label, f"the File cell links to {link.group(1)}, which is not a feature file"))
            continue
        paths = re.findall(r"`([^`]+)`", cells[code_column])
        if not paths and header_name(cells[code_column]) != "none":
            bad.append(MapRow(number, label, "the Code cell has no path in backticks and is not `none`"))
            continue
        for path in paths:
            result.setdefault(path, [])
            if target not in result[path]:
                result[path].append(target)
            named.append((path, number))
    return result, named, bad


def load_feature_map(tree: Tree) -> FeatureMap:
    lines = tree.lines(FEATURES + "README.md")
    return parse_feature_map(lines)[0] if lines is not None else {}


def lint_l1_map(tree: Tree, must_exist: bool = False) -> list[Finding]:
    where = FEATURES + "README.md"
    lines = tree.lines(where)
    if lines is None:
        if must_exist:
            return [Finding("L1m", where, 1, "the feature map file is missing, so L1 has no map", "Restore the file, or update FEATURES in tools/lint.py to its new path.")]
        return []
    mapping, named, bad = parse_feature_map(lines)
    findings = [
        Finding("L1m", where, row.line, f"the row `{row.name}` cannot be read: {row.problem}", ROW_FIX, "row")
        for row in bad
    ]
    if not mapping:
        return findings + [Finding("L1m", where, 1, "the features table has no Code column with paths, so L1 has no map", "Add a Code column to the features table, with the paths of each feature in backticks.")]
    findings += [
        Finding("L1m", where, number, f"the Code column names {path}, which does not exist", "Fix the path, or delete it from the Code column.", path)
        for path, number in named
        if not tree.exists(path)
    ]
    findings += [
        Finding("L1m", where, 1, f"{path} is under game/ and no path in the Code column covers it", f"Add {path} or its folder to the Code column of a row in {where}. If a change to it needs no feature file, add it to L1_IGNORED in tools/lint.py.", path)
        for path in tree.paths("game/**/*")
        if not path.endswith(L1_IGNORED) and not any(path.startswith(k) for k in mapping)
    ]
    return findings


def lint_l1(commit: CommitInfo, feature_map: FeatureMap) -> list[Finding]:
    if "README.md" not in commit.feature_files or has_verify_trailer(commit.message):
        return []
    docs = {p.removeprefix(FEATURES) for p in commit.changed if p.startswith(FEATURES)}
    skill_touched = SKILL in commit.changed
    missing: dict[tuple[str, ...], list[str]] = defaultdict(list)
    for path, code in sorted(commit.changed.items()):
        if not path.startswith("game/") or path.endswith(L1_IGNORED) or not code:
            continue
        prefix = max((k for k in feature_map if path.startswith(k)), default=None)
        if prefix is None:
            continue
        wanted = feature_map[prefix]
        if wanted == [ANY_FEATURE]:
            if not (docs or skill_touched):
                missing[(ANY_FEATURE,)].append(path)
            continue
        names = [w for w in wanted if w in commit.feature_files] or wanted
        need = set(names) - docs
        if need:
            missing[tuple(sorted(need))].append(path)
    short = commit.sha[:7]
    return [
        Finding(
            "L1",
            paths[0],
            1,
            f"commit {short} changed {', '.join(paths)} and did not change {describe(need)}{absent_note(need, commit)}",
            "Read each file and update it to match the new behavior. If the player-visible behavior is unchanged, "
            "add the commit trailer `Verify-map: unchanged (<reason>)` as the last paragraph of the message.",
            "any" if need == (ANY_FEATURE,) else "+".join(need),
        )
        for need, paths in missing.items()
    ]


def git_ok(repo: Path, *args: str) -> bool:
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, env=clean_env()).returncode == 0


def resolve_range(repo: Path, commit_range: str | None) -> tuple[str | None, list[Finding]]:
    where = FEATURES + "README.md"
    if not (repo / where).is_file():
        return None, [Finding("L1", where, 1, "the feature map file is missing, so L1 cannot run", "Restore the file, or update FEATURES in tools/lint.py to its new path.")]
    if git(repo, "rev-parse", "--is-shallow-repository").strip() == "true":
        return None, [Finding("L1", ".git", 1, "the repository is shallow, so L1 cannot see the commits", "Run `git fetch --unshallow origin main`. In CI, set `fetch-depth: 0` on the checkout step.")]
    if commit_range is not None:
        return commit_range, []
    for base in ("origin/main", "main"):
        if git_ok(repo, "rev-parse", "--verify", "-q", base):
            return f"{base}..HEAD", []
    return None, [Finding("L1", ".git", 1, "no origin/main or main ref exists, so L1 has no base to compare with", "Run `git fetch origin main`, or pass `--range <base>..HEAD`. In CI, set `fetch-depth: 0` on the checkout step.")]


def parse_expected(text: str) -> set[str]:
    return {line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")}


def run_fixtures(feature_map: FeatureMap) -> tuple[list[str], int]:
    out: list[str] = []
    failures = 0
    for kind in ("bad", "good"):
        for case in sorted(p for p in (FIXTURES / kind).iterdir() if p.is_dir()):
            name = f"{kind}/{case.name}"
            expected = parse_expected((case / "expect.txt").read_text(encoding="utf-8"))
            found: list[Finding] = []
            if (case / "commit.json").is_file():
                found += lint_l1(CommitInfo.from_json((case / "commit.json").read_text(encoding="utf-8")), feature_map)
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


def env_repo(base: Path, name: str, *, readme: bool, branch: str) -> Path:
    repo = base / name
    repo.mkdir()
    git(repo, "init", "-q", "-b", branch)
    git(repo, "config", "user.email", "lint@example.com")
    git(repo, "config", "user.name", "lint")
    if readme:
        (repo / FEATURES).mkdir(parents=True)
        (repo / FEATURES / "README.md").write_text("x\n", encoding="utf-8")
    (repo / "a.txt").write_text("a\n", encoding="utf-8")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "first")
    return repo


def run_env_cases() -> tuple[list[str], int]:
    out: list[str] = []
    failures = 0
    with tempfile.TemporaryDirectory() as raw:
        base = Path(raw)
        source = env_repo(base, "source", readme=True, branch="main")
        (source / "b.txt").write_text("b\n", encoding="utf-8")
        git(source, "add", "-A")
        git(source, "commit", "-q", "-m", "second")
        subprocess.run(["git", "clone", "-q", "--depth", "1", source.as_uri(), str(base / "shallow")], check=True, capture_output=True, env=clean_env())
        cases: dict[str, tuple[Path, str]] = {
            "no base ref": (env_repo(base, "nobase", readme=True, branch="trunk"), "no origin/main or main ref"),
            "shallow clone": (base / "shallow", "the repository is shallow"),
            "missing feature map": (env_repo(base, "nomap", readme=False, branch="main"), "the feature map file is missing"),
            "empty range": (source, ""),
        }
        for name, (repo, expected) in cases.items():
            scope, found = resolve_range(repo, None)
            messages = " ".join(f.what + " " + f.fix for f in found)
            if expected and expected in messages and scope is None:
                out.append(f"OK: lint env case {name}: fails with a message that names the fix")
            elif not expected and not found and scope == "main..HEAD" and not git(repo, "log", "--format=%H", "main..HEAD").split():
                out.append(f"OK: lint env case {name}: an empty range passes and the summary says it is empty")
            else:
                failures += 1
                out.append(f"FAIL lint env case {name}: expected `{expected or 'no finding'}`, got scope {scope} and findings: {messages}")
        sentinel = env_repo(base, "sentinel", readme=True, branch="main")
        sentinel_config = sentinel / ".git" / "config"
        config_before = sentinel_config.read_text(encoding="utf-8")
        hook_env = {"GIT_DIR": str(sentinel / ".git"), "GIT_WORK_TREE": str(sentinel), "GIT_INDEX_FILE": str(sentinel / ".git" / "index")}
        saved = {key: os.environ.get(key) for key in hook_env}
        os.environ.update(hook_env)
        try:
            env_repo(base, "inherited", readme=True, branch="main")
        finally:
            for key, value in saved.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        if sentinel_config.read_text(encoding="utf-8") == config_before and (base / "inherited" / ".git").is_dir():
            out.append("OK: lint env case inherited GIT_DIR: a temp repo ignores the hook's repository variables")
        else:
            failures += 1
            out.append("FAIL lint env case inherited GIT_DIR: a temp repo wrote to the repository named by GIT_DIR. Run every git child with clean_env().")
        l1_cases: dict[str, tuple[Path, str]] = {
            "l1 with no Code column": (source, "no Code column with paths"),
            "l1 with no feature map file": (base / "nomap", "the feature map file is missing"),
        }
        for name, (repo, expected) in l1_cases.items():
            messages = " ".join(f.what + " " + f.fix for f in l1_findings(repo, "HEAD"))
            if expected in messages:
                out.append(f"OK: lint env case {name}: fails with a message that names the fix")
            else:
                failures += 1
                out.append(f"FAIL lint env case {name}: expected `{expected}`, got: {messages or 'no finding'}")
    return out, failures


def cmd_check(repo: Path, commit_range: str | None) -> int:
    findings = lint_tree(Tree(repo), ALLOWED_DUPLICATES, must_exist=True)
    feature_map = load_feature_map(Tree(repo))
    scope, problems = resolve_range(repo, commit_range)
    findings += problems
    checked = 0
    if scope is not None:
        try:
            shas = git(repo, "log", "--no-merges", "--format=%H", scope).split()
        except subprocess.CalledProcessError as error:
            findings.append(Finding("L1", ".git", 1, f"git cannot list the range {scope} ({error.stderr.strip()})", "Fetch the base branch, or pass a range that exists."))
            shas = []
        for sha in reversed(shas):
            findings += lint_l1(commit_info(repo, sha), feature_map)
            checked += 1
    for finding in findings:
        print(finding.render())
    if findings:
        return 1
    print(f"OK: lint (L1m, L2b, L3, L4 on the tree; L1 on {checked} commit(s) in {scope}{'; the range is empty, so HEAD adds nothing over its base' if checked == 0 else ''})")
    lines, failures = run_fixtures(feature_map)
    env_lines, env_failures = run_env_cases()
    print("\n".join(lines + env_lines))
    return 1 if failures or env_failures else 0


def l1_findings(repo: Path, sha: str) -> list[Finding]:
    tree = Tree(repo)
    return lint_l1_map(tree, must_exist=True) + lint_l1(commit_info(repo, sha), load_feature_map(tree))


def cmd_l1(repo: Path, sha: str) -> int:
    findings = l1_findings(repo, sha)
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
