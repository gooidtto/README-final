# Web UI + Railway + 动态订阅生成

> **推荐部署方式：直接使用当前 GitHub 仓库 / Railway Deploy 按钮。**

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

![Railway 选择仓库并部署](https://github.com/user-attachments/assets/4bb8b5c0-49ec-4f2e-9a2e-0a0c397a5752)

---

# 2. Railway 基础配置

第一次部署时，Railway 需要完成服务、Volume 和 Networking 的初始化。

## Volume

添加 Persistent Volume：

```text
Mount Path:
/data
```

`/data` 用于保存运行时状态、订阅状态以及持久化身份信息。

---

# 3. Networking

## Gateway Port

统一使用：

```text
8080
```

在 **Settings → Networking** 中创建：

1. **Public Domain**
2. **TCP Proxy**

TCP Proxy 的：

```text
Target Port = 8080
```

![Railway Networking 配置示例](https://github.com/user-attachments/assets/88810187-bb2e-47ea-994c-547c83997e00)

### 节点入口关系

```text
Node 1
Railway Public Domain :443
        ↓
      :8080
        ↓
      10086
```

```text
Node 2 / Node 3 / Node 4
Railway TCP Proxy
        ↓
      :8080
        ↓
10087 / 10088 / 10089
```

> **不要手动写死 Railway Domain 或 TCP Proxy 地址。**
>
> 程序启动时读取当前 Deployment Networking，并根据当前部署动态生成 endpoint。

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

**第一次部署出现短暂 Networking 未就绪，不代表部署失败。**

正常情况下等待程序自动完成 discovery 即可。

只有整个等待窗口结束后仍无法获得有效的当前 Deployment Networking，才检查 Railway Networking 配置。

### 不建议的操作

不要因为第一次启动时短暂没有读取到 Networking 就立即：

- 删除 Public Domain
- 删除 TCP Proxy
- 重新创建服务
- 修改节点配置
- 修改订阅配置

优先等待自动 retry 完成。

---

# 5. Scale / Regions & Replicas

在 Railway：

```text
Scale
 ↓
Regions & Replicas
```

选择部署 Region。

Region 可以根据实际需求调整。

![Railway Regions & Replicas](https://github.com/user-attachments/assets/c885ecdf-dfc8-439d-9dcb-058ac6d40e37)

选择完成后点击左上角：

```text
Deploy
```

---

# 6. Node 5 Cloudflare（可选）

默认部署不强制启用 Node 5。

如果需要第 5 个节点，在 Railway Variables 中配置：

```text
CLOUDFLARE_TUNNEL_TOKEN
CLOUDFLARE_TUNNEL_ID
CLOUDFLARE_PUBLIC_HOSTNAME
CLOUDFLARE_ORIGIN_SERVICE
CLOUDFLARE_XHTTP_PORT
CLOUDFLARE_XHTTP_PATH
```

只有 Cloudflare 所需配置完整时，Node 5 才加入订阅：

```text
CLOUDFLARE_CONFIG_STATE=enabled
CLOUDFLARE_XHTTP=enabled
```

Node 5 使用：

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
Node 5
```

> Node 5 不使用旧的 WebSocket 配置。

---

# 7. 完成部署并获取订阅

完成整个部署后，进入 Railway Shell / Terminal。

![Railway 部署完成](https://github.com/user-attachments/assets/9540145a-db55-4c0e-8ad9-28d729e3e5d1)

执行：

```bash
cat /data/subscription_url.txt
```

复制输出的订阅链接，导入支持 VLESS 的客户端。

---

# 8. 如何判断部署真正成功？

不要只看 Railway 显示：

```text
Deployment successful
```

建议同时确认 Deploy Logs：

```text
RAILWAY_NETWORKING_SOURCE=current-deployment-environment
RAILWAY_NETWORKING_AUTHORITATIVE=true
PRODUCTION_GUARD=PASS
SUBSCRIPTION_ENDPOINT_INVARIANT=PASS
```

4 节点时：

```text
RUNTIME_NODE_COUNT=4
SUBSCRIPTION_COUNT=4
```

Cloudflare 配置完整时：

```text
RUNTIME_NODE_COUNT=5
SUBSCRIPTION_COUNT=5
```

---

# 9. 订阅节点顺序

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

# 10. 健康检查

## `/health`

用于检查进程级健康状态。

```text
/health
```

## `/ready`

用于检查完整运行就绪状态，包括运行时配置、订阅生成、Endpoint 校验和 Xray listener；Cloudflare Node 5 启用时也纳入检查。

```text
/ready
```

只有 `/ready` 正常后，才建议使用最终订阅。

---

# 11. Runtime 生命周期

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

`/data` 中的持久化状态用于 identity continuity、change detection 和 runtime state，而不是恢复已经过期的 Railway endpoint。

---

# 12. 常见问题

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

因为这三个节点需要 TCP/REALITY 传输入口：

```text
Node 2 = RAW REALITY
Node 3 = XHTTP REALITY
Node 4 = gRPC REALITY
```

因此不能简单把它们全部改成 Railway Public HTTPS Domain。

---

# 13. Security

严禁提交以下内容到 Git：

```text
Cloudflare Tunnel Token
Private Keys
UUID / Private Credentials
Subscription URLs containing secrets
Railway Deployment Secrets
/data runtime state
```

统一使用 Railway Variables 与 Persistent Volume `/data` 保存部署相关秘密和运行时状态。

---

# 14. Repository-Native Stable

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

# 15. 正式版本

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

后续涉及节点传输、Gateway routing、Subscription format、Railway Networking authority、Cloudflare XHTTP 或 Runtime identity 的修改，应先完成独立验证，再合并回正式基线。

---

# ⚠️ 使用说明

本项目仅供学习、研究和合法的网络技术测试使用。

请遵守所在地区法律法规、Railway、Cloudflare 及相关服务的使用条款。
