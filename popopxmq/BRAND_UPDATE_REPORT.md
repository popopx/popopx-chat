# POPOPX 品牌更新差异报告

生成日期: 2026-09-29
分支: stable
提交数: 6

## 统计概览

总文件变更数: 306 files changed, 3558 insertions(+), 3558 deletions(-)

## 提交历史

1. **33e27eca** (279 files) - 主要品牌更新
2. **e87baac8** (29 files) - 剩余项目（assetlinks、测试、脚本、函数名）
3. **45ac7ad0** (9 files) - 文档和测试固件
4. **e70f2830** (3 files) - DB迁移SQL函数
5. **476dc21b** (2 files) - URI scheme和cabal依赖
6. **15419516** (1 file) - install.sh更新（保留GitHub URL）

## 变更分类

### 1. 用户可见字符串
- 版本号: "SimpleX XFTP server v" → "POPOPX XFTP server v"
- 服务器描述: "SimpleX SMP server" → "POPOPX SMP server"
- 帮助文本和错误消息

### 2. 运维标识符
- 配置路径: /etc/opt/simplex → /etc/opt/popopx
- 日志路径: /var/simplex → /var/popopx
- Prometheus指标: simplex_smp_* → popopx_smp_*
- INI字段名: admin_simplex → admin_popopx

### 3. URI Scheme
- simplex: → popopx:
- simplex:/contact → popopx:/contact
- simplex:/invitation → popopx:/invitation

### 4. Haskell模块名
- Simplex.Messaging.* → Popopx.Messaging.*
- Simplex.FileTransfer.* → Popopx.FileTransfer.*
- 200+ 模块重命名

### 5. 加密KDF标签
- "SimpleXX3DH" → "POPOPXX3DH"
- "SimpleXRootRatchet" → "POPOPXRootRatchet"
- "SimpleXHeader" → "POPOPXHeader"

### 6. 数据库SQL函数
- simplex_xor_md5_combine → popopx_xor_md5_combine
- simplex_is_valid_text → popopx_is_valid_text

### 7. 内部函数名
- simplexMQVersion → popopxMQVersion
- simplexChat → popopxChat
- simplexConnReqUri → popopxConnReqUri
- simplexShortLink → popopxShortLink
- simplexmqVersionCommit → popopxmqVersionCommit

### 8. 域名和TLD
- simplex.chat → popopx.xyz
- .simplex TLD → .popopx TLD

### 9. Docker和部署
- 服务名: SimpleX Chat → POPOPX
- 卷路径: simplexchat/ → popopx/
- APNS bundle ID: chat.simplex.app → chat.popopx.app

### 10. Web UI
- 标题: "SimpleX File Transfer" → "POPOPX File Transfer"
- 预设键: "simplex" → "popopx"
- 页脚链接和社交媒体

### 11. 安装脚本 (install.sh)
- 脚本名: simplex-servers-* → popopx-servers-*
- 路径: /simplex → /popopx
- 文档URL: simplex.chat/docs → popopx.xyz/docs
- Logo: SimpleX → POPOPX
- **保留**: github.com/simplex-chat/simplexmq (6处GitHub URL)

## 保留项（按指示）

### 1. install.sh 中的 GitHub URL
- github.com/simplex-chat/simplexmq (6处)
  - 脚本下载源
  - 二进制文件下载
  - API调用
  - Issue链接

### 2. 服务器预设地址
- smp4.simplex.im
- xftp1.simplex.im
- xftp1-6.simplexonflux.com
- 其他 *.simplex.im 和 *.simplexonflux.com 地址

### 3. 历史文档
- CHANGELOG.md (版本历史记录)
- rfcs/standard/*.md (协议规范)
- design/*.md (架构决策)
- plans/*.md (实施计划)

## 验证结果

所有类别文件（排除保留项）：
- ✅ 源代码: 0个遗留引用
- ✅ 测试文件: 0个遗留引用
- ✅ 脚本文件: 0个遗留引用
- ✅ Web文件: 0个遗留引用
- ✅ Cabal文件: 0个遗留引用
- ✅ Docker文件: 0个遗留引用
- ✅ DB迁移: 0个遗留引用
- ✅ install.sh: 仅保留GitHub URL

**POPOPX品牌更新已100%完成。**
