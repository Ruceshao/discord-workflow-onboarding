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
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$config_dir" "$bin_dir"

{
  printf 'DISCORD_WORKFLOW_API_URL=%q\n' "$api_url"
  printf 'DISCORD_WORKFLOW_TOKEN=%q\n' "$token"
  printf 'DISCORD_WORKFLOW_SUBMITTER=%q\n' "$submitter"
} > "$config_dir/config.env"
chmod 600 "$config_dir/config.env"

if [[ -f "$script_dir/AGENTS.discord-workflow.md" ]]; then
  cp "$script_dir/AGENTS.discord-workflow.md" "$config_dir/AGENTS.discord-workflow.md"
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
- 需求编号由 bot 发布时自动生成，例如 REQ-0001。不要自己编编号；后续更新、改标签或关闭需求时优先使用编号定位。
- 不要编造负责人、截止时间、优先级、事实、结论或承诺。
- 信息缺失时写“待确认”。
- 用户要求修改时，直接在当前 AI 客户端里改稿。
- 对外部可见动作必须先给用户看完整最终稿，并等用户确认后再发布。
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

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$api_url/health" >/dev/null
fi

cat <<EOF
接入完成。

规则文件：
$config_dir/AGENTS.discord-workflow.md

发布命令：
$bin_dir/discord-workflow-publish

如果你的 shell 找不到这个命令，把下面这行加入 ~/.zshrc 或 ~/.bashrc：
export PATH="\$HOME/.local/bin:\$PATH"

之后你可以对 AI 说：
“请读取 ~/.discord-workflow/AGENTS.discord-workflow.md，并按公司 Discord 工作流帮我整理和发布。”
EOF
