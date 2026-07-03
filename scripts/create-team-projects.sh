#!/usr/bin/env bash
#
# --- USAGE-START ---  (sentinel for usage(); do not remove)
# create-team-projects.sh -- Generate one project per Agency team for
# Claude Code, GitHub Copilot, and/or Antigravity.
#
# For every division (team) in the repo this creates <dest>/<team>/ containing,
# per selected tool:
#   claude-code   .claude/agents/*.md            + CLAUDE.md charter
#   copilot       .github/agents/*.md            + .github/copilot-instructions.md
#   antigravity   .agents/skills/agency-*/SKILL.md + AGENTS.md charter
#
# Open a generated folder in the matching tool and that team's agents load
# project-locally -- no global install required. One folder can serve all
# three tools at once (--tool all).
#
# Usage:
#   ./scripts/create-team-projects.sh [options]
#
# Options:
#   --tool <a,b>       claude-code, copilot, antigravity, or all
#                      (default: claude-code)
#   --dest <dir>       Where to create the projects (default: ~/AgencyTeams)
#   --division <a,b>   Only these teams (comma-separated; default: all)
#   --link             Symlink agent files instead of copying (updates propagate)
#   --force            Overwrite existing charter files (agents always refreshed)
#   --no-convert       Don't auto-run convert.sh when antigravity skills are missing
#   --dry-run          Print the plan and exit without writing anything
#   --help             Show this help
# --- USAGE-END ---
#
# Platform support: Linux, macOS (bash 3.2+), Windows Git Bash / WSL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTEGRATIONS="$REPO_ROOT/integrations"

# Shared helpers (get_field, agent_slug, is_agent_file, slugify, incr)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if supports_color; then
  C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[0;31m'
  C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''; C_DIM=''; C_RESET=''
fi
ok()     { printf "${C_GREEN}[OK]${C_RESET}  %s\n" "$*"; }
warn()   { printf "${C_YELLOW}[!!]${C_RESET}  %s\n" "$*"; }
err()    { printf "${C_RED}[ERR]${C_RESET} %s\n" "$*" >&2; }
header() { printf "\n${C_BOLD}%s${C_RESET}\n" "$*"; }
dim()    { printf "${C_DIM}%s${C_RESET}\n" "$*"; }

# Keep in sync with ALL_DIVISIONS in install.sh (divisions.json is the source
# of truth; strategy/ is excluded -- playbooks, not frontmatter agents).
ALL_DIVISIONS=(
  academic design engineering finance game-development gis marketing paid-media
  product project-management sales security spatial-computing specialized support testing
)

ALL_TOOLS=(claude-code copilot antigravity)

usage() {
  sed -n '/^# --- USAGE-START ---/,/^# --- USAGE-END ---/p' "$0" \
    | sed -e '1d;$d' -e 's/^# \{0,1\}//'
  exit 0
}

validate_division() {
  local d
  for d in "${ALL_DIVISIONS[@]}"; do [[ "$d" == "$1" ]] && return 0; done
  err "Unknown division '$1'. Valid: ${ALL_DIVISIONS[*]}"
  exit 1
}

validate_tool() {
  local t
  for t in "${ALL_TOOLS[@]}"; do [[ "$t" == "$1" ]] && return 0; done
  err "Unknown tool '$1'. Valid: ${ALL_TOOLS[*]} all"
  exit 1
}

tool_selected() {
  local t
  for t in "${TOOLS[@]}"; do [[ "$t" == "$1" ]] && return 0; done
  return 1
}

# division_label <division> -- display label from divisions.json, slug fallback.
division_label() {
  local l
  l="$(sed -n 's/.*"'"$1"'": { "label": "\([^"]*\)".*/\1/p' "$REPO_ROOT/divisions.json" | head -1)"
  if [[ -n "$l" ]]; then printf '%s' "$l"; else printf '%s' "$1"; fi
}

# division_files <division> -- frontmatter agent files in a division.
division_files() {
  local d="$REPO_ROOT/$1" f
  [[ -d "$d" ]] || return 0
  while IFS= read -r -d '' f; do
    is_agent_file "$f" && printf '%s\n' "$f"
  done < <(find "$d" -name "*.md" -type f -print0 2>/dev/null | sort -z)
}

# short_desc <file> -- frontmatter description trimmed to one readable line.
short_desc() {
  local desc
  desc="$(get_field description "$1")"
  desc="${desc%%<example>*}"                 # drop inline usage examples
  desc="$(printf '%s' "$desc" | tr -s ' ' | sed 's/^ //; s/ $//')"
  if [[ ${#desc} -gt 180 ]]; then desc="${desc:0:177}..."; fi
  printf '%s' "$desc"
}

install_file() {
  if $USE_LINK; then ln -sf "$1" "$2"; else cp "$1" "$2"; fi
}

# ensure_antigravity_skills -- generated SKILL.md dirs are gitignored, so
# regenerate them via convert.sh when missing (mirrors install.sh behavior).
ensure_antigravity_skills() {
  local d="$INTEGRATIONS/antigravity"
  if [[ -z "$(find "$d" -maxdepth 2 -name SKILL.md 2>/dev/null | head -1)" ]]; then
    if ! $AUTO_CONVERT; then
      err "antigravity: integration files missing and --no-convert set. Run ./scripts/convert.sh --tool antigravity first."
      exit 1
    fi
    warn "antigravity: integration files missing — running convert.sh --tool antigravity"
    "$SCRIPT_DIR/convert.sh" --tool antigravity >/dev/null 2>&1 \
      && ok "antigravity: generated skill files" \
      || { err "antigravity: convert.sh failed; run it manually"; exit 1; }
  fi
}

# ---------------------------------------------------------------------------
# Charter writers -- one per tool convention. Each takes <division> <label>
# <project-dir> and reads the roster itself. Existing charters are kept
# unless --force (agent/skill files are always refreshed).
# ---------------------------------------------------------------------------

# roster_lines <division> <with_slug> -- markdown bullets for the charter.
roster_lines() {
  local division="$1" with_slug="$2" f name desc slug
  while IFS= read -r f; do
    name="$(get_field name "$f")"
    desc="$(short_desc "$f")"
    if [[ "$with_slug" == "yes" ]]; then
      slug="agency-$(slugify "$name")"
      printf -- '- **%s** (`%s`)' "$name" "$slug"
    else
      printf -- '- **%s**' "$name"
    fi
    if [[ -n "$desc" ]]; then printf -- ' — %s\n' "$desc"; else printf '\n'; fi
  done < <(division_files "$division")
}

charter_footer() {
  printf '\n---\n\nGenerated by `scripts/create-team-projects.sh` in the agency-agents repo.\n'
  printf 'Re-run it after updating agents to refresh this project.\n'
}

# write_charter <path> <division> <label> -- guarded write; body from stdin
# is not possible per-tool cleanly in bash 3.2, so each tool has a writer.
charter_guard() {
  # returns 0 when the caller should write the file
  local path="$1" division="$2" what="$3"
  if [[ -f "$path" ]] && ! $FORCE; then
    warn "$division: $what exists, keeping it (--force overwrites)"
    return 1
  fi
  return 0
}

write_charter_claude() {
  local division="$1" label="$2" proj="$3"
  charter_guard "$proj/CLAUDE.md" "$division" "CLAUDE.md" || return 0
  {
    printf '# The Agency — %s Team\n\n' "$label"
    printf 'This is a Claude Code project for The Agency'"'"'s **%s** team.\n' "$label"
    printf 'The team'"'"'s specialist agents are installed project-locally in `.claude/agents/`,\n'
    printf 'so opening this folder in Claude Code loads exactly this roster.\n\n'
    printf '## Working with the team\n\n'
    printf -- '- Describe your task and Claude Code will auto-delegate to a matching specialist.\n'
    printf -- '- Or address one directly: "Use the <agent-name> agent to ...".\n'
    printf -- '- Run `/agents` to browse this team'"'"'s roster inside a session.\n\n'
    printf '## Roster\n\n'
    roster_lines "$division" no
    charter_footer
  } > "$proj/CLAUDE.md"
}

write_charter_copilot() {
  local division="$1" label="$2" proj="$3"
  charter_guard "$proj/.github/copilot-instructions.md" "$division" ".github/copilot-instructions.md" || return 0
  {
    printf '# The Agency — %s Team\n\n' "$label"
    printf 'This workspace is a GitHub Copilot project for The Agency'"'"'s **%s** team.\n' "$label"
    printf 'The team'"'"'s specialist agents live in `.github/agents/`.\n\n'
    printf '## Working with the team\n\n'
    printf -- '- Activate one directly in chat: "Activate <Agent Name> and ...".\n'
    printf -- '- If agents do not appear, verify the VS Code setting `chat.agentFilesLocations`\n'
    printf -- '  includes `.github/agents` for this workspace.\n\n'
    printf '## Roster\n\n'
    roster_lines "$division" no
    charter_footer
  } > "$proj/.github/copilot-instructions.md"
}

write_charter_antigravity() {
  local division="$1" label="$2" proj="$3"
  charter_guard "$proj/AGENTS.md" "$division" "AGENTS.md" || return 0
  {
    printf '# The Agency — %s Team\n\n' "$label"
    printf 'This workspace is an Antigravity project for The Agency'"'"'s **%s** team.\n' "$label"
    printf 'The team'"'"'s specialist skills live in `.agents/skills/` (slugs prefixed `agency-`).\n\n'
    printf '## Working with the team\n\n'
    printf -- '- Activate a specialist by slug: "Use the agency-<agent-name> skill to ...".\n'
    printf -- '- Pick the specialist whose description best matches the task; load one at a time.\n\n'
    printf '## Roster\n\n'
    roster_lines "$division" yes
    charter_footer
  } > "$proj/AGENTS.md"
}

# ---------------------------------------------------------------------------
# Per-tool installers -- <division> <project-dir>; echo the file count.
# ---------------------------------------------------------------------------

install_team_claude_code() {
  local division="$1" proj="$2" f count=0
  mkdir -p "$proj/.claude/agents"
  while IFS= read -r f; do
    install_file "$f" "$proj/.claude/agents/$(basename "$f")"
    incr count
  done < <(division_files "$division")
  echo "$count"
}

install_team_copilot() {
  local division="$1" proj="$2" f count=0
  mkdir -p "$proj/.github/agents"
  while IFS= read -r f; do
    install_file "$f" "$proj/.github/agents/$(basename "$f")"
    incr count
  done < <(division_files "$division")
  echo "$count"
}

install_team_antigravity() {
  local division="$1" proj="$2" f slug src count=0
  mkdir -p "$proj/.agents/skills"
  while IFS= read -r f; do
    slug="agency-$(agent_slug "$f")"
    src="$INTEGRATIONS/antigravity/$slug/SKILL.md"
    if [[ ! -f "$src" ]]; then
      warn "$division: no generated skill for $slug (run convert.sh --tool antigravity)" >&2
      continue
    fi
    mkdir -p "$proj/.agents/skills/$slug"
    install_file "$src" "$proj/.agents/skills/$slug/SKILL.md"
    incr count
  done < <(division_files "$division")
  echo "$count"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
DEST="${HOME}/AgencyTeams"
USE_LINK=false
FORCE=false
DRY_RUN=false
AUTO_CONVERT=true
SELECTED=()
TOOLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      IFS=',' read -ra _tools <<< "${2:?'--tool requires a value'}"
      for _t in "${_tools[@]}"; do
        _t="$(printf '%s' "$_t" | xargs)"; [[ -z "$_t" ]] && continue
        if [[ "$_t" == "all" ]]; then TOOLS=("${ALL_TOOLS[@]}"); else validate_tool "$_t"; TOOLS+=("$_t"); fi
      done
      shift 2 ;;
    --dest)     DEST="${2:?'--dest requires a value'}"; shift 2 ;;
    --division)
      IFS=',' read -ra _divs <<< "${2:?'--division requires a value'}"
      for _d in "${_divs[@]}"; do
        _d="$(printf '%s' "$_d" | xargs)"; [[ -z "$_d" ]] && continue
        validate_division "$_d"; SELECTED+=("$_d")
      done
      shift 2 ;;
    --link)       USE_LINK=true; shift ;;
    --force)      FORCE=true; shift ;;
    --no-convert) AUTO_CONVERT=false; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help|-h)    usage ;;
    *)            err "Unknown option: $1"; usage ;;
  esac
done

[[ ${#SELECTED[@]} -eq 0 ]] && SELECTED=("${ALL_DIVISIONS[@]}")
[[ ${#TOOLS[@]} -eq 0 ]] && TOOLS=(claude-code)

header "The Agency -- Creating team projects"
printf "  Repo:  %s\n" "$REPO_ROOT"
printf "  Dest:  %s\n" "$DEST"
printf "  Tools: %s\n" "${TOOLS[*]}"
printf "  Teams: %s\n" "${#SELECTED[@]}"
$USE_LINK && printf "  Mode:  symlink (--link)\n"
printf "\n"

if $DRY_RUN; then
  for division in "${SELECTED[@]}"; do
    n="$(division_files "$division" | grep -c . || true)"
    printf '  %-22s %3s agents -> %s/%s/  (%s)\n' "$division" "$n" "$DEST" "$division" "${TOOLS[*]}"
  done
  printf "\n"; dim "  Dry run: nothing written."; exit 0
fi

tool_selected antigravity && ensure_antigravity_skills

TOTAL_AGENTS=0
CREATED=0
for division in "${SELECTED[@]}"; do
  label="$(division_label "$division")"
  proj="$DEST/$division"
  team_count=0

  for t in "${TOOLS[@]}"; do
    case "$t" in
      claude-code)
        count="$(install_team_claude_code "$division" "$proj")"
        [[ "$count" -gt 0 ]] && write_charter_claude "$division" "$label" "$proj"
        ;;
      copilot)
        count="$(install_team_copilot "$division" "$proj")"
        [[ "$count" -gt 0 ]] && write_charter_copilot "$division" "$label" "$proj"
        ;;
      antigravity)
        count="$(install_team_antigravity "$division" "$proj")"
        [[ "$count" -gt 0 ]] && write_charter_antigravity "$division" "$label" "$proj"
        ;;
    esac
    [[ "$count" -gt "$team_count" ]] && team_count=$count
    if [[ "$count" -gt 0 ]]; then
      ok "$label ($t): $count agents -> $proj"
    else
      warn "$label ($t): no agents installed"
    fi
  done

  if [[ "$team_count" -eq 0 ]]; then
    rm -rf "$proj"
    continue
  fi
  TOTAL_AGENTS=$(( TOTAL_AGENTS + team_count ))
  incr CREATED
done

# Top-level index so the destination folder is self-explaining. List every
# team present on disk, not just this run's selection, so a filtered re-run
# never shrinks the index.
{
  printf '# The Agency — Team Projects\n\n'
  printf 'One project per Agency team. Depending on how they were generated, each\n'
  printf 'folder works in Claude Code (`.claude/agents/` + CLAUDE.md), GitHub Copilot\n'
  printf '(`.github/agents/` + copilot-instructions.md), and/or Antigravity\n'
  printf '(`.agents/skills/` + AGENTS.md). Open a folder in the matching tool and the\n'
  printf 'team'"'"'s agents load automatically.\n\n'
  for division in "${ALL_DIVISIONS[@]}"; do
    [[ -d "$DEST/$division" ]] || continue
    n=0
    for probe in ".claude/agents" ".github/agents" ".agents/skills"; do
      m="$(find "$DEST/$division/$probe" \( -name '*.md' -o -name 'SKILL.md' \) 2>/dev/null | grep -c . || true)"
      [[ "$m" -gt "$n" ]] && n=$m
    done
    [[ "$n" -eq 0 ]] && continue
    printf -- '- `%s/` — %s (%s agents)\n' "$division" "$(division_label "$division")" "$n"
  done
  printf '\nGenerated by `scripts/create-team-projects.sh`.\n'
} > "$DEST/README.md"

printf "\n"
ok "Done: $CREATED team projects ($TOTAL_AGENTS agents) for: ${TOOLS[*]} -> $DEST"
dim "  Claude Code:  open the folder, or: cd $DEST/<team> && claude"
dim "  Copilot:      open the folder in VS Code (agents in .github/agents/)"
dim "  Antigravity:  open the folder as a workspace (skills in .agents/skills/)"
