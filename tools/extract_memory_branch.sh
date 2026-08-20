#!/usr/bin/env bash
#
# Publish the MEMORY app (دفتر خاطرات و تولد) as a standalone branch.
#
# The app currently lives in memory/ next to ROOZI. This lifts it to the root
# of its own branch — app/, ci/, tools/ — with a single clean commit and no
# ROOZI or Factor-Roobi history behind it.
#
# WHY A SCRIPT RATHER THAN A FEW GIT COMMANDS
# The agent session that built the app is pinned to one branch and cannot push
# anywhere else, so this has to be run by a human. Doing it by hand means
# retyping ~20 commands including a `git checkout --orphan`, where one typo in
# the wrong order can wipe the working tree. This is the same sequence, tested.
#
# SAFETY
#   * Never touches the source branch. It only reads it, via `git worktree`.
#   * Refuses to run if the branch already exists, unless --force.
#   * Refuses to run with uncommitted changes.
#   * Builds everything in a temporary directory; on failure nothing is pushed.
#   * Pushing is opt-in (--push). By default it only creates the local branch,
#     so you can inspect it before anything leaves your machine.
#
# USAGE
#   bash tools/extract_memory_branch.sh                  # create locally
#   bash tools/extract_memory_branch.sh --push           # create and push
#   bash tools/extract_memory_branch.sh --branch my-name --push
#
set -euo pipefail

BRANCH="memory-app"
SOURCE_REF="HEAD"
DO_PUSH=0
FORCE=0
REMOTE="origin"

while [ $# -gt 0 ]; do
    case "$1" in
        --branch) BRANCH="$2"; shift 2 ;;
        --from)   SOURCE_REF="$2"; shift 2 ;;
        --remote) REMOTE="$2"; shift 2 ;;
        --push)   DO_PUSH=1; shift ;;
        --force)  FORCE=1; shift ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# --- Preconditions --------------------------------------------------------

if [ -n "$(git status --porcelain)" ]; then
    fail "You have uncommitted changes. Commit or stash them first."
fi

if ! git rev-parse --verify --quiet "$SOURCE_REF^{commit}" >/dev/null; then
    fail "No such ref: $SOURCE_REF"
fi

# Run from the wrong branch this would otherwise fail deep inside the copy
# step with a confusing message, so it is caught up front with the fix.
if ! git cat-file -e "$SOURCE_REF:memory/app/build.gradle.kts" 2>/dev/null; then
    CURRENT=$(git branch --show-current 2>/dev/null || echo "detached HEAD")
    printf '\033[31mERROR: the memory app is not on this branch (%s).\033[0m\n' "$CURRENT" >&2
    printf '\nSwitch to the branch that has it, then run this again:\n' >&2
    printf '  git fetch origin\n' >&2
    printf '  git switch arena/01a002a3-kamand\n' >&2
    printf '  bash tools/extract_memory_branch.sh\n\n' >&2
    exit 1
fi

if git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
    if [ "$FORCE" -eq 1 ]; then
        say "Branch '$BRANCH' exists; --force given, it will be replaced."
        git branch -D "$BRANCH"
    else
        fail "Branch '$BRANCH' already exists. Pass --force to replace it."
    fi
fi

STAGE="$(mktemp -d)"
# A worktree is used instead of copying files so the extraction reads the
# committed tree, never whatever happens to be lying in the working directory.
WORKTREE="$STAGE/src"
BUILD="$STAGE/build"
cleanup() {
    git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    rm -rf "$STAGE"
}
trap cleanup EXIT

say "1/6  Reading $SOURCE_REF into a temporary worktree"
git worktree add --detach --quiet "$WORKTREE" "$SOURCE_REF"

say "2/6  Laying out the new root"
mkdir -p "$BUILD"
# The app module moves up: memory/app -> app, memory/ci -> ci, and so on.
cp -a "$WORKTREE/memory/." "$BUILD/"
# Shared tooling comes along: the app's own README tells you to run it.
cp -a "$WORKTREE/tools" "$BUILD/tools"
# ROOZI-only helpers would be dead weight on a branch with no ROOZI in it.
# gen_widget_preview.py in particular renders a widget this app does not have,
# and gen_icons.py hardcodes a roozi/ output path that no longer exists.
rm -f "$BUILD/tools/fork_app.py" \
      "$BUILD/tools/set_launcher_icon.py" \
      "$BUILD/tools/gen_widget_preview.py" \
      "$BUILD/tools/gen_icons.py" \
      "$BUILD/tools/extract_memory_branch.sh"
rm -rf "$BUILD/tools/__pycache__"

say "3/6  Repointing paths at the new root"
python3 - "$BUILD" <<'PYEOF'
import os
import re
import sys

build = sys.argv[1]

def edit(rel, fn):
    path = os.path.join(build, rel)
    if not os.path.exists(path):
        return
    text = open(path, encoding="utf-8").read()
    new = fn(text)
    if new != text:
        open(path, "w", encoding="utf-8").write(new)

# The static checkers take --module; at the root the module IS the root.
# Their prose still describes ROOZI, which would be misleading on a branch
# where ROOZI does not exist.
def fix_tool(t):
    t = (t.replace('default="roozi"', 'default="."')
          .replace('module_paths("roozi")', 'module_paths(".")')
          .replace('module_root("roozi")', 'module_root(".")')
          .replace('app module directory (default: roozi)',
                   'app module directory (default: the repository root)'))
    t = t.replace("""Cross-file call-site checker for the ROOZI Kotlin sources.""",
                  """Cross-file call-site checker for the MEMORY Kotlin sources.""")
    t = t.replace("""Static checks for the ROOZI Android module.""",
                  """Static checks for the MEMORY Android module.""")
    t = t.replace("""The same checks apply to any app forked out of ROOZI, so the module directory
is selectable with --module (default: roozi).""",
                  """The module directory is selectable with --module; it defaults to the
repository root, where this app lives.""")
    t = t.replace("""Apps forked out of ROOZI reuse the same rules, so the module directory is
selectable with --module (default: roozi).""",
                  """The module directory is selectable with --module; it defaults to the
repository root, where this app lives.""")
    t = t.replace("(RooziApp, MemoryApp)", "(MemoryApp)")
    return t

for tool in ("verify_resources.py", "check_callsites.py"):
    edit(os.path.join("tools", tool), fix_tool)

# CI no longer builds from a subdirectory.
def fix_ci(t):
    t = t.replace("        working-directory: memory\n", "")
    t = re.sub(r"^    defaults:\n      run:\n\n", "", t, flags=re.M)
    t = t.replace("          path: memory/app/build/", "          path: app/build/")
    t = t.replace("            memory/app/build/reports/", "            app/build/reports/")
    # This branch is not the agent's branch; build whatever is pushed to it.
    t = re.sub(
        r"  push:\n    branches:\n(?:      - \"[^\"]+\"\n)+",
        "  push:\n    branches:\n      - \"**\"\n",
        t,
    )
    return t

edit(os.path.join("ci", "memory-android.yml"), fix_ci)

# README instructions were written for a nested module.
def fix_readme(t):
    t = t.replace("python3 ../tools/", "python3 tools/")
    t = t.replace("--module memory", "")
    t = t.replace("cd memory\n", "")
    t = t.replace(
        "روش ساخت در `../FORKING.md`.",
        "این برنچ فقط شامل همین اپ است.",
    )
    t = t.replace("`memory/preview/index.html`", "`preview/index.html`")
    t = t.replace("فایل ورک‌فلوی آماده در `ci/memory-android.yml`",
                  "فایل ورک‌فلوی آماده در `ci/memory-android.yml`")
    return re.sub(r"[ \t]+\n", "\n", t)

edit("README.md", fix_readme)

# .gitignore came from a two-app repo.
gitignore = """# Gradle / Android
.gradle/
build/
app/build/
local.properties
captures/
*.apk
*.aab
*.ap_
*.dex

# Signing secrets - never commit
keystore.properties
*.jks
*.keystore

# IDE / OS
.idea/
.vscode/
*.iml
*.swp
*.swo
.DS_Store
Thumbs.db

# Python tooling
__pycache__/
"""
open(os.path.join(build, ".gitignore"), "w", encoding="utf-8").write(gitignore)
PYEOF

say "4/6  Verifying the extracted tree"
( cd "$BUILD" && python3 tools/verify_resources.py ) || fail "resource check failed"
( cd "$BUILD" && python3 tools/check_callsites.py )  || fail "call-site check failed"
[ -f "$BUILD/app/build.gradle.kts" ] || fail "app/build.gradle.kts missing"
[ -f "$BUILD/settings.gradle.kts" ]  || fail "settings.gradle.kts missing"
[ -f "$BUILD/gradlew" ]              || fail "gradlew missing"
[ -x "$BUILD/gradlew" ]              || chmod +x "$BUILD/gradlew"
if grep -rql "com\.roozi\.app" "$BUILD" 2>/dev/null; then
    fail "ROOZI package references survived the extraction"
fi
# One comment in MemoryDatabase.kt legitimately explains why the schema starts
# at v1 by naming the project it came from; anything else is a leftover.
STRAY=$(grep -ril "roozi" "$BUILD" 2>/dev/null \
        | grep -v "app/src/main/java/com/studiojavid/memory/data/local/MemoryDatabase.kt" || true)
if [ -n "$STRAY" ]; then
    fail "unexpected ROOZI references remain in: $STRAY"
fi

say "5/6  Creating branch '$BRANCH' (single commit, no prior history)"
git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
ORPHAN="$STAGE/orphan"
git worktree add --detach --quiet "$ORPHAN" "$SOURCE_REF"
(
    cd "$ORPHAN"
    git checkout --orphan "$BRANCH" --quiet
    git rm -rq --cached . 2>/dev/null || true
    find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    cp -a "$BUILD/." .
    git add -A
    git commit -q -F - <<'MSGEOF'
دفتر خاطرات و تولد | MEMORY

Persian diary, birthday book and notes app for Android.
Kotlin, Jetpack Compose, Material 3, Room, real Jalali calendar, full RTL.

One page per day, keyed by its civil date: reopening a day edits that page
instead of stacking a second one. Each page carries a mood, optional tags and
one photo; the mood colour is the accent of both the card and the calendar
cell, so a month reads as a mood map before a single word is read.

Photos go through the Photo Picker, which needs no storage permission, and are
copied into app-private storage because a gallery Uri grant does not survive a
reboot. The repository owns those files: an image orphaned by a deleted page
would grow app storage forever.

"On this day" looks back at the same *Jalali* day in earlier years and skips
years that do not have it, so 30 Esfand never slides onto the 29th.

Birthdays get their own tab with countdowns, ages, greetings and gift ideas,
reminded by an exact alarm with a WorkManager backstop. Backup covers diary,
notes and birthdays alike: a birthday is typed once and, if lost, is never
reminded again.

The Jalali engine, RTL design system, Room layer and signed-release CI are
carried over from the ROOZI project; the schema starts at version 1 because
this app has never shipped.
MSGEOF
)
git worktree remove --force "$ORPHAN" >/dev/null 2>&1 || true

say "6/6  Done"
COMMIT=$(git rev-parse --short "$BRANCH")
FILES=$(git ls-tree -r --name-only "$BRANCH" | wc -l | tr -d ' ')
echo "  branch : $BRANCH"
echo "  commit : $COMMIT (no parents)"
echo "  files  : $FILES"

if [ "$DO_PUSH" -eq 1 ]; then
    say "Pushing to $REMOTE/$BRANCH"
    git push -u "$REMOTE" "$BRANCH"
    echo
    echo "Now copy ci/memory-android.yml to .github/workflows/ on that branch"
    echo "through the GitHub web editor to get signed APK/AAB builds."
else
    say "Nothing was pushed. Inspect it first:"
    echo "  git log --stat $BRANCH | head -40"
    echo "  git switch $BRANCH"
    echo
    echo "When it looks right:"
    echo "  git push -u $REMOTE $BRANCH"
fi
