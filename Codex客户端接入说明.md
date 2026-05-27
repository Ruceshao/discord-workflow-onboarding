# Codex 客户端接入说明

这个流程的目标是让员工在自己的 Codex / Claude 客户端里完成 AI 整理、修改和最终确认，Discord 只负责承载最终记录。

## 使用方式

普通同事不需要手动配置 `.env`。推荐把 `docs/新人一键接入提示词.md` 复制给自己的 Codex / Claude，让 AI 自动配置。

推荐顺序：

1. 在 Discord `#从这里开始` 复制新人提示词。
2. 把提示词交给 Codex / Claude。
3. AI 会自己从 GitHub 下载工作流文件。
4. AI 会读取本地 Markdown 文件并自动安装配置。

管理员只需要给新人一项：

- `接入密钥`

当前 API URL 固定为：

```text
https://workflow.weebstrading.xyz
```

接入密钥应该一人一个，不要多人共用。密钥只在生成时显示一次；VPS 里只保存 hash 和归属信息。

AI 会自动完成：

- 下载工作流规则
- 写入本机配置
- 安装 Codex skill：`discord-workflow`
- 安装 `discord-workflow-publish` 命令
- 安装 `discord-workflow-preview` 只读预览命令
- 安装 `discord-workflow-list`、`discord-workflow-read`、`discord-workflow-reply`、`discord-workflow-edit`、`discord-workflow-close`、`discord-workflow-delete` 命令
- 做 health check

手动配置方式如下，仅供管理员或高级用户排查问题：

1. 把 `docs/AGENTS.discord-workflow.md` 的内容放进项目的 `AGENTS.md`，或者做成个人 skill / custom instruction。
2. 在本地配置两个环境变量：

```bash
export DISCORD_WORKFLOW_API_URL="https://workflow.weebstrading.xyz"
export DISCORD_WORKFLOW_TOKEN="由管理员发放的 token"
```

3. 用户在 Codex / Claude 里说：

```text
使用 discord-workflow skill，帮我把下面内容整理成需求最终稿。先给我看，不要直接发布。
...
```

4. AI 给出可读最终稿候选：发布字段用短行展示，正文按 Markdown 原样展开换行，不要只贴一整段 raw JSON。
5. 用户在 AI 客户端里继续修改，直到确认。
6. 用户确认后，AI 调用 Discord Workflow Bot 的 `/publish` 接口。
7. Bot 分配需求编号，并把内容直接发布到对应 Forum。

Discord 只保留两个主要 Forum：

- `需求池`：所有持续工作对象。进度、决策、风险都沉淀在需求帖里。
- `会议纪要`：事件型会议记录。

另外有两个说明频道：

- `从这里开始`：最新接入入口和新人提示词。
- `bot更新日志`：bot、API、接入脚本和 skill 更新说明，以及已有同事的更新方法。

需求帖只使用状态和优先级标签：

- 状态：`未开始`、`进行中`、`阻塞中`、`已完成`、`已归档`
- 优先级：`P0`、`P1`、`P2`、`P3`

需求编号由 bot 自动生成，例如 `REQ-0001`。AI 客户端不要自己编编号；发布成功后，用返回的 `workItemId` 定位后续读取、回复、编辑、改标签、关闭或删除需求。闭口后的需求不能补充、编辑、改标签或重新打开；需要重写时应发布新需求，或由管理员确认后删除旧需求。

如果正文或回复超过 Discord 单条消息限制，bot 会保持原格式自动拆成同一线程下的多条消息，后一条直接接着上一条继续写；AI 客户端不要为了塞进单条消息而删掉结构或关键信息。

## Codex Skill

安装脚本会把 skill 安装到：

```text
~/.codex/skills/discord-workflow/
```

Codex 用户可以直接说：

```text
使用 discord-workflow skill，帮我整理下面的需求。先给我看最终稿，不要发布。
```

skill 本身只负责触发和流程约束；详细格式仍然读取本机的 `~/.discord-workflow/AGENTS.discord-workflow.md`。

如果 AI 已经生成 `draft.json`，可以先运行这个只读命令生成方便人工检查的确认稿：

```bash
discord-workflow-preview draft.json
```

这个命令不会请求 API，也不会发布到 Discord。

## 已有同事更新

当 Discord `#bot更新日志` 有更新时，把日志里的“如何更新本地工作流”提示词交给 Codex / Claude。更新过程会复用本机 `~/.discord-workflow/config.env` 里的 API URL 和接入密钥，不需要把 token 发到公开频道。

## Bot API

### `GET /onboarding/setup.sh`

给新人 AI 客户端使用的自动配置脚本。

### `GET /onboarding/agents.md`

返回最新的 Agent 工作流规则。

### `POST /publish`

把外部 AI 客户端整理好、且用户已确认的最终稿发布到对应 Forum。

请求：

```json
{
  "type": "requirement",
  "title": "将新人入职流程接入 Discord",
  "tags": ["进行中", "P1"],
  "body": "## 一句话总结\n...\n\n## 背景\n...",
  "missingInfo": ["负责人待确认", "截止时间待确认"],
  "confidenceNote": "负责人和时间需要人工确认。",
  "source": "Codex 客户端整理",
  "submitter": "Ruceshao"
}
```

响应：

```json
{
  "ok": true,
  "status": "published",
  "workItemId": "REQ-0001",
  "url": "https://discord.com/channels/...",
  "messageIds": ["1500000000000000000", "1500000000000000001"]
}
```

### `GET /items`

读取 bot 本地索引里的需求列表，可用于用户只记得大概标题、状态或优先级时辅助定位编号。

示例：

```bash
discord-workflow-list --status 进行中
```

接口响应：

```json
{
  "ok": true,
  "count": 1,
  "items": [
    {
      "workItemId": "REQ-0001",
      "type": "requirement",
      "title": "测试本地 AI 工作流",
      "status": "进行中",
      "tags": ["进行中", "P0"],
      "url": "https://discord.com/channels/..."
    }
  ]
}
```

### `GET /items/:workItemId`

按需求编号读取单条需求的 Discord 线程上下文，包括原帖和最近回复。AI 回复、编辑、改标签或闭口前应该先读取。

示例：

```bash
discord-workflow-read REQ-0001
```

### `POST /reply`

按需求编号在对应 Discord 需求帖下回复进度、卡点、决策或补充说明。需要改状态时，通过 `tags` 传入新的状态标签；不需要改状态时不要传标签。不能通过 `/reply` 设置 `已完成` 或 `已归档`，关闭需求必须使用 `/close`。已闭口需求会被拒绝回复和改标签。

请求：

```json
{
  "workItemId": "REQ-0001",
  "kind": "blocker",
  "body": "当前卡点：需要确认 API 读取权限和回复格式。",
  "tags": ["阻塞中"],
  "submitter": "Ruce Shao"
}
```

响应：

```json
{
  "ok": true,
  "status": "replied",
  "workItemId": "REQ-0001",
  "kind": "blocker",
  "tags": ["阻塞中", "P0"],
  "url": "https://discord.com/channels/...",
  "messageIds": ["1500000000000000000", "1500000000000000001"]
}
```

本地命令：

```bash
discord-workflow-reply REQ-0001 --kind blocker --tag 阻塞中 "当前卡点：需要确认 API 读取权限和回复格式。"
```

### `POST /edit`

编辑某个需求线程里由工作流 bot 已发送的单条消息。用于修正错字、事实、格式或换行，不用于偷偷改变状态、优先级或闭口结果。编辑前应该先调用 `discord-workflow-read REQ-0001`，从 `recentMessages` 里确认 `messageId`，并把完整替换正文给用户确认。

已闭口或已删除的需求不能编辑。接口只允许编辑该需求线程内、由工作流 bot 自己发送的消息；单条编辑内容必须不超过 Discord 消息长度限制。

请求：

```json
{
  "workItemId": "REQ-0001",
  "messageId": "1500000000000000000",
  "body": "修正后的完整消息正文。",
  "editedBy": "Ruce Shao"
}
```

响应：

```json
{
  "ok": true,
  "status": "edited",
  "workItemId": "REQ-0001",
  "messageId": "1500000000000000000",
  "editedAt": "2026-05-27T00:00:00.000Z",
  "url": "https://discord.com/channels/..."
}
```

本地命令：

```bash
discord-workflow-edit REQ-0001 MESSAGE_ID "修正后的完整消息正文。"
```

多行正文建议用 stdin 或 heredoc，避免把 `\n` 当成普通字符：

```bash
discord-workflow-edit REQ-0001 MESSAGE_ID <<'EOF'
修正后的第一段。

修正后的第二段。
EOF
```

### `POST /close`

按需求编号关闭需求。bot 会根据本地索引定位 Discord 帖子，把状态标签改成 `已完成`，保留优先级标签，发送闭口记录，并锁定归档该需求帖。关闭不会把闭口记录塞回原帖正文，避免长原帖被截断。

请求：

```json
{
  "workItemId": "REQ-0001",
  "note": "已确认完成并闭口。",
  "closedBy": "Ruceshao"
}
```

响应：

```json
{
  "ok": true,
  "status": "closed",
  "workItemId": "REQ-0001",
  "tags": ["已完成", "P0"],
  "url": "https://discord.com/channels/..."
}
```

### `POST /delete`

删除误发、内容不可读或需要重写的需求。删除是管理员维护动作，AI 客户端必须先读取上下文并展示删除对象、删除原因和影响摘要，等用户明确确认后再调用。

也支持 `DELETE /items/:workItemId` 做同一件事；推荐客户端命令默认使用 `POST /delete`，便于携带删除原因和删除人。

请求：

```json
{
  "workItemId": "REQ-0001",
  "reason": "确认删除该需求并重新发布。",
  "deletedBy": "Ruceshao"
}
```

响应：

```json
{
  "ok": true,
  "status": "deleted",
  "workItemId": "REQ-0001",
  "deletedAt": "2026-05-27T00:00:00.000Z"
}
```

本地命令：

```bash
discord-workflow-delete REQ-0001 "确认删除该需求并重新发布。"
```

## 安全规则

- `DISCORD_WORKFLOW_TOKEN` 不要写进仓库。
- 接入密钥不要写进仓库、Discord 公开频道或群聊；建议管理员私发给个人。
- 新人接入密钥一人一个，并在 VPS 的 `data/api-keys.json` 入档。这个文件只保存 hash，不保存明文 token。
- AI 每次调用 bot 前必须展示最终稿并获得用户确认。
- 编辑已发送消息前必须展示操作摘要和完整替换正文，并获得用户确认。
- 确认稿必须可读：`body` 要作为 Markdown 正文展开换行，不要只以 JSON 字符串的一长条展示。
- 用户要求修改时，在 AI 客户端里直接改，不要让用户去 Discord 退回重来。
- 如果缺少 token 或 API URL，只输出最终稿，不要尝试发布。
- 生产环境建议通过 HTTPS 暴露 API；没有 HTTPS 前，不要在公网明文传输 token。

## 管理员发放密钥

在 VPS 项目目录运行：

```bash
cd /home/ubuntu/discord-ai-workflow-bot
npm run key:create -- --owner "同事姓名" --label "同事姓名 Codex 客户端"
```

命令会输出 `token`，只复制这一段给同事。`data/api-keys.json` 会记录 key id、owner、label、hash 和创建时间。

吊销某个 key 时，编辑 `data/api-keys.json`，把对应记录的 `status` 改成 `revoked`，然后重启 bot：

```bash
sudo systemctl restart discord-ai-workflow-bot.service
```
