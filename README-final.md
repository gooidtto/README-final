# Railway Xray Gateway

基于已验证生产基线的 Railway 单服务部署项目。

项目提供：

- Railway 动态 Networking 发现
- Xray Gateway
- 4 个 Railway 基础节点
- 可选的第 5 个 Cloudflare XHTTP TLS 节点
- 动态订阅生成
- `/health` 与 `/ready` 健康检查
- 首次 Railway Networking provisioning 的自动重试与退避
- Repository-Native Stable 运行时版本身份

> **推荐部署方式：直接使用当前 GitHub 仓库 / Railway Deploy 按钮。不要使用旧 ZIP 作为长期部署源。**

---

# 🚀 Deploy on Railway

## 1. 一键部署

点击：

<p align="center">
  <a href="https://railway.com/new/github?utm_source=github&utm_medium=readme&utm_campaign=railway-portable">
    <img src="https://railway.com/button.svg" alt="Deploy on Railway" width="260">
  </a>
</p>

选择仓库后刷新 Railway 页面，确认已经进入项目。

---

# 2. Railway 基础配置

第一次部署时，Railway 需要完成服务、Volume 和 Networking 的初始化。

## Volume

添加 Persistent Volume：

```text
Mount Path:
/data
```

`/data` 用于保存：

- 运行时身份
- UUID / 密钥等生成状态
- runtime manifest
- 订阅状态
- 日志及其他运行时状态

不要把 `/data` 中的运行时秘密提交到 Git。

---

# 3. Networking

## Gateway Port

统一使用：

```text
8080
```

创建：

1. **Public Domain**
2. **TCP Proxy**

TCP Proxy 的：

```text
Target Port = 8080
```

> Node 2、Node 3、Node 4 使用 Railway TCP Proxy 作为客户端 TCP 入口；Node 1 使用 Railway HTTPS/Public Domain；Node 5 使用 Cloudflare（启用后）。

### 不要手动写死 Railway 地址

不要在代码或变量中写死：

```text
*.up.railway.app
*.proxy.rlwy.net
```

项目会在运行时读取当前 Deployment 的 Railway Networking 信息。

---

# 4. 首次部署为什么可能需要等待？

Railway 首次创建 Public Domain / TCP Proxy 后，Networking 资源可能比容器启动稍晚完成。

本项目已经加入 **Networking Race Hardened**：

```text
启动
 ↓
读取当前 Deployment Networking
 ↓
Networking 未就绪？
 ↓
2s
 ↓
4s
 ↓
8s
 ↓
16s
 ↓
32s
 ↓
60s
 ↓
最多等待 180s
 ↓
Networking READY
 ↓
写入 current-deployment-environment snapshot
 ↓
Production Guard
 ↓
生成节点
 ↓
Endpoint Invariant
 ↓
Xray 配置检查
 ↓
启动 Xray / Gateway
```

因此：

**第一次部署出现短暂 Networking 未就绪，不代表部署失败。**

正常情况下等待程序自动完成 discovery 即可。

只有在整个等待窗口结束后仍然无法获得有效的当前 Deployment Networking，才应检查 Railway Networking 配置。

### 不建议的操作

不要因为第一次启动时短暂没有读取到 Networking 就立即：

- 删除 Public Domain
- 删除 TCP Proxy
- 重新创建服务
- 修改节点配置
- 修改订阅配置

优先等待自动 retry 完成。

---

# 5. 如何确认 Networking 已经正确？

查看 Railway Deploy Logs。

应看到类似：

```text
RAILWAY_NETWORKING_SOURCE=current-deployment-environment
RAILWAY_NETWORKING_AUTHORITATIVE=true
RAILWAY_CURRENT_PUBLIC=xxxx.up.railway.app
```

并且：

```text
PRODUCTION_GUARD=PASS
```

之后应看到：

```text
SUBSCRIPTION_ENDPOINT_INVARIANT=PASS
```

最终节点数量应为：

```text
4
```

或者 Cloudflare 配置完整时：

```text
5
```

---

# 6. 节点结构

## Node 1

```text
VLESS
XHTTP
TLS
```

入口：

```text
Railway Public Domain :443
        ↓
      :8080
        ↓
      10086
```

---

## Node 2

```text
VLESS
RAW TCP
REALITY
Vision
```

入口：

```text
Railway TCP Proxy
        ↓
      :8080
        ↓
      10087
```

---

## Node 3

```text
VLESS
XHTTP
REALITY
```

入口：

```text
Railway TCP Proxy
        ↓
      :8080
        ↓
      10088
```

---

## Node 4

```text
VLESS
gRPC
REALITY
```

入口：

```text
Railway TCP Proxy
        ↓
      :8080
        ↓
      10089
```

---

## Node 5（可选）

Node 5 只有在 Cloudflare 配置完整时才启用：

```text
VLESS
XHTTP
TLS
Cloudflare
```

公网路径：

```text
Internet
   ↓
Cloudflare
   ↓
Cloudflare Tunnel
   ↓
local XHTTP origin
```

Node 5 不使用旧的 WebSocket 配置。

---

# 7. Node 5 Cloudflare 配置

如果需要第 5 个节点，在 Railway Variables 中配置：

```text
CLOUDFLARE_TUNNEL_TOKEN
CLOUDFLARE_TUNNEL_ID
CLOUDFLARE_PUBLIC_HOSTNAME
CLOUDFLARE_ORIGIN_SERVICE
CLOUDFLARE_XHTTP_PORT
CLOUDFLARE_XHTTP_PATH
```

推荐使用明确的：

```text
CLOUDFLARE_XHTTP_*
```

变量名称。

旧的：

```text
WS_PORT
WS_PATH
```

仅作为兼容性 fallback，不建议新部署继续使用。

### Node 5 启用条件

只有 Cloudflare 所需配置全部完整时：

```text
CLOUDFLARE_CONFIG_STATE=enabled
CLOUDFLARE_XHTTP=enabled
```

运行时才加入：

```text
Node 5
```

否则：

```text
CLOUDFLARE_CONFIG_STATE=disabled
```

项目正常运行 4 个 Railway 节点，不会因为缺少 Cloudflare 配置而导致整个部署失败。

---

# 8. Scale / Regions & Replicas

在 Railway：

```text
Scale
 ↓
Regions & Replicas
```

选择部署 Region。

Region 可以根据实际需求调整。

完成后点击：

```text
Deploy
```

---

# 9. 获取订阅

部署成功后，可以进入 Railway Shell / Terminal。

执行：

```bash
cat /data/subscription_url.txt
```

复制输出的订阅链接，导入支持 VLESS 的客户端。

---

# 10. 如何判断部署真正成功？

不要只看 Railway 显示：

```text
Deployment successful
```

建议同时确认以下日志。

### Networking

```text
RAILWAY_NETWORKING_SOURCE=current-deployment-environment
RAILWAY_NETWORKING_AUTHORITATIVE=true
```

### Production Guard

```text
PRODUCTION_GUARD=PASS
```

### 节点数量

4 节点：

```text
RUNTIME_NODE_COUNT=4
SUBSCRIPTION_COUNT=4
```

5 节点：

```text
RUNTIME_NODE_COUNT=5
SUBSCRIPTION_COUNT=5
```

### Endpoint

```text
SUBSCRIPTION_ENDPOINT_INVARIANT=PASS
```

### Readiness

```text
/ready
```

应返回 HTTP `200`。

---

# 11. 健康检查

## `/health`

用于检查进程级健康状态。

```text
/health
```

## `/ready`

用于检查完整运行就绪状态，包括：

- 运行时配置
- 订阅生成
- Endpoint 校验
- Xray listener
- Cloudflare Node 5（启用时）

```text
/ready
```

只有 `/ready` 正常后，才建议使用最终订阅。

---

# 12. Runtime 生命周期

每次启动都遵循：

```text
当前 Deployment Networking
        ↓
Networking discovery / retry
        ↓
Runtime generation
        ↓
Subscription generation
        ↓
Endpoint / UUID / Node-count validation
        ↓
Production Guard
        ↓
Xray configuration test
        ↓
Local listener readiness
        ↓
Gateway
```

当前 Deployment Networking 是 authoritative source。

`/data` 中的持久化状态用于：

- identity continuity
- change detection
- runtime state

而不是用于恢复已经过期的 Railway endpoint。

---

# 13. 订阅节点顺序

正常 4 节点：

```text
1. railway-xhttp-tls
2. raw-reality-vision
3. xhttp-reality
4. grpc-reality
```

Cloudflare 配置完整时：

```text
1. railway-xhttp-tls
2. raw-reality-vision
3. xhttp-reality
4. grpc-reality
5. cloudflare-xhttp-tls
```

---

# 14. 常见问题

## Q1：第一次部署 Networking 显示异常怎么办？

先等待。

本版本会自动进行 Networking discovery retry，最多等待约 180 秒。

如果最终仍然失败，再检查：

- Public Domain 是否存在
- TCP Proxy 是否存在
- TCP Proxy Target Port 是否为 `8080`
- Service 是否已经重新部署
- Railway 当前 Deployment 是否已经获得新的 Networking 环境变量

---

## Q2：重新创建 Networking 后为什么需要重新部署？

Railway Networking 发生变化后，当前 Deployment 需要重新获得新的环境状态。

推荐：

```text
修改 / 创建 Networking
        ↓
Redeploy
        ↓
读取 current-deployment-environment
        ↓
重新生成 runtime
        ↓
重新生成 subscription
```

不要继续使用旧的 `/data` endpoint 作为权威地址。

---

## Q3：为什么有时只有 4 个节点？

如果 Cloudflare 配置没有完整提供：

```text
CLOUDFLARE_TUNNEL_TOKEN
CLOUDFLARE_TUNNEL_ID
CLOUDFLARE_PUBLIC_HOSTNAME
CLOUDFLARE_ORIGIN_SERVICE
CLOUDFLARE_XHTTP_PORT
CLOUDFLARE_XHTTP_PATH
```

Node 5 会自动 disabled。

这是正常行为。

---

## Q4：为什么 Node 2–4 使用 TCP Proxy？

因为这三个节点需要 TCP/REALITY 传输入口。

它们不是普通 HTTP ingress：

```text
Node 2 = RAW REALITY
Node 3 = XHTTP REALITY
Node 4 = gRPC REALITY
```

因此不能简单把它们全部改成 Railway Public HTTPS Domain。

---

# 15. Security

严禁提交以下内容到 Git：

```text
Cloudflare Tunnel Token
Private Keys
UUID / Private Credentials
Subscription URLs containing secrets
Railway Deployment Secrets
/data runtime state
```

统一使用：

```text
Railway Variables
+
Persistent Volume /data
```

保存部署相关秘密和运行时状态。

---

# 16. Repository-Native Stable

运行时版本身份不依赖旧 ZIP 上传名称。

系统按照 repository / tag / commit 等当前仓库信息推导：

```text
RELEASE
BUILD_ID
SOURCE_BUILD
```

三者共享同一个 runtime-derived identity。

历史 baseline：

```text
upload-baseline-2026-08-24
```

仅作为历史基线名称保留，不作为新账户部署时的固定身份来源。

---

# 17. 正式版本

当前正式基线：

```text
Repository-Native Stable
+
Networking Race Hardened
```

正式封版：

```text
repository-native-stable-networking-race-hardened.zip
```

后续修改如涉及：

- 节点传输
- Gateway routing
- Subscription format
- Railway Networking authority
- Cloudflare XHTTP
- Runtime identity

应先完成独立验证，再合并回正式基线。

---

# ⚠️ 使用说明

本项目仅供学习、研究和合法的网络技术测试使用。

请遵守所在地区法律法规、Railway、Cloudflare 及相关服务的使用条款。
