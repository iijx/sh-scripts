#!/bin/bash

# 加载 .env 文件（注意：必须用 source，不能直接执行）
set -a  # 自动 export 所有变量（可选但推荐）
source .env
set +a

# ====== 全局配置 ======
SSH_KEY="$HOME/.ssh/id_ed25519"         # 你的 SSH 私钥路径

# 生产环境配置
PROD_VPS_USER=$PROD_VPS_USER        # 生产环境 VPS 登录用户名
PROD_VPS_HOST=$PROD_VPS_HOST        # 生产环境 VPS 公网 IP

# 测试环境配置
DEV_VPS_USER=$DEV_VPS_USER          # 测试环境 VPS 登录用户名
DEV_VPS_HOST=$DEV_VPS_HOST          # 测试环境 VPS 公网 IP

# ====== 命令行参数处理 (stop/restart) ======
# 用法: ./ssh-tunnel.sh restart  (先停止旧隧道，再启动新隧道)
# 用法: ./ssh-tunnel.sh stop     (仅停止所有隧道)
if [[ "$1" == "stop" || "$1" == "restart" ]]; then
    echo "🛑 正在停止所有 autossh 隧道..."
    # 杀掉所有 autossh 进程（包括生产环境和测试环境）
    pkill -f "autossh.*-L" || true
    
    if [[ "$1" == "stop" ]]; then
        echo "✅ 已停止所有隧道。"
        exit 0
    fi
    
    echo "⏳ 旧进程已清理，准备启动新配置..."
    sleep 2
fi

# 1. 环境检查（只做一次）
if ! command -v autossh &> /dev/null; then
  echo "❌ 错误: autossh 未安装。请运行: brew install autossh"
  exit 1
fi

# 检查 SSH 密钥是否存在（如果用密钥登录）
if [[ -n "$SSH_KEY" && ! -f "$SSH_KEY" ]]; then
  echo "❌ 错误: SSH 密钥文件不存在: $SSH_KEY"
  exit 1
fi

# 2. 定义启动函数
start_tunnel() {
    local SERVICE_NAME=$1  # 服务名称（用于日志）
    local L_PORT=$2        # 本地端口
    local R_PORT=$3        # 远程端口
    local VPS_USER=$4      # VPS 登录用户名
    local VPS_HOST=$5      # VPS 公网 IP
    local EXTRA_MSG=$6     # (可选) 成功后的额外提示信息

    # 0. 参数自检：如果端口或连接信息未定义，则直接跳过
    if [[ -z "$L_PORT" || -z "$R_PORT" || -z "$VPS_USER" || -z "$VPS_HOST" ]]; then
        echo "⚠️  [${SERVICE_NAME}] 配置缺失 (变量未定义)，跳过启动。"
        return 0
    fi

    echo "--------------------------------------------------"
    echo "🚀 正在启动 [${SERVICE_NAME}] 隧道..."
    
    # 检查该端口是否已被占用/运行中
    # 使用更精确的匹配模式，防止误判
    if pgrep -f "autossh.*$L_PORT:127.0.0.1:$R_PORT" > /dev/null; then
        echo "⚠️  [${SERVICE_NAME}] 隧道已在运行 (本地端口: $L_PORT)"
        return 0
    fi

    echo "   配置: 本地 $L_PORT -> $VPS_HOST:$R_PORT"

    # 启动 autossh
    # -M 0: 禁用 autossh 自带的监控端口
    # -f: 后台运行
    # -N: 不执行远程命令
    # -T: 禁用伪终端
    if [[ -n "$SSH_KEY" ]]; then
        autossh -M 0 -fNT -L $L_PORT:127.0.0.1:$R_PORT \
          -i "$SSH_KEY" \
          -o "UserKnownHostsFile=/dev/null" \
          -o "StrictHostKeyChecking=no" \
          -o "ServerAliveInterval=30" \
          -o "ServerAliveCountMax=3" \
          $VPS_USER@$VPS_HOST
    else
        # 密码登录模式
        autossh -M 0 -fNT -L $L_PORT:127.0.0.1:$R_PORT \
          -o "UserKnownHostsFile=/dev/null" \
          -o "StrictHostKeyChecking=no" \
          -o "ServerAliveInterval=30" \
          -o "ServerAliveCountMax=3" \
          $VPS_USER@$VPS_HOST
    fi

    # 简单检查
    sleep 1
    if pgrep -f "autossh.*$L_PORT:127.0.0.1:$R_PORT" > /dev/null; then
        echo "✅ [${SERVICE_NAME}] 启动成功"
        if [[ -n "$EXTRA_MSG" ]]; then
            echo "   $EXTRA_MSG"
        fi
    else
        echo "❌ [${SERVICE_NAME}] 启动失败"
    fi
}

# ====== 3. 配置并启动所有隧道 ======

# 格式: start_tunnel "服务名" "$本地端口变量" "$远程端口变量" "$VPS_USER" "$VPS_HOST" "可选提示信息"

echo "=================================================="
echo "🌍 生产环境隧道"
echo "=================================================="

# 生产环境隧道
# start_tunnel "MongoDB (生产)" "$LOCAL_PROD_MONGO_PORT" "$MONGO_PORT" "$PROD_VPS_USER" "$PROD_VPS_HOST" "mongodb prod tunnel started"
start_tunnel "Postgres (生产)" "$LOCAL_PROD_POSTGRES_PORT" "$POSTGRES_PORT" "$PROD_VPS_USER" "$PROD_VPS_HOST" "postgres prod tunnel started"
start_tunnel "Redis (生产)" "$LOCAL_PROD_REDIS_PORT" "$REDIS_PORT" "$PROD_VPS_USER" "$PROD_VPS_HOST" "连接: redis-cli -p $LOCAL_PROD_REDIS_PORT"

echo ""
echo "=================================================="
echo "🧪 测试环境隧道"
echo "=================================================="

# 测试环境隧道
# start_tunnel "MongoDB (测试)" "$LOCAL_DEV_MONGO_PORT" "$MONGO_PORT" "$DEV_VPS_USER" "$DEV_VPS_HOST" "mongodb dev tunnel started"
start_tunnel "Postgres (测试)" "$LOCAL_DEV_POSTGRES_PORT" "$POSTGRES_PORT" "$DEV_VPS_USER" "$DEV_VPS_HOST" "postgres dev tunnel started"
start_tunnel "Redis (测试)" "$LOCAL_DEV_REDIS_PORT" "$REDIS_PORT" "$DEV_VPS_USER" "$DEV_VPS_HOST" "连接: redis-cli -p $LOCAL_DEV_REDIS_PORT"

echo "--------------------------------------------------"
echo "🎉 所有任务执行完毕。"
