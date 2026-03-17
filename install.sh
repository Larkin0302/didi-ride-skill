#!/bin/bash
# =============================================================================
# didi-ride-skill 一键安装脚本
#
# 将滴滴打车技能安装到 OpenClaw 飞书插件中。
# 安装完成后在飞书里对龙虾说"帮我叫个车"即可使用。
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

PLUGIN_DIR="$HOME/.openclaw/extensions/feishu-openclaw-plugin"
TOOL_DIR="$PLUGIN_DIR/src/tools/didi-ride"
SKILL_DIR="$HOME/.openclaw/skills/didi-ride"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "🦞 didi-ride-skill 安装程序"
echo "=========================="
echo ""

# -------------------------------------------------------------------------
# Step 1: 前置检查
# -------------------------------------------------------------------------

info "检查前置条件..."

if [ ! -d "$PLUGIN_DIR" ]; then
    fail "未找到飞书插件目录: $PLUGIN_DIR\n   请先安装 feishu-openclaw-plugin（openclaw plugin install feishu-openclaw-plugin）"
fi

if [ ! -f "$PLUGIN_DIR/index.js" ]; then
    fail "飞书插件 index.js 不存在，请确认插件安装完整"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    fail "未找到 openclaw.json: $CONFIG_FILE\n   请确认 OpenClaw 已初始化"
fi

ok "前置检查通过"

# -------------------------------------------------------------------------
# Step 2: 复制源文件
# -------------------------------------------------------------------------

info "复制源文件到插件目录..."

mkdir -p "$TOOL_DIR"
cp "$SCRIPT_DIR/src/client.js"   "$TOOL_DIR/"
cp "$SCRIPT_DIR/src/cards.js"    "$TOOL_DIR/"
cp "$SCRIPT_DIR/src/handler.js"  "$TOOL_DIR/"
cp "$SCRIPT_DIR/src/register.js" "$TOOL_DIR/"

ok "源文件已复制到 $TOOL_DIR"

info "复制 SKILL.md..."

mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DIR/"

ok "SKILL.md 已复制到 $SKILL_DIR"

# -------------------------------------------------------------------------
# Step 3: Patch index.js（追加 import + 注册）
# -------------------------------------------------------------------------

INDEX_FILE="$PLUGIN_DIR/index.js"

info "检查 index.js 是否需要 patch..."

if grep -q 'didi-ride/register.js' "$INDEX_FILE"; then
    ok "index.js 已包含 didi-ride import，跳过"
else
    info "Patching index.js..."

    # 在最后一个 import 行之后插入 didi-ride import
    # 找到 "import { trace }" 这行（最后一个 import），在其后插入
    sed -i.bak '/^import { trace } from "\.\/src\/core\/trace\.js";/a\
import { registerDiDiRideTool } from "./src/tools/didi-ride/register.js";' "$INDEX_FILE"

    ok "index.js import 已添加"
fi

# 检查注册调用
if grep -q 'registerDiDiRideTool(api)' "$INDEX_FILE"; then
    ok "index.js 已包含 registerDiDiRideTool 调用，跳过"
else
    # 在 registerFeishuOAuthBatchAuthTool(api) 之后插入
    sed -i.bak '/registerFeishuOAuthBatchAuthTool(api);/a\
        // Register DiDi ride tool (query pricing + send interactive card)\
        registerDiDiRideTool(api);' "$INDEX_FILE"

    ok "index.js 注册调用已添加"
fi

# 清理备份文件
rm -f "$INDEX_FILE.bak"

# -------------------------------------------------------------------------
# Step 4: Patch monitor.js（追加 didi_ 卡片路由）
# -------------------------------------------------------------------------

MONITOR_FILE="$PLUGIN_DIR/src/channel/monitor.js"

info "检查 monitor.js 是否需要 patch..."

if grep -q 'action.startsWith("didi_")' "$MONITOR_FILE"; then
    ok "monitor.js 已包含 didi_ 路由，跳过"
else
    info "Patching monitor.js..."

    # 在 "card.action.trigger" 的 try { 之后、return await handleCardAction 之前插入
    sed -i.bak '/\"card\.action\.trigger\":/,/return await handleCardAction/ {
        /return await handleCardAction/i\
                    const action = data?.action?.value?.action;\
                    if (typeof action === "string" \&\& action.startsWith("didi_")) {\
                        const { handleDiDiCardAction } = await import("../tools/didi-ride/handler.js");\
                        return await handleDiDiCardAction(data, cfg, accountId);\
                    }
    }' "$MONITOR_FILE"

    ok "monitor.js didi_ 路由已添加"
fi

rm -f "$MONITOR_FILE.bak"

# -------------------------------------------------------------------------
# Step 5: 配置 DIDI_MCP_KEY
# -------------------------------------------------------------------------

info "检查 DIDI_MCP_KEY 配置..."

if python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
key = cfg.get('env', {}).get('DIDI_MCP_KEY', '')
if key:
    print(f'已配置: {key[:8]}...')
    sys.exit(0)
else:
    sys.exit(1)
" 2>/dev/null; then
    ok "DIDI_MCP_KEY 已配置"
else
    echo ""
    echo -e "${YELLOW}需要配置滴滴 MCP API Key${NC}"
    echo "申请地址: https://mcp.didichuxing.com"
    echo ""
    read -p "请输入你的 DIDI_MCP_KEY（留空跳过，后续可手动配置）: " DIDI_KEY

    if [ -n "$DIDI_KEY" ]; then
        python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
if 'env' not in cfg:
    cfg['env'] = {}
cfg['env']['DIDI_MCP_KEY'] = '$DIDI_KEY'
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print('OK')
"
        ok "DIDI_MCP_KEY 已写入 openclaw.json"
    else
        warn "跳过 API Key 配置。你可以稍后手动在 openclaw.json 的 env 中添加 DIDI_MCP_KEY"
    fi
fi

# -------------------------------------------------------------------------
# Step 6: 沙箱模式提示
# -------------------------------------------------------------------------

echo ""
info "当前默认使用沙箱模式（模拟数据，不产生真实订单）"
info "切换到正式环境：编辑 $TOOL_DIR/client.js，将 DIDI_DEBUG_MODE 改为 false"

# -------------------------------------------------------------------------
# Done!
# -------------------------------------------------------------------------

echo ""
echo "================================"
echo -e "${GREEN}🦞 安装完成！${NC}"
echo "================================"
echo ""
echo "下一步："
echo "  1. 重启 gateway:  openclaw gateway restart"
echo "  2. 在飞书里对龙虾说: \"帮我叫个车从长治客运西站到长治东站\""
echo ""
