#!/bin/bash
# PixelMug MCP Service Environment Variables Export
# 导出环境变量供可执行文件使用
# 支持永久环境变量设置（系统级/用户级/会话级）

# =============================================================================
# 脚本配置和参数
# =============================================================================

# 脚本版本
SCRIPT_VERSION="2.0.0"

# 默认配置模式
DEFAULT_MODE="session"  # session, user, system

# 配置文件路径
USER_PROFILE="$HOME/.bashrc"
SYSTEM_PROFILE="/etc/environment"
SYSTEM_BASH_PROFILE="/etc/bash.bashrc"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# 必需的环境变量 - 必须配置
# =============================================================================

# IoT角色ARN - 用于STS临时凭证申请
# 格式: qcs::cam::uin/{UIN}:roleName/{角色名称}
# 获取方式: 腾讯云控制台 -> 访问管理 -> 角色 -> 选择角色 -> 复制角色ARN
# 当前配置: alaya_mcp 角色 (alaya network authority)
export IOT_ROLE_ARN="qcs::cam::uin/123456789:roleName/alaya_mcp"

# =============================================================================
# 腾讯云访问凭证 - 必须配置
# =============================================================================

# 推荐使用子账号密钥，比主账号密钥更安全
# 获取方式: 腾讯云控制台 -> 访问管理 -> API密钥管理
export TC_SECRET_ID="your_secret_id"
export TC_SECRET_KEY="your_secret_key"

# 凭证优先级: 子账号密钥 > 主账号密钥

# =============================================================================
# COS对象存储配置 - 可选，如果使用COS功能需要配置
# =============================================================================

# COS存储桶拥有者UIN - 拥有COS存储桶的腾讯云账号UIN
# 获取方式: 腾讯云控制台 -> 账号信息 -> 主账号ID
export COS_OWNER_UIN="123456789"

# COS存储桶名称 - 用于存储像素图片和GIF动画
# 获取方式: 腾讯云控制台 -> 对象存储 -> 存储桶列表
export COS_BUCKET_NAME="your-bucket-name"

# COS地域 - 存储桶所在的地域
# 常用地域: ap-guangzhou, ap-beijing, ap-shanghai
export COS_REGION="ap-guangzhou"

# =============================================================================
# 服务配置 - 可选，有默认值
# =============================================================================

# 默认地域 - 腾讯云服务默认地域
export DEFAULT_REGION="ap-guangzhou"

# COS存储桶名称（兼容旧版本）
export COS_BUCKET="pixelmug-assets"

# 日志级别 - DEBUG, INFO, WARNING, ERROR
export LOG_LEVEL="INFO"

# 注意: ALAYA网络使用stdio模式，无需HTTP服务监听端口

# =============================================================================
# ALAYA协议配置 - ALAYA是协议标准，DApp直接组装stdio参数
# =============================================================================

# 注意: ALAYA是协议标准，不需要额外的验证配置
# DApp直接通过stdio接口组装参数调用服务

# =============================================================================
# 核心功能函数
# =============================================================================

# 显示帮助信息
show_help() {
    echo -e "${BLUE}PixelMug MCP Service 环境变量配置工具 v${SCRIPT_VERSION}${NC}"
    echo ""
    echo "用法: $0 [选项] [模式]"
    echo ""
    echo "模式:"
    echo "  session    仅当前会话生效（默认）"
    echo "  user       用户级永久生效（写入 ~/.bashrc）"
    echo "  system     系统级永久生效（需要sudo权限）"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --version  显示版本信息"
    echo "  -c, --check    检查当前环境变量配置"
    echo "  -r, --remove   移除永久环境变量配置"
    echo "  -s, --status   显示配置状态"
    echo ""
    echo "示例:"
    echo "  $0                    # 仅当前会话生效"
    echo "  $0 user               # 用户级永久生效"
    echo "  sudo $0 system        # 系统级永久生效"
    echo "  $0 --check            # 检查配置"
    echo "  $0 --remove           # 移除配置"
}

# 检查环境变量配置
check_config() {
    echo -e "${BLUE}检查环境变量配置...${NC}"
    echo ""
    
    local vars=("IOT_ROLE_ARN" "TC_SECRET_ID" "TC_SECRET_KEY" "COS_OWNER_UIN" "COS_BUCKET_NAME" "COS_REGION" "DEFAULT_REGION" "LOG_LEVEL")
    
    for var in "${vars[@]}"; do
        if [ -n "${!var}" ]; then
            if [[ "$var" == *"SECRET"* ]] || [[ "$var" == *"KEY"* ]]; then
                echo -e "  ${GREEN}✓${NC} $var: ${!var:0:8}***"
            else
                echo -e "  ${GREEN}✓${NC} $var: ${!var}"
            fi
        else
            echo -e "  ${RED}✗${NC} $var: 未设置"
        fi
    done
}

# 生成环境变量配置内容
generate_env_config() {
    cat << 'EOF'
# =============================================================================
# PixelMug MCP Service 环境变量配置
# 由 export_env.sh 自动生成 - 请勿手动修改
# =============================================================================

# IoT角色ARN
export IOT_ROLE_ARN="qcs::cam::uin/123456789:roleName/alaya_mcp"

# 腾讯云访问凭证
export TC_SECRET_ID="your_secret_id"
export TC_SECRET_KEY="your_secret_key"

# COS对象存储配置
export COS_OWNER_UIN="123456789"
export COS_BUCKET_NAME="your-bucket-name"
export COS_REGION="ap-guangzhou"

# 服务配置
export DEFAULT_REGION="ap-guangzhou"
export COS_BUCKET="pixelmug-assets"
export LOG_LEVEL="INFO"

# =============================================================================
# 配置结束
# =============================================================================
EOF
}

# 写入用户级配置
write_user_config() {
    local profile_file="$USER_PROFILE"
    local config_content
    local backup_file="${profile_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 检查是否已存在配置
    if grep -q "PixelMug MCP Service 环境变量配置" "$profile_file" 2>/dev/null; then
        echo -e "${YELLOW}警告: 用户配置已存在，将更新现有配置${NC}"
        # 备份原文件
        cp "$profile_file" "$backup_file"
        echo -e "${BLUE}已备份原配置到: $backup_file${NC}"
        
        # 移除旧配置
        sed -i '/# =============================================================================/,/# =============================================================================/d' "$profile_file"
    fi
    
    # 生成配置内容
    config_content=$(generate_env_config)
    
    # 写入新配置
    echo "" >> "$profile_file"
    echo "$config_content" >> "$profile_file"
    
    echo -e "${GREEN}✓ 用户级配置已写入: $profile_file${NC}"
    echo -e "${YELLOW}请运行 'source $profile_file' 或重新登录以生效${NC}"
}

# 写入系统级配置
write_system_config() {
    local env_file="$SYSTEM_PROFILE"
    local bash_file="$SYSTEM_BASH_PROFILE"
    local backup_env="${env_file}.backup.$(date +%Y%m%d_%H%M%S)"
    local backup_bash="${bash_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 检查权限
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 系统级配置需要root权限，请使用 sudo${NC}"
        return 1
    fi
    
    # 备份原文件
    cp "$env_file" "$backup_env" 2>/dev/null || true
    cp "$bash_file" "$backup_bash" 2>/dev/null || true
    
    # 写入 /etc/environment
    cat >> "$env_file" << EOF

# PixelMug MCP Service 环境变量配置
IOT_ROLE_ARN="qcs::cam::uin/123456789:roleName/alaya_mcp"
TC_SECRET_ID="your_secret_id"
TC_SECRET_KEY="your_secret_key"
COS_OWNER_UIN="123456789"
COS_BUCKET_NAME="your-bucket-name"
COS_REGION="ap-guangzhou"
DEFAULT_REGION="ap-guangzhou"
COS_BUCKET="pixelmug-assets"
LOG_LEVEL="INFO"
EOF
    
    # 写入 /etc/bash.bashrc
    if grep -q "PixelMug MCP Service 环境变量配置" "$bash_file" 2>/dev/null; then
        sed -i '/# =============================================================================/,/# =============================================================================/d' "$bash_file"
    fi
    
    cat >> "$bash_file" << 'EOF'

# =============================================================================
# PixelMug MCP Service 环境变量配置
# =============================================================================
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi
# =============================================================================
EOF
    
    echo -e "${GREEN}✓ 系统级配置已写入${NC}"
    echo -e "${YELLOW}系统重启后对所有用户生效${NC}"
}

# 移除永久配置
remove_permanent_config() {
    local mode="$1"
    
    case "$mode" in
        "user")
            if [ -f "$USER_PROFILE" ]; then
                if grep -q "PixelMug MCP Service 环境变量配置" "$USER_PROFILE"; then
                    local backup_file="${USER_PROFILE}.backup.$(date +%Y%m%d_%H%M%S)"
                    cp "$USER_PROFILE" "$backup_file"
                    sed -i '/# =============================================================================/,/# =============================================================================/d' "$USER_PROFILE"
                    echo -e "${GREEN}✓ 用户级配置已移除${NC}"
                    echo -e "${BLUE}备份文件: $backup_file${NC}"
                else
                    echo -e "${YELLOW}未找到用户级配置${NC}"
                fi
            fi
            ;;
        "system")
            if [ "$EUID" -ne 0 ]; then
                echo -e "${RED}错误: 移除系统级配置需要root权限，请使用 sudo${NC}"
                return 1
            fi
            
            if grep -q "PixelMug MCP Service 环境变量配置" "$SYSTEM_PROFILE"; then
                local backup_env="${SYSTEM_PROFILE}.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$SYSTEM_PROFILE" "$backup_env"
                sed -i '/# PixelMug MCP Service 环境变量配置/,/LOG_LEVEL="INFO"/d' "$SYSTEM_PROFILE"
                echo -e "${GREEN}✓ 系统级环境变量配置已移除${NC}"
            fi
            
            if grep -q "PixelMug MCP Service 环境变量配置" "$SYSTEM_BASH_PROFILE"; then
                local backup_bash="${SYSTEM_BASH_PROFILE}.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$SYSTEM_BASH_PROFILE" "$backup_bash"
                sed -i '/# =============================================================================/,/# =============================================================================/d' "$SYSTEM_BASH_PROFILE"
                echo -e "${GREEN}✓ 系统级bash配置已移除${NC}"
            fi
            ;;
        *)
            echo -e "${RED}错误: 无效的移除模式${NC}"
            return 1
            ;;
    esac
}

# 显示配置状态
show_status() {
    echo -e "${BLUE}PixelMug MCP Service 配置状态${NC}"
    echo ""
    
    # 检查会话级配置
    echo -e "${YELLOW}会话级配置:${NC}"
    if [ -n "$IOT_ROLE_ARN" ]; then
        echo -e "  ${GREEN}✓${NC} 当前会话已加载"
    else
        echo -e "  ${RED}✗${NC} 当前会话未加载"
    fi
    
    # 检查用户级配置
    echo -e "${YELLOW}用户级配置:${NC}"
    if [ -f "$USER_PROFILE" ] && grep -q "PixelMug MCP Service 环境变量配置" "$USER_PROFILE"; then
        echo -e "  ${GREEN}✓${NC} 已配置 ($USER_PROFILE)"
    else
        echo -e "  ${RED}✗${NC} 未配置"
    fi
    
    # 检查系统级配置
    echo -e "${YELLOW}系统级配置:${NC}"
    if [ -f "$SYSTEM_PROFILE" ] && grep -q "PixelMug MCP Service 环境变量配置" "$SYSTEM_PROFILE"; then
        echo -e "  ${GREEN}✓${NC} 已配置 ($SYSTEM_PROFILE)"
    else
        echo -e "  ${RED}✗${NC} 未配置"
    fi
}

# =============================================================================
# 参数解析和主逻辑
# =============================================================================

# 解析命令行参数
MODE="$DEFAULT_MODE"
ACTION="export"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "PixelMug MCP Service 环境变量配置工具 v$SCRIPT_VERSION"
            exit 0
            ;;
        -c|--check)
            ACTION="check"
            shift
            ;;
        -r|--remove)
            ACTION="remove"
            if [ -n "$2" ] && [[ "$2" =~ ^(user|system)$ ]]; then
                MODE="$2"
                shift
            fi
            shift
            ;;
        -s|--status)
            ACTION="status"
            shift
            ;;
        session|user|system)
            MODE="$1"
            shift
            ;;
        *)
            echo -e "${RED}错误: 未知参数 '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 执行相应操作
case "$ACTION" in
    "check")
        check_config
        exit 0
        ;;
    "remove")
        remove_permanent_config "$MODE"
        exit 0
        ;;
    "status")
        show_status
        exit 0
        ;;
    "export")
        # 继续执行原有的导出逻辑
        ;;
esac

# =============================================================================
# 配置验证和显示
# =============================================================================

# 根据模式执行相应操作
case "$MODE" in
    "user")
        echo -e "${BLUE}配置用户级永久环境变量...${NC}"
        write_user_config
        echo ""
        ;;
    "system")
        echo -e "${BLUE}配置系统级永久环境变量...${NC}"
        write_system_config
        echo ""
        ;;
    "session")
        # 仅当前会话生效，无需额外操作
        ;;
esac

echo -e "${GREEN}✅ PixelMug MCP Service 环境变量已导出${NC}"
echo ""
echo -e "${BLUE}📋 核心配置:${NC}"
echo "  IOT_ROLE_ARN: $IOT_ROLE_ARN"
echo "  DEFAULT_REGION: $DEFAULT_REGION"
echo ""
echo -e "${BLUE}☁️  COS配置:${NC}"
echo "  COS_OWNER_UIN: $COS_OWNER_UIN"
echo "  COS_BUCKET_NAME: $COS_BUCKET_NAME"
echo "  COS_REGION: $COS_REGION"
echo ""
echo -e "${BLUE}⚙️  服务配置:${NC}"
echo "  LOG_LEVEL: $LOG_LEVEL"
echo "  运行模式: stdio模式 (ALAYA网络)"
echo ""
echo -e "${BLUE}🌐 ALAYA协议:${NC}"
echo "  ALAYA是协议标准，DApp直接组装stdio参数"
echo ""
echo -e "${BLUE}🔑 访问凭证:${NC}"
if [ -n "$TC_SECRET_ID" ] && [ "$TC_SECRET_ID" != "your_secret_id" ]; then
    echo "  TC_SECRET_ID: ${TC_SECRET_ID:0:8}***"
    echo "  TC_SECRET_KEY: ${TC_SECRET_KEY:0:8}***"
    # 简单检测账号类型
    if [[ "$TC_SECRET_ID" =~ ^AKID.* ]]; then
        echo "  账号类型: 子账号密钥（推荐）"
    else
        echo "  账号类型: 主账号密钥"
    fi
else
    echo "  请配置TC_SECRET_ID和TC_SECRET_KEY环境变量"
fi
echo "  角色ARN: $IOT_ROLE_ARN"
echo ""

# 显示配置模式信息
case "$MODE" in
    "user")
        echo -e "${YELLOW}💡 用户级配置已设置，下次登录时自动生效${NC}"
        echo -e "${YELLOW}   或运行: source $USER_PROFILE${NC}"
        ;;
    "system")
        echo -e "${YELLOW}💡 系统级配置已设置，重启后对所有用户生效${NC}"
        ;;
    "session")
        echo -e "${YELLOW}💡 当前为会话级配置，仅当前会话有效${NC}"
        echo -e "${YELLOW}   使用 '$0 user' 设置用户级永久配置${NC}"
        echo -e "${YELLOW}   使用 'sudo $0 system' 设置系统级永久配置${NC}"
        ;;
esac

echo ""
echo -e "${BLUE}🔧 管理命令:${NC}"
echo "  检查配置: $0 --check"
echo "  查看状态: $0 --status"
echo "  移除配置: $0 --remove [user|system]"
echo "  显示帮助: $0 --help"
