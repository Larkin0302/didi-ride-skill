# didi-ride-skill

在飞书里说一句话叫车。龙虾（OpenClaw）的滴滴打车技能。

在飞书对话里说"帮我叫个车从A到B"，龙虾自动查价格、发交互卡片，点一下按钮车就来了。

## 效果预览

<!-- TODO: 补截图 -->

| 选车卡片 | 等待接单 | 司机信息 | 行程完成 |
|---------|---------|---------|---------|
| ![选车](screenshots/select-car.png) | ![等待](screenshots/waiting.png) | ![司机](screenshots/driver.png) | ![完成](screenshots/completed.png) |

## 前置条件

- [OpenClaw](https://github.com/nicepkg/openclaw) 已安装并运行
- `feishu-openclaw-plugin` 已安装（飞书频道插件）
- 滴滴 MCP API Key（申请地址：https://mcp.didichuxing.com ）

## 一键安装

```bash
git clone https://github.com/Larkin0302/didi-ride-skill.git
cd didi-ride-skill
bash install.sh
```

安装脚本会自动：
1. 复制打车工具代码到飞书插件目录
2. 复制 AI 技能定义到 OpenClaw skills 目录
3. 在插件的 `index.js` 中注册工具
4. 在插件的 `monitor.js` 中添加卡片按钮路由
5. 引导你配置滴滴 API Key

安装完成后执行 `openclaw gateway restart` 重启即可。

## 手动安装

如果自动安装不适用，可以手动操作：

### 1. 复制文件

```bash
# 源代码
mkdir -p ~/.openclaw/extensions/feishu-openclaw-plugin/src/tools/didi-ride/
cp src/*.js ~/.openclaw/extensions/feishu-openclaw-plugin/src/tools/didi-ride/

# 技能定义
mkdir -p ~/.openclaw/skills/didi-ride/
cp skill/SKILL.md ~/.openclaw/skills/didi-ride/
```

### 2. 修改 index.js

在 `~/.openclaw/extensions/feishu-openclaw-plugin/index.js` 中：

添加 import（放在其他 import 附近）：
```js
import { registerDiDiRideTool } from "./src/tools/didi-ride/register.js";
```

在 `register(api)` 函数中添加注册调用：
```js
registerDiDiRideTool(api);
```

### 3. 修改 monitor.js

在 `~/.openclaw/extensions/feishu-openclaw-plugin/src/channel/monitor.js` 的 `card.action.trigger` 处理中，在 `handleCardAction` 调用之前添加：

```js
const action = data?.action?.value?.action;
if (typeof action === "string" && action.startsWith("didi_")) {
    const { handleDiDiCardAction } = await import("../tools/didi-ride/handler.js");
    return await handleDiDiCardAction(data, cfg, accountId);
}
```

### 4. 配置 API Key

在 `~/.openclaw/openclaw.json` 的 `env` 字段中添加：

```json
{
  "env": {
    "DIDI_MCP_KEY": "你的API Key"
  }
}
```

### 5. 重启

```bash
openclaw gateway restart
```

## 使用方式

在飞书私聊或群聊中对龙虾说：

> 帮我叫个车从长治客运西站到长治东站

龙虾会：
1. 搜索起终点坐标
2. 查询所有可用车型和预估价格
3. 发送交互式选车卡片

在卡片上你可以：
- 点击「叫车 ¥XX」按钮下单
- 点击「刷新状态」查看最新订单信息（司机、车牌、预计到达）
- 点击「取消订单」取消

## 沙箱测试模式

默认安装后使用沙箱环境（模拟数据，不产生真实订单），方便先跑通流程。

切换到正式环境：编辑 `~/.openclaw/extensions/feishu-openclaw-plugin/src/tools/didi-ride/client.js`，将：

```js
const DIDI_DEBUG_MODE = true;
```

改为：

```js
const DIDI_DEBUG_MODE = false;
```

## 卸载

```bash
bash uninstall.sh
openclaw gateway restart
```

## 技术架构

```
用户说"叫车" → AI 调用 didi_ride 工具
                    ↓
         POI 搜索 → 价格估算 → 路线查询
                    ↓
         发送飞书交互卡片（选车型 + 价格）
                    ↓
         用户点按钮 → card.action.trigger 回调
                    ↓
         handler.js → 滴滴 MCP 下单/查询/取消
                    ↓
         发送新卡片（等待接单/司机信息/行程状态）
```

核心链路：
- **client.js** - 滴滴 MCP JSON-RPC 2.0 HTTP 客户端，封装所有 API 调用
- **cards.js** - 飞书 CardKit v2 交互卡片模板（7 种状态卡片）
- **register.js** - OpenClaw 工具注册 + 查价流程编排
- **handler.js** - 飞书卡片按钮回调处理（叫车/刷新/取消）

## License

MIT
