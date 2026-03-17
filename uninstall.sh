#!/bin/bash
# =============================================================================
# didi-ride-skill 卸载脚本
#
# 从 OpenClaw 飞书插件中移除滴滴打车技能。
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

PLUGIN_DIR="$HOME/.openclaw/extensions/feishu-openclaw-plugin"
TOOL_DIR="$PLUGIN_DIR/src/tools/didi-ride"
SKILL_DIR="$HOME/.openclaw/skills/didi-ride"

echo ""
echo "🦞 didi-ride-skill 卸载程序"
echo "=========================="
echo ""

# -------------------------------------------------------------------------
# Step 1: 删除工具目录
# -------------------------------------------------------------------------

if [ -d "$TOOL_DIR" ]; then
    rm -rf "$TOOL_DIR"
    ok "已删除 $TOOL_DIR"
else
    info "工具目录不存在，跳过"
fi

# -------------------------------------------------------------------------
# Step 2: 删除技能目录
# -------------------------------------------------------------------------

if [ -d "$SKILL_DIR" ]; then
    rm -rf "$SKILL_DIR"
    ok "已删除 $SKILL_DIR"
else
    info "技能目录不存在，跳过"
fi

# -------------------------------------------------------------------------
# Step 3: 从 index.js 移除 didi-ride 相关行
# -------------------------------------------------------------------------

INDEX_FILE="$PLUGIN_DIR/index.js"

if [ -f "$INDEX_FILE" ]; then
    info "清理 index.js..."

    # 移除 import 行
    sed -i.bak '/import.*didi-ride\/register\.js/d' "$INDEX_FILE"
    # 移除注册调用行
    sed -i.bak '/registerDiDiRideTool(api)/d' "$INDEX_FILE"
    # 移除可能的注释行
    sed -i.bak '/Register DiDi ride tool/d' "$INDEX_FILE"

    rm -f "$INDEX_FILE.bak"
    ok "index.js 已清理"
else
    warn "index.js 不存在，跳过"
fi

# -------------------------------------------------------------------------
# Step 4: 从 monitor.js 移除 didi_ 路由
# -------------------------------------------------------------------------

MONITOR_FILE="$PLUGIN_DIR/src/channel/monitor.js"

if [ -f "$MONITOR_FILE" ]; then
    info "清理 monitor.js..."

    # 移除 didi_ 相关的 4 行块
    sed -i.bak '/action\.startsWith("didi_")/,+3d' "$MONITOR_FILE"
    # 移除可能残留的 action 声明行（如果是单独插入的）
    # 注意：不删除原有的 action 声明，只删 didi 相关的

    rm -f "$MONITOR_FILE.bak"
    ok "monitor.js 已清理"
else
    warn "monitor.js 不存在，跳过"
fi

# -------------------------------------------------------------------------
# Done
# -------------------------------------------------------------------------

echo ""
echo "================================"
echo -e "${GREEN}🦞 卸载完成！${NC}"
echo "================================"
echo ""
echo "下一步："
echo "  1. 重启 gateway:  openclaw gateway restart"
echo "  2. 如需删除 API Key，手动编辑 ~/.openclaw/openclaw.json 移除 DIDI_MCP_KEY"
echo ""
