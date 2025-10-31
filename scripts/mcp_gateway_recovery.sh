#!/bin/bash

# MCP Gateway 快速恢复脚本
# 用于修复常见的MCP Gateway启动问题
# 作者: Claude Code Assistant
# 创建日期: 2025-11-01

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在正确的目录
check_directory() {
    log_info "检查工作目录..."
    if [[ ! -f "docker-compose.yml" ]] && [[ ! -f "docker-compose.yaml" ]]; then
        log_error "未找到docker-compose文件，请在MCP Gateway项目目录中运行此脚本"
        exit 1
    fi
    log_success "目录检查通过"
}

# 停止所有服务
stop_services() {
    log_info "停止所有服务..."
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
    log_success "服务已停止"
}

# 清理Docker资源
clean_docker_resources() {
    log_info "清理Docker资源..."

    # 清理停止的容器
    docker container prune -f >/dev/null 2>&1 || true

    # 清理未使用的网络
    docker network prune -f >/dev/null 2>&1 || true

    # 清理未使用的镜像（可选）
    if [[ "$1" == "--deep-clean" ]]; then
        log_warning "执行深度清理，将删除未使用的镜像..."
        docker image prune -f >/dev/null 2>&1 || true
    fi

    log_success "Docker资源清理完成"
}

# 验证配置文件
validate_config() {
    log_info "验证Docker Compose配置..."

    if docker compose config >/dev/null 2>&1; then
        log_success "配置文件验证通过"
    else
        log_error "配置文件有语法错误，请检查docker-compose.yml"
        docker compose config
        exit 1
    fi
}

# 检查并创建必要的配置
check_configs() {
    log_info "检查配置文件..."

    # 检查mcp-config.json是否存在
    if [[ ! -f "mcp-config.json" ]]; then
        log_warning "mcp-config.json不存在，创建基础配置..."
        cat > mcp-config.json << 'EOF'
{
  "mcpServers": {
    "time": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--network=airis-mcp-gateway_default", "mcp/time"]
    },
    "fetch": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--network=airis-mcp-gateway_default", "mcp/fetch"]
    },
    "filesystem": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "-v", "/Users/zhoujian:/workspace", "mcp/filesystem"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    },
    "sequentialthinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
EOF
        log_success "已创建基础mcp-config.json"
    else
        log_success "mcp-config.json已存在"
    fi
}

# 启动服务
start_services() {
    log_info "启动MCP Gateway服务..."

    # 使用docker-compose或docker compose
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    log_success "服务启动命令已执行"
}

# 等待服务健康检查
wait_for_health() {
    log_info "等待服务健康检查..."

    local max_wait=60
    local wait_time=0

    while [[ $wait_time -lt $max_wait ]]; do
        # 检查API健康状态
        if curl -sf http://localhost:9000/health >/dev/null 2>&1; then
            log_success "API服务健康检查通过"
            break
        fi

        echo -n "."
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [[ $wait_time -ge $max_wait ]]; then
        log_warning "健康检查超时，服务可能需要更多时间启动"
    fi
}

# 验证服务状态
verify_services() {
    log_info "验证服务状态..."

    # 检查容器状态
    log_info "容器状态:"
    docker compose ps

    # 检查端口是否开放
    log_info "端口检查:"
    for port in 9090 9000 5173; do
        if nc -z localhost $port 2>/dev/null; then
            log_success "端口 $port 可访问"
        else
            log_warning "端口 $port 不可访问"
        fi
    done
}

# 显示摘要
show_summary() {
    log_info "恢复操作完成！"
    echo ""
    echo "=== 服务访问地址 ==="
    echo "🔗 Gateway API: http://localhost:9090"
    echo "🚀 Management API: http://localhost:9000"
    echo "🎨 Settings UI: http://localhost:5173"
    echo ""
    echo "=== 常用命令 ==="
    echo "查看日志: docker compose logs"
    echo "重启服务: docker compose restart"
    echo "停止服务: docker compose down"
    echo ""
    echo "如仍有问题，请查看日志: docker compose logs --tail=50"
}

# 主函数
main() {
    local deep_clean=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --deep-clean)
                deep_clean=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [--deep-clean] [--help]"
                echo ""
                echo "选项:"
                echo "  --deep-clean  执行深度清理，删除未使用的Docker镜像"
                echo "  --help        显示此帮助信息"
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                echo "使用 --help 查看可用选项"
                exit 1
                ;;
        esac
    done

    echo "🔧 MCP Gateway 快速恢复脚本"
    echo "================================"

    # 执行恢复流程
    check_directory
    stop_services

    if [[ "$deep_clean" == true ]]; then
        clean_docker_resources --deep-clean
    else
        clean_docker_resources
    fi

    validate_config
    check_configs
    start_services
    wait_for_health
    verify_services
    show_summary

    log_success "MCP Gateway恢复完成！"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi