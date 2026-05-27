---
name: discord-workflow
description: Company Discord workflow assistant for Codex. Use when the user asks to整理、发布、读取、回复、编辑、更新、关闭、闭口、删除 Discord 工作流记录, mentions 需求池、会议纪要、REQ 编号、进度、卡点、阻塞、决策记录, or wants natural-language work input converted into the company's Discord workflow format.
---

# Discord Workflow

## Core Rule

Read `~/.discord-workflow/AGENTS.discord-workflow.md` before doing any workflow work. That file is the source of truth for formatting, labels, confirmation rules, and bot commands.

If the file is missing, tell the user to run the onboarding setup first. Do not guess the production workflow from memory.

## Operating Mode

- Use Chinese by default.
- Treat the human as the source of facts and final approval.
- Do not invent owners, deadlines, priorities, commitments, conclusions, or missing facts.
- Write missing information as `待确认`.
- Never reveal `~/.discord-workflow/config.env` or `DISCORD_WORKFLOW_TOKEN`.
- Do not perform visible Discord changes until the user explicitly confirms the final draft or operation summary.
- If a draft or reply is too long for one Discord message, preserve the same headings and structure and let the bot continue directly in the next message. Do not add extra continuation headings, truncate, or flatten the content.

## New Records

For a new requirement or meeting note:

1. Read `~/.discord-workflow/AGENTS.discord-workflow.md`.
2. Turn the user's natural language into the required Chinese structure.
3. Show the complete final draft to the user first in the readable preview format from the rules file: metadata as short fields, and `body` expanded as normal Markdown with real line breaks rather than a one-line JSON string.
4. Wait for explicit confirmation such as `确认发布`.
5. Publish only after confirmation:

```bash
discord-workflow-publish draft.json
```

If a draft JSON file already exists, use the local read-only helper to generate a human-checkable preview:

```bash
discord-workflow-preview draft.json
```

Requirement drafts must not include a manually invented `REQ-xxxx` id. The bot assigns it after publishing.

## Existing Requirements

For any existing requirement action, prefer the requirement id, for example `REQ-0001`.

If the user only provides a title or vague description, list candidates and ask the user to confirm the id:

```bash
discord-workflow-list --status 进行中
```

Before replying, editing, updating, closing, or deleting, read the current thread context:

```bash
discord-workflow-read REQ-0001
```

Do not rely on title matching alone.

## Replies

Use replies for progress, blockers, decisions, and notes inside the requirement thread.

1. Read the requirement first.
2. Draft the reply in Chinese.
3. Show the reply to the user.
4. After confirmation, call:

```bash
discord-workflow-reply REQ-0001 --kind progress --tag 进行中 "进度说明"
```

Allowed `--kind` values:

- `progress`: 进度更新
- `blocker`: 风险 / 阻塞更新
- `decision`: 决策记录
- `note`: 补充说明

Only pass `--tag` when the status or priority should actually change. For a blocker, usually use `--kind blocker --tag 阻塞中`.

Do not use replies to set `已完成` or `已归档`; use the close flow instead. If a requirement is already closed, do not reply, change tags, or reopen it. Create a new requirement, or ask for explicit confirmation before deleting the old one.

## Editing Messages

Use edits only to correct bot-authored messages that were already sent, such as typos, formatting, line breaks, or factual corrections. Do not use edits to silently change status, priority, or closure outcomes.

1. Read the requirement first and identify the target `messageId` from `recentMessages`.
2. Show the operation summary and the full replacement body to the user.
3. After confirmation, call:

```bash
discord-workflow-edit REQ-0001 MESSAGE_ID "修正后的完整消息正文"
```

Prefer stdin or heredocs for multi-line content so real line breaks are preserved:

```bash
discord-workflow-edit REQ-0001 MESSAGE_ID <<'EOF'
修正后的第一段。

修正后的第二段。
EOF
```

The command can only edit messages in the mapped requirement thread that were authored by the workflow bot. Closed or deleted requirements cannot be edited.

## Closing

When the user asks to close or 闭口 a requirement:

1. Require or identify the `REQ-xxxx` id.
2. Read the requirement.
3. Show the close note and operation summary.
4. After confirmation, call:

```bash
discord-workflow-close REQ-0001 "闭口说明"
```

## Deleting

Deleting is a maintainer action for a wrong or unreadable requirement that must be rewritten. Read the requirement first, show the deletion target, reason, and impact summary, and wait for explicit confirmation. After confirmation, call:

```bash
discord-workflow-delete REQ-0001 "删除原因"
```

## Safety Check

For setup verification, only run health checks and read/list commands. Do not publish or reply as a test unless the user explicitly asks for a real Discord write.

## Maintainer Updates

When maintaining or updating the workflow bot, API, onboarding repo, setup script, Codex skill, or workflow rules:

1. Update the GitHub onboarding repo and the VPS bot files.
2. Run `npm run sync:onboarding` from the bot project so Discord `#从这里开始` reflects the latest onboarding entry.
3. Post or update `#bot更新日志` with what changed and how existing teammates should update.

Treat this as bot maintenance, not a normal requirement post. Do not publish it to `需求池`.
