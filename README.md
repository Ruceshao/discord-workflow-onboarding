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

接入密钥应该一人一个。管理员在 VPS 上生成后私发给新人，VPS 只保存 hash 和归属信息。

AI 会自动完成：

- 下载工作流规则
- 写入本机配置
- 安装 `discord-workflow-publish` 命令
- 安装 `discord-workflow-list`、`discord-workflow-read`、`discord-workflow-reply`、`discord-workflow-close` 命令
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
根据公司的 Discord 工作流规则，把下面内容整理成需求最终稿。先给我看，不要直接发布。
...
```

4. AI 给出最终稿候选。
5. 用户在 AI 客户端里继续修改，直到确认。
6. 用户确认后，AI 调用 Discord Workflow Bot 的 `/publish` 接口。
7. Bot 把内容直接发布到对应 Forum。

Discord 只保留两个主要 Forum：

- `需求池`：所有持续工作对象。进度、决策、风险都沉淀在需求帖里。
- `会议纪要`：事件型会议记录。

需求帖只使用状态和优先级标签：

- 状态：`未开始`、`进行中`、`阻塞中`、`已完成`、`已归档`
- 优先级：`P0`、`P1`、`P2`、`P3`

需求编号由 bot 自动生成，例如 `REQ-0001`。编号会写入需求帖标题、正文和 API 响应，后续读取、回复、改标签、关闭需求或补充进展时优先使用编号定位。

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
  "url": "https://discord.com/channels/..."
}
```

### `POST /close`

按编号关闭需求，把状态标签改成 `已完成`，保留优先级标签，并在 Discord 里补充闭口记录。

请求：

```json
{
  "workItemId": "REQ-0001",
  "note": "已确认完成并闭口。",
  "closedBy": "Ruceshao"
}
```

读取和回复已有需求：

```bash
discord-workflow-list --status 进行中
discord-workflow-read REQ-0001
discord-workflow-reply REQ-0001 --kind progress --tag 进行中 "这里写进度或卡点说明。"
```

## 安全规则

- `DISCORD_WORKFLOW_TOKEN` 不要写进仓库。
- AI 每次调用 bot 前必须展示最终稿并获得用户确认。
- 用户要求修改时，在 AI 客户端里直接改，不要让用户去 Discord 退回重来。
- 如果缺少 token 或 API URL，只输出最终稿，不要尝试发布。
- 生产环境建议通过 HTTPS 暴露 API；没有 HTTPS 前，不要在公网明文传输 token。
