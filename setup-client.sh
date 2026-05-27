#!/usr/bin/env bash
set -euo pipefail

api_url=""
token=""
submitter="${USER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url)
      api_url="${2:-}"
      shift 2
      ;;
    --token)
      token="${2:-}"
      shift 2
      ;;
    --submitter)
      submitter="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$api_url" ]]; then
  read -r -p "Discord Workflow API URL: " api_url
fi

if [[ -z "$token" ]]; then
  read -r -s -p "Discord Workflow Token: " token
  echo
fi

api_url="${api_url%/}"
config_dir="$HOME/.discord-workflow"
bin_dir="$HOME/.local/bin"
codex_home="${CODEX_HOME:-$HOME/.codex}"
skill_dir="$codex_home/skills/discord-workflow"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$config_dir" "$bin_dir" "$skill_dir/agents"

{
  printf 'DISCORD_WORKFLOW_API_URL=%q\n' "$api_url"
  printf 'DISCORD_WORKFLOW_TOKEN=%q\n' "$token"
  printf 'DISCORD_WORKFLOW_SUBMITTER=%q\n' "$submitter"
} > "$config_dir/config.env"
chmod 600 "$config_dir/config.env"

agent_rules_source=""
if [[ -f "$script_dir/AGENTS.discord-workflow.md" ]]; then
  agent_rules_source="$script_dir/AGENTS.discord-workflow.md"
elif [[ -f "$script_dir/../docs/AGENTS.discord-workflow.md" ]]; then
  agent_rules_source="$script_dir/../docs/AGENTS.discord-workflow.md"
fi

if [[ -n "$agent_rules_source" ]]; then
  cp "$agent_rules_source" "$config_dir/AGENTS.discord-workflow.md"
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$api_url/onboarding/agents.md" -o "$config_dir/AGENTS.discord-workflow.md" || true
fi

if [[ ! -s "$config_dir/AGENTS.discord-workflow.md" ]]; then
  cat > "$config_dir/AGENTS.discord-workflow.md" <<'EOF'
# Discord 工作流 Agent 规则

你是公司的 Discord 工作流整理助手。默认使用中文。用户会在 Codex / Claude 客户端里用自然语言描述需求或会议内容。你负责整理成最终稿，并在用户明确确认后调用 `discord-workflow-publish` 发布到 Discord。

规则：
- 只使用 `requirement` 和 `meeting` 两种发布类型。
- 需求池里的对象默认都是需求/工作项，不要打类型标签。
- 需求帖只使用状态和优先级标签：未开始、进行中、阻塞中、已完成、已归档、P0、P1、P2、P3。
- 需求编号由 bot 发布时自动生成，例如 REQ-0001。不要自己编编号；后续读取、回复、编辑、改标签或关闭需求时优先使用编号定位。
- 不要编造负责人、截止时间、优先级、事实、结论或承诺。
- 信息缺失时写“待确认”。
- 用户要求修改时，直接在当前 AI 客户端里改稿。
- 对外部可见动作必须先给用户看完整最终稿，并等用户确认后再发布。
- 回复或编辑已有需求前先调用 `discord-workflow-read REQ-0001` 读取上下文；确认后再调用 `discord-workflow-reply` 或 `discord-workflow-edit`。
- 闭口后的需求不能补充、编辑、改标签或重新打开；如需重写，发布新需求或由管理员确认后调用 `discord-workflow-delete` 删除旧需求。
- 正文或回复较长时，保持格式完整；bot 会自动拆成同一线程下的多条消息，并在下一条消息里直接接着写，不要截断。
EOF
fi

skill_source_dir=""
if [[ -f "$script_dir/skills/discord-workflow/SKILL.md" ]]; then
  skill_source_dir="$script_dir/skills/discord-workflow"
elif [[ -f "$script_dir/../skills/discord-workflow/SKILL.md" ]]; then
  skill_source_dir="$script_dir/../skills/discord-workflow"
fi

if [[ -n "$skill_source_dir" ]]; then
  cp "$skill_source_dir/SKILL.md" "$skill_dir/SKILL.md"

  if [[ -f "$skill_source_dir/agents/openai.yaml" ]]; then
    cp "$skill_source_dir/agents/openai.yaml" "$skill_dir/agents/openai.yaml"
  fi
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$api_url/onboarding/skills/discord-workflow/SKILL.md" -o "$skill_dir/SKILL.md" || true
  curl -fsSL "$api_url/onboarding/skills/discord-workflow/agents/openai.yaml" -o "$skill_dir/agents/openai.yaml" || true
fi

if [[ ! -s "$skill_dir/SKILL.md" ]]; then
  cat > "$skill_dir/SKILL.md" <<'EOF'
---
name: discord-workflow
description: Company Discord workflow assistant for Codex. Use when the user asks to整理、发布、读取、回复、编辑、更新、关闭、闭口、删除 Discord 工作流记录, mentions 需求池、会议纪要、REQ 编号、进度、卡点、阻塞、决策记录, or wants natural-language work input converted into the company's Discord workflow format.
---

# Discord Workflow

Read `~/.discord-workflow/AGENTS.discord-workflow.md` before doing any workflow work. Use Chinese by default. Show drafts or operation summaries before any Discord write. Publish with `discord-workflow-publish`, list with `discord-workflow-list`, read existing requirements with `discord-workflow-read`, reply with `discord-workflow-reply`, edit bot-authored messages with `discord-workflow-edit`, close with `discord-workflow-close`, and delete only after explicit confirmation with `discord-workflow-delete`. Never reveal `~/.discord-workflow/config.env` or `DISCORD_WORKFLOW_TOKEN`.

When showing a draft for confirmation, do not show only raw JSON. Show metadata as short fields and expand `body` as readable Markdown with real line breaks. If a draft JSON file exists, use `discord-workflow-preview draft.json` for a local read-only preview. If content is long, preserve the structure; the bot will continue directly in the next Discord message.
EOF
fi

if [[ ! -s "$skill_dir/agents/openai.yaml" ]]; then
  cat > "$skill_dir/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Discord Workflow"
  short_description: "整理、读取、回复、编辑、关闭和删除公司 Discord 工作流记录"
  default_prompt: "使用 discord-workflow skill，帮我整理下面的需求；先给我看最终稿，不要发布。"
EOF
fi

cat > "$bin_dir/discord-workflow-publish" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

source "$config_file"

input="${1:-}"
if [[ -n "$input" ]]; then
  data_arg=("--data-binary" "@$input")
else
  data_arg=("--data-binary" "@-")
fi

curl -sS "$DISCORD_WORKFLOW_API_URL/publish" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN" \
  -H "content-type: application/json" \
  "${data_arg[@]}"
EOF
chmod +x "$bin_dir/discord-workflow-publish"

cat > "$bin_dir/discord-workflow-preview" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

input="${1:-}"

if [[ -z "$input" ]]; then
  echo "Usage: discord-workflow-preview draft.json" >&2
  exit 2
fi

node - "$input" <<'NODE'
const { readFileSync } = require('node:fs');

const input = process.argv[2];
const text = readFileSync(input, 'utf8');
let draft;

try {
  draft = JSON.parse(text);
} catch (error) {
  console.error(`Invalid draft JSON: ${error.message}`);
  process.exit(2);
}

const value = (text, fallback = '待确认') => {
  const normalized = String(text || '').trim();
  return normalized || fallback;
};

const list = (items, fallback = '- 暂无') => {
  if (!Array.isArray(items) || items.length === 0) {
    return fallback;
  }

  return items
    .map((item) => String(item || '').trim())
    .filter(Boolean)
    .map((item) => `- ${item}`)
    .join('\n') || fallback;
};

const tags = Array.isArray(draft.tags) && draft.tags.length
  ? draft.tags.map((tag) => String(tag).trim()).filter(Boolean).join('、')
  : '未打标签';

const lines = [
  '# Discord 工作流确认稿',
  '',
  '## 发布字段',
  '',
  `- type: ${value(draft.type)}`,
  `- title: ${value(draft.title)}`,
  `- tags: ${tags}`,
  `- source: ${value(draft.source)}`,
  `- submitter: ${value(draft.submitter)}`,
  '',
  '## 正文预览',
  '',
  value(draft.body),
  '',
  '## 待确认信息',
  '',
  list(draft.missingInfo),
  '',
  '## AI 说明',
  '',
  value(draft.confidenceNote, '请人工确认事实、优先级、负责人和截止时间。')
];

process.stdout.write(`${lines.join('\n').trimEnd()}\n`);
NODE
EOF
chmod +x "$bin_dir/discord-workflow-preview"

cat > "$bin_dir/discord-workflow-close" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

work_item_id="${1:-}"
if [[ -z "$work_item_id" ]]; then
  echo "Usage: discord-workflow-close REQ-0001 [close note]" >&2
  exit 2
fi
shift || true

note="${*:-已确认完成并闭口。}"

source "$config_file"

payload="$(
  node - "$work_item_id" "$note" "${DISCORD_WORKFLOW_SUBMITTER:-}" <<'NODE'
const [workItemId, note, closedBy] = process.argv.slice(2);
process.stdout.write(JSON.stringify({ workItemId, note, closedBy }));
NODE
)"

curl -sS "$DISCORD_WORKFLOW_API_URL/close" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN" \
  -H "content-type: application/json" \
  --data-binary "$payload"
EOF
chmod +x "$bin_dir/discord-workflow-close"

cat > "$bin_dir/discord-workflow-delete" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

work_item_id="${1:-}"
if [[ -z "$work_item_id" ]]; then
  echo "Usage: discord-workflow-delete REQ-0001 [delete reason]" >&2
  exit 2
fi
shift || true

reason="${*:-确认删除需求。}"

source "$config_file"

payload="$(
  node - "$work_item_id" "$reason" "${DISCORD_WORKFLOW_SUBMITTER:-}" <<'NODE'
const [workItemId, reason, deletedBy] = process.argv.slice(2);
process.stdout.write(JSON.stringify({ workItemId, reason, deletedBy }));
NODE
)"

curl -sS "$DISCORD_WORKFLOW_API_URL/delete" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN" \
  -H "content-type: application/json" \
  --data-binary "$payload"
EOF
chmod +x "$bin_dir/discord-workflow-delete"

cat > "$bin_dir/discord-workflow-read" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

work_item_id="${1:-}"
if [[ -z "$work_item_id" ]]; then
  echo "Usage: discord-workflow-read REQ-0001" >&2
  exit 2
fi

source "$config_file"

curl -sS "$DISCORD_WORKFLOW_API_URL/items/$work_item_id" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN"
EOF
chmod +x "$bin_dir/discord-workflow-read"

cat > "$bin_dir/discord-workflow-list" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

query=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)
      query="${query}${query:+&}status=$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1] || ""))' "${2:-}")"
      shift 2
      ;;
    --type)
      query="${query}${query:+&}type=$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1] || ""))' "${2:-}")"
      shift 2
      ;;
    *)
      echo "Usage: discord-workflow-list [--status 未开始|进行中|阻塞中|已完成|已归档] [--type requirement|meeting]" >&2
      exit 2
      ;;
  esac
done

source "$config_file"

url="$DISCORD_WORKFLOW_API_URL/items"
if [[ -n "$query" ]]; then
  url="$url?$query"
fi

curl -sS "$url" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN"
EOF
chmod +x "$bin_dir/discord-workflow-list"

cat > "$bin_dir/discord-workflow-reply" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

work_item_id="${1:-}"
if [[ -z "$work_item_id" ]]; then
  echo "Usage: discord-workflow-reply REQ-0001 [--kind progress|blocker|decision|note] [--tag 进行中] \"reply body\"" >&2
  exit 2
fi
shift || true

kind="progress"
tags=()
body_parts=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind)
      kind="${2:-progress}"
      shift 2
      ;;
    --tag)
      tags+=("${2:-}")
      shift 2
      ;;
    *)
      body_parts+=("$1")
      shift
      ;;
  esac
done

body="${body_parts[*]:-}"
if [[ -z "$body" ]]; then
  body="$(cat)"
fi

source "$config_file"

tags_joined=""
if [[ ${#tags[@]} -gt 0 ]]; then
  tags_joined="$(IFS=$'\037'; echo "${tags[*]}")"
fi

payload="$(
  node - "$work_item_id" "$kind" "$body" "${DISCORD_WORKFLOW_SUBMITTER:-}" "$tags_joined" <<'NODE'
const [workItemId, kind, body, submitter, joinedTags] = process.argv.slice(2);
const tags = joinedTags ? joinedTags.split('\x1f').filter(Boolean) : [];
process.stdout.write(JSON.stringify({ workItemId, kind, body, submitter, tags }));
NODE
)"

curl -sS "$DISCORD_WORKFLOW_API_URL/reply" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN" \
  -H "content-type: application/json" \
  --data-binary "$payload"
EOF
chmod +x "$bin_dir/discord-workflow-reply"

cat > "$bin_dir/discord-workflow-edit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_file="$HOME/.discord-workflow/config.env"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Run setup-client.sh first." >&2
  exit 1
fi

work_item_id="${1:-}"
message_id="${2:-}"
if [[ -z "$work_item_id" || -z "$message_id" ]]; then
  echo "Usage: discord-workflow-edit REQ-0001 MESSAGE_ID [new message body]" >&2
  echo "Tip: omit the body argument and pipe or paste Markdown through stdin to preserve real line breaks." >&2
  exit 2
fi
shift 2 || true

body_parts=("$@")
body="${body_parts[*]:-}"
if [[ -z "$body" ]]; then
  body="$(cat)"
fi

if [[ -z "$body" ]]; then
  echo "Missing edited message body" >&2
  exit 2
fi

source "$config_file"

payload="$(
  node - "$work_item_id" "$message_id" "$body" "${DISCORD_WORKFLOW_SUBMITTER:-}" <<'NODE'
const [workItemId, messageId, body, editedBy] = process.argv.slice(2);
process.stdout.write(JSON.stringify({ workItemId, messageId, body, editedBy }));
NODE
)"

curl -sS "$DISCORD_WORKFLOW_API_URL/edit" \
  -H "authorization: Bearer $DISCORD_WORKFLOW_TOKEN" \
  -H "content-type: application/json" \
  --data-binary "$payload"
EOF
chmod +x "$bin_dir/discord-workflow-edit"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$api_url/health" >/dev/null
fi

cat <<EOF
接入完成。

规则文件：
$config_dir/AGENTS.discord-workflow.md

Codex skill：
$skill_dir

发布命令：
$bin_dir/discord-workflow-publish

确认预览命令：
$bin_dir/discord-workflow-preview draft.json

关闭命令：
$bin_dir/discord-workflow-close REQ-0001 "已确认完成并闭口。"

删除命令：
$bin_dir/discord-workflow-delete REQ-0001 "确认删除该需求并重新发布。"

列表命令：
$bin_dir/discord-workflow-list --status 进行中

读取命令：
$bin_dir/discord-workflow-read REQ-0001

回复命令：
$bin_dir/discord-workflow-reply REQ-0001 --kind progress --tag 进行中 "这里写进度或卡点说明。"

编辑已发送消息命令：
$bin_dir/discord-workflow-edit REQ-0001 MESSAGE_ID "这里写修正后的完整消息正文。"

如果你的 shell 找不到这个命令，把下面这行加入 ~/.zshrc 或 ~/.bashrc：
export PATH="\$HOME/.local/bin:\$PATH"

之后你可以对 AI 说：
“使用 discord-workflow skill，帮我整理这个需求。先给我看最终稿，不要发布。”
EOF
