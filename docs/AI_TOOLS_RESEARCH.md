# AI 编码工具机制调研报告（2026-08）

> 全网调研 Claude Code / Cursor / GitHub Copilot / Aider / Devin / Gemini CLI / OpenAI Codex / Windsurf 的核心机制，提炼可借鉴设计。落地成果：`CLAUDE.md`、`.github/copilot-instructions.md`、`.mcp.json`、`tools/gen_repo_map.sh`、skill `ai-tools-patterns`。

## 1. 各工具核心机制速览

### Claude Code
| 机制 | 要点 | 借鉴 |
|---|---|---|
| CLAUDE.md 分层加载 | managed→user→project→local 向上合并；子目录按需惰性加载；`@imports` 引用外部文件（≤4 跳） | ✅ 已落地 CLAUDE.md=@AGENTS.md |
| Hooks 生命周期 | PreToolUse/PostToolUse/SessionStart 等；stdin JSON + **exit code 2 拦截**；if 条件预过滤 | ✅ pre-commit 钩子（gdlint+import） |
| Subagents | 独立上下文、描述驱动委托，只回摘要 | ✅ explore/task 子代理 |
| Slash Commands | `.claude/commands/` 自定义命令 | ✅ skills 系统等价 |
| Plan Mode | 只读研究→计划→确认→实施分离 | ✅ todo/complete_step |
| Checkpointing | 每提示快照（保留 100 个），/rewind 恢复；**独立于 Git** | git commit 即锚点（已覆盖） |
| Auto memory | `MEMORY.md` 索引（前 200 行/25KB）每会话加载 + 按需读细节 | ✅ 记忆系统 |
| 非交互 -p | JSON 输出、max-turns、预算上限、json-schema 强制输出 | verify_all.sh 退出码协议 |
| 权限渐进信任 | default→acceptEdits→plan→auto 模式切换；protected paths | — |
| Context 资产化 | compaction、prompt caching、tool search 延迟加载、skill 目录预算 1% | 记忆精简（≤25KB 索引） |

### Cursor
| 机制 | 要点 |
|---|---|
| Rules 三层 | AGENTS.md / `.cursor/rules/*.mdc`（frontmatter：alwaysApply/globs/description 触发）；规则 <500 行；`@file` 引用防过期 |
| Agent 三组件 | Instructions + Tools + Model；Checkpoints 快照（独立 Git） |
| Plan Mode + Explore | 子代理并行检索，只回摘要（上下文隔离） |
| Instant Grep + 语义索引 | 精确符号检索 + embedding 语义搜索 |

### GitHub Copilot
| 机制 | 要点 |
|---|---|
| Auto-compaction | 上下文 ~80% 时后台压缩成结构化摘要（目标/已完成/关键文件/下一步），95% 暂停等待 |
| 大输出转文件 | 工具输出 >20KiB 写临时文件，模型只收路径+预览 |
| Code Review | PR 级 agentic 审查，读 AGENTS.md + 路径级指令（`.github/instructions/**`） |
| Checkpoints | 每次压缩生成编号摘要快照，/session checkpoints 回看 |

### Aider
| 机制 | 要点 |
|---|---|
| Repo Map | tree-sitter 生成符号树状图注入上下文（本项目→GDScript 符号地图 gen_repo_map.sh） |
| 每步 git commit | 每个改动自动提交、可回滚 |
| Lint/Test 循环 | 改完自动跑 lint+test，失败喂回修复（TDD） |
| architect/code 双模式 | 规划与实施分离 |

### Devin
| 机制 | 要点 |
|---|---|
| Blueprint 声明式环境 | 仓库内声明 Godot 版本/依赖/验证命令，CI 与本地共用 |
| Snapshot | 环境快照回滚 |
| AGENTS.md 指令 | 长期任务规划 + 反馈闭环 |

### Gemini CLI / Codex / Windsurf
| 机制 | 要点 |
|---|---|
| GEMINI.md 层级 + JIT | 按目录分层、按需加载 |
| Checkpointing（影子仓库） | 独立于主 git 的 AI 操作历史，任意步还原 |
| Undo/Backtrack | 回到某步分叉重来（不改历史） |
| 上下文硬约束 | 注入片段有界 + 单片段 <10K token、>1K 需审查（Codex AGENTS.md 工程规则） |
| Cascade | 双模式 + 消息队列 + 步骤 Revert + 三级权限（Off/Auto/Turbo） |

## 2. 通用设计逻辑（跨工具共识）

1. **上下文是核心资产**：一切围绕省上下文——子代理隔离、tool 延迟加载、compaction、按目录惰性加载、大输出转文件。**省不下上下文的机制都是设计失败**。
2. **软硬双轨约束**：提示层（规范文件）塑造意图，强制层（hooks/权限/沙箱）保障边界——模型判断不是唯一安全来源。
3. **渐进式信任**：权限/审批按模式分级，会话中可切换；项目授权需信任。
4. **一切可恢复**：transcript 落盘、checkpoint 快照、git 提交、分叉重来——让 AI 试错无成本。
5. **文件即配置**：规范/hooks/commands/skills 全是入库 Markdown/JSON，可版本化、团队共享、AI 自生成。
6. **DoD 写进规范**：验收标准（测试全绿才提交、改完必跑 lint）是规范条目而非口头指令，须具体可验证。

## 3. 能力差距分析（本项目 vs 业界）

| 业界机制 | 本项目现状 | 差距 |
|---|---|---|
| 规范文件分层（AGENTS.md + 各工具兼容） | AGENTS.md ✅ | 缺 CLAUDE.md/.github/copilot-instructions.md 兼容层 → **C1/C2 已补** |
| Repo map（符号地图注入） | 无 | 缺 GDScript 符号地图 → **C7 gen_repo_map.sh 已补** |
| MCP 生态（含 Godot MCP） | 无 .mcp.json | 缺跨客户端 MCP 配置 → **C4 已补** |
| Compaction（上下文自动压缩） | 记忆索引有限制 | ⚠️ 依赖宿主；记忆精简已做 |
| 大输出转文件 | 工具输出直接进上下文 | ⚠️ 依赖宿主 |
| 自动修复循环（lint 失败喂回） | verify_all.sh + 手动循环 | ✅ 已覆盖（wanjie-workflow skill） |
| 每步 commit 锚点 | 手动 commit | ✅ 已覆盖（pre-commit 门禁） |

## 4. 落地清单（已完成，见对应文件）

- `CLAUDE.md`：@AGENTS.md 导入 + Claude Code 专属补充
- `.github/copilot-instructions.md`：Copilot 兼容指令（与 AGENTS.md 对齐）
- `.mcp.json`：项目级 MCP 配置（Godot MCP + 官方 servers，供 Claude Code/Cursor/Codex 等）
- `tools/gen_repo_map.sh`：GDScript 符号地图生成（docs/REPO_MAP.md）
- skill `ai-tools-patterns`：六条通用设计逻辑 playbook
- `docs/REPO_MAP.md`：项目符号地图（类/信号/函数索引，AI 上下文加速）

## 5. 来源

- Claude Code：docs.anthropic.com/en/docs/claude-code/{memory,settings,hooks,checkpointing,headless,context-window,mcp}
- Cursor：cursor.com/docs/{context/rules,agent/overview,agent/plan-mode,context/codebase-indexing}
- Copilot：docs.github.com/en/copilot（CLI 上下文管理 / code review / custom-instructions-support）
- Aider：aider.chat/docs/{repomap,git,usage/lint-test,usage/modes}
- Devin：docs.devin.ai（environment/blueprints、agents-md、essential-guidelines）
- Gemini CLI：github.com/google-gemini/gemini-cli、geminicli.com/docs/cli/{gemini-md,checkpointing}
- Codex：github.com/openai/codex（AGENTS.md、app_backtrack.rs）
- MCP：modelcontextprotocol.io（specification）、github.com/modelcontextprotocol/servers、Coding-Solo/godot-mcp（5.1k★）、hi-godot/godot-ai（1.5k★）
- AGENTS.md 规范：agents.md（Agentic AI Foundation）
