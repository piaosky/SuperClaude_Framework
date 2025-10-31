# MCP Gateway故障排除知识库

## 快速诊断检查清单

### 🚨 紧急故障处理
**症状**: 容器启动失败
```bash
# 1. 立即执行
docker compose down
docker system prune -f
docker network prune -f

# 2. 检查配置文件语法
docker compose config

# 3. 重新启动
docker compose up -d
```

### 🔍 系统状态检查
```bash
# 容器状态
docker compose ps

# 服务日志
docker compose logs --tail=20

# 网络状态
docker network ls

# 资源使用
docker system df
```

## 常见问题和解决方案

### 问题1: Docker Secrets配置冲突
**症状**:
```
ERROR: Secrets file not found: ./.secrets/db_password.txt
```

**解决方案**:
```yaml
# docker-compose.yml 中注释掉开发环境不需要的secrets
# secrets:
#   db_password:
#     file: ./.secrets/db_password.txt
```

### 问题2: Gateway显示"0 tools listed"
**症状**: MCP Gateway启动但无可用工具

**解决方案**:
```json
// mcp-config.json 中确保正确配置
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    }
  }
}
```

### 问题3: 容器网络连接问题
**症状**: 容器间无法通信

**解决方案**:
```bash
# 重建网络
docker compose down
docker network prune -f
docker compose up -d

# 验证网络
docker network inspect airis-mcp-gateway_default
```

### 问题4: API服务无响应
**症状**: API调用超时

**解决方案**:
```bash
# 检查API健康状态
curl -f http://localhost:9000/health

# 重启API服务
docker compose restart api
```

## 核心配置模板

### 开发环境docker-compose.yml
```yaml
version: '3.8'
services:
  mcp-gateway:
    image: docker/mcp-gateway:latest
    container_name: airis-mcp-gateway-gateway
    ports:
      - "9090:9090"
    environment:
      - GATEWAY_PORT=9090
    volumes:
      - ./mcp-config.json:/app/mcp-config.json:ro
    networks:
      - airis-mcp-gateway_default
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9090/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    # 注意: 开发环境注释掉secrets配置

  api:
    build: ./apps/api
    container_name: airis-mcp-gateway-api
    ports:
      - "9000:9000"
    environment:
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@postgres:5432/mcp_gateway
      - API_PORT=9000
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - airis-mcp-gateway_default
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:17-alpine
    container_name: airis-mcp-gateway-postgres
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=mcp_gateway
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - airis-mcp-gateway_default
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:

networks:
  airis-mcp-gateway_default:
    driver: bridge
```

### 基础mcp-config.json
```json
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
```

## 启动和验证流程

### 完整启动流程
```bash
# 1. 清理环境
make clean-all  # 或 docker system prune -f

# 2. 验证配置
docker compose config

# 3. 启动服务
docker compose up -d

# 4. 等待健康检查
sleep 30

# 5. 验证状态
docker compose ps
curl -f http://localhost:9090/health
curl -f http://localhost:9000/health
```

### 功能验证清单
- [ ] Gateway健康检查: `http://localhost:9090/health`
- [ ] API健康检查: `http://localhost:9000/health`
- [ ] UI界面: `http://localhost:5173`
- [ ] MCP服务器列表: `curl -s http://localhost:9090/api/v1/mcp/servers`
- [ ] 服务状态: `curl -s http://localhost:9090/api/v1/server-states`

## 性能优化建议

### 资源管理
```bash
# 定期清理
docker system prune -f --volumes
docker network prune -f

# 监控资源使用
docker stats --no-stream
```

### 配置优化
- 使用健康检查避免假阳性状态
- 配置适当的重启策略
- 优化网络配置减少延迟

### 监控设置
```bash
# 实时监控
docker compose logs -f

# 服务状态监控
watch -n 5 'docker compose ps'
```

## 安全考虑

### 开发环境安全
- 不要在生产环境使用默认密码
- 限制容器权限
- 定期更新基础镜像

### 网络安全
- 使用内部网络进行服务间通信
- 限制暴露端口
- 配置适当的防火墙规则

## 故障排除命令速查

```bash
# 快速重启
docker compose restart

# 查看特定服务日志
docker compose logs [service-name]

# 进入容器调试
docker compose exec [service-name] sh

# 检查网络连接
docker network inspect [network-name]

# 验证配置文件
docker compose config

# 清理并重建
docker compose down
docker system prune -f
docker compose up -d --build
```

---
**最后更新**: 2025-11-01
**适用版本**: AIRIS MCP Gateway v2.0+
**维护状态**: 活跃