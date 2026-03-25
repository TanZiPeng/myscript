#!/bin/bash
# ============================================================
#  饥荒联机版服务器 + dst-admin-go 管理面板 一键安装脚本
#  适用系统：Ubuntu 20.04/22.04 / Debian 11+ / CentOS 7/8 / RHEL / Rocky / AlmaLinux
#  管理面板：dst-admin-go (Docker 版)
#  面板地址：安装完成后访问 http://服务器IP:8082
# ============================================================

set -e

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}========== $1 ==========${NC}"; }

# ---- 检查 root 权限 ----
if [ "$EUID" -ne 0 ]; then
    error "请使用 root 权限运行此脚本：sudo bash dst_install.sh"
fi

# ============================================================
# 自动识别发行版
# ============================================================
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID,,}"           # 转小写：ubuntu / debian / centos / rhel / rocky / almalinux
        OS_VERSION="${VERSION_ID}" # 例如 22.04 / 7 / 8 / 9
        OS_NAME="${PRETTY_NAME}"
    else
        error "无法识别操作系统，缺少 /etc/os-release"
    fi

    case "${OS_ID}" in
        ubuntu|debian|linuxmint)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|rocky|almalinux|fedora)
            # CentOS 8+ / RHEL 8+ 使用 dnf，CentOS 7 使用 yum
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        *)
            warn "未经测试的系统：${OS_NAME}"
            read -p "是否继续？(y/n): " CONTINUE
            [[ "$CONTINUE" != "y" ]] && exit 0
            # 降级尝试
            if command -v apt &>/dev/null; then
                PKG_MANAGER="apt"
            elif command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            elif command -v yum &>/dev/null; then
                PKG_MANAGER="yum"
            else
                error "找不到可用的包管理器"
            fi
            ;;
    esac

    info "检测到系统：${OS_NAME}"
    info "包管理器：${PKG_MANAGER}"
}

# ============================================================
# 封装：安装软件包（屏蔽差异）
# ============================================================
pkg_install() {
    case "${PKG_MANAGER}" in
        apt)
            apt-get install -y "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y "$@"
            ;;
    esac
}

pkg_update() {
    case "${PKG_MANAGER}" in
        apt)  apt-get update -y ;;
        dnf)  dnf makecache -y  ;;
        yum)  yum makecache -y  ;;
    esac
}

# ============================================================
# 封装：防火墙操作（ufw / firewalld）
# ============================================================
firewall_open() {
    local PROTO=$1  # tcp / udp
    local PORT=$2   # 端口号

    if command -v ufw &>/dev/null && ufw status | grep -q "Status"; then
        ufw allow "${PORT}/${PROTO}" 2>/dev/null || true
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port="${PORT}/${PROTO}" 2>/dev/null || true
    else
        warn "未检测到防火墙工具，请手动开放端口 ${PORT}/${PROTO}"
    fi
}

firewall_reload() {
    if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
        ufw reload 2>/dev/null || true
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --reload 2>/dev/null || true
    fi
}

# ============================================================
detect_os

section "Step 1: 更新系统 & 安装基础依赖"
# ============================================================
pkg_update

# 各发行版通用依赖（包名略有不同）
case "${PKG_MANAGER}" in
    apt)
        pkg_install curl wget git ca-certificates gnupg lsb-release ufw htop
        ;;
    dnf|yum)
        pkg_install curl wget git ca-certificates gnupg2 firewalld htop
        # CentOS 7 需要 epel
        if [[ "${OS_ID}" == "centos" && "${OS_VERSION}" == "7" ]]; then
            pkg_install epel-release
        fi
        # 启动 firewalld
        systemctl enable firewalld --now 2>/dev/null || true
        ;;
esac

info "基础依赖安装完成"

# ============================================================
section "Step 2: 安装 Docker"
# ============================================================

if command -v docker &>/dev/null; then
    info "Docker 已安装，版本：$(docker --version)"
else
    info "开始安装 Docker..."

    case "${PKG_MANAGER}" in
        apt)
            install -m 0755 -d /etc/apt/keyrings

            # Ubuntu / Debian 分别使用不同的 GPG 源
            if [[ "${OS_ID}" == "ubuntu" ]]; then
                DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
            else
                DOCKER_REPO_URL="https://download.docker.com/linux/debian"
            fi

            curl -fsSL "${DOCKER_REPO_URL}/gpg" \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                ${DOCKER_REPO_URL} $(lsb_release -cs) stable" \
                | tee /etc/apt/sources.list.d/docker.list > /dev/null

            apt-get update -y
            pkg_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;

        dnf|yum)
            pkg_install yum-utils 2>/dev/null || pkg_install dnf-utils 2>/dev/null || true

            if [[ "${OS_ID}" == "centos" && "${OS_VERSION}" == "7" ]]; then
                yum-config-manager --add-repo \
                    https://download.docker.com/linux/centos/docker-ce.repo
                pkg_install docker-ce docker-ce-cli containerd.io
            else
                # CentOS 8 / RHEL / Rocky / Alma
                ${PKG_MANAGER}-config-manager --add-repo \
                    https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || \
                dnf config-manager --add-repo \
                    https://download.docker.com/linux/centos/docker-ce.repo
                pkg_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
            fi
            ;;
    esac

    systemctl enable docker --now
    info "Docker 安装完成：$(docker --version)"
fi

# ============================================================
section "Step 3: 安装 Docker Compose"
# ============================================================

if docker compose version &>/dev/null; then
    info "docker compose plugin 已安装"
elif command -v docker-compose &>/dev/null; then
    info "docker-compose 已安装"
else
    info "安装 docker-compose..."
    COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-linux-x86_64" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    info "docker-compose 安装完成"
fi

# ============================================================
section "Step 4: 创建目录结构"
# ============================================================

DST_DIR="/opt/dst-server"
mkdir -p "${DST_DIR}"/{saves,backup,mods}
cd "${DST_DIR}"

info "目录创建完成：${DST_DIR}"
info "  saves/  → 游戏存档"
info "  backup/ → 自动备份"
info "  mods/   → Mod 文件"

# ============================================================
section "Step 5: 生成 docker-compose.yml"
# ============================================================

cat > "${DST_DIR}/docker-compose.yml" << 'EOF'
version: '3'

services:
  dst-admin-go:
    image: hujinbo23/dst-admin-go:1.3.1
    container_name: dst-admin-go
    restart: always
    volumes:
      - ./saves:/root/.klei/DoNotStarveTogether   # 游戏存档持久化
      - ./backup:/app/backup                       # 备份文件
      - ./mods:/app/mod                            # Mod 文件
    ports:
      - "8082:8082/tcp"      # Web 管理面板
      - "10888:10888/udp"    # Steam 通信
      - "10998:10998/udp"    # 洞穴世界
      - "10999:10999/udp"    # 主世界
    environment:
      - TZ=Asia/Shanghai
EOF

info "docker-compose.yml 已生成"

# ============================================================
section "Step 6: 配置防火墙"
# ============================================================

info "开放必要端口..."

firewall_open tcp 22
firewall_open tcp 8082
firewall_open udp 10888
firewall_open udp 10998
firewall_open udp 10999
firewall_reload

# UFW 未启用时提示
if command -v ufw &>/dev/null && ufw status | grep -q "inactive"; then
    warn "UFW 防火墙当前未启用。"
    warn "如果你使用云服务商的安全组（阿里云/腾讯云/华为云），请手动在控制台放通上述端口。"
    read -p "是否启用 UFW？(y/n，云服务器建议选 n): " UFW_ENABLE
    [[ "$UFW_ENABLE" == "y" ]] && ufw --force enable && info "UFW 已启用"
fi

info "需要在云服务商控制台（安全组）开放以下端口："
info "  TCP 8082  → Web 管理面板"
info "  UDP 10888 → Steam 通信"
info "  UDP 10998 → 洞穴"
info "  UDP 10999 → 主世界"

# ============================================================
section "Step 7: 拉取镜像并启动服务"
# ============================================================

cd "${DST_DIR}"
info "拉取 dst-admin-go 镜像（首次可能需要几分钟）..."
docker compose pull 2>/dev/null || docker-compose pull

info "启动服务..."
docker compose up -d 2>/dev/null || docker-compose up -d

# ============================================================
section "Step 8: 验证安装"
# ============================================================

sleep 5

if docker ps | grep -q "dst-admin-go"; then
    info "✅ dst-admin-go 容器已成功运行！"
else
    error "❌ 容器启动失败，请检查：docker logs dst-admin-go"
fi

# ============================================================
section "✅ 安装完成！"
# ============================================================

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  🎮 饥荒服务器管理面板已成功部署！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  🖥️  系统版本：${YELLOW}${OS_NAME}${NC}"
echo -e "  🌐 面板地址：${YELLOW}http://${SERVER_IP}:8082${NC}"
echo -e "  👤 默认账号：${YELLOW}admin${NC}"
echo -e "  🔑 默认密码：${YELLOW}admin123${NC}（首次登录请立即修改！）"
echo ""
echo -e "  📁 数据目录：${YELLOW}${DST_DIR}${NC}"
echo ""
echo -e "${BLUE}后续步骤：${NC}"
echo -e "  1. 打开面板 → 系统设置 → 填入你的 Klei Server Token"
echo -e "     Token 获取：Steam → 饥荒 → 账户 → 游戏服务器 → 添加服务器"
echo -e "  2. 创建房间 → 配置世界参数、Mod、密码等"
echo -e "  3. 启动世界，开始游戏！"
echo ""
echo -e "${BLUE}常用管理命令：${NC}"
echo -e "  查看日志：docker logs -f dst-admin-go"
echo -e "  重启面板：cd ${DST_DIR} && docker compose restart"
echo -e "  停止服务：cd ${DST_DIR} && docker compose down"
echo -e "  更新面板：cd ${DST_DIR} && docker compose pull && docker compose up -d"
echo ""
echo -e "${GREEN}============================================${NC}"