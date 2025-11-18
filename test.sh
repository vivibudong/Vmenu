#!/bin/bash

#  2025.11.18 v0.70
set -euo pipefail  # 启用严格模式

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly BORDER='\033[38;2;255;119;119m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# 全局变量
SERVER_IP=""
IS_INTERACTIVE=0

# 初始化函数
initialize() {
    # 检查是否为root用户
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\n${RED}错误: 请以root用户运行此脚本${NC}"
        exit 1
    fi
    
    # 检测是否为交互式环境
    if [ -t 0 ]; then
        IS_INTERACTIVE=1
    fi
    
    # 获取服务器IP
    SERVER_IP=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="服务器IP"
    fi
}

# 通用输入验证函数
validate_port() {
    local port=$1
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

validate_positive_integer() {
    local num=$1
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

validate_non_negative_integer() {
    local num=$1
    if [[ "$num" =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 安全的读取输入函数
safe_read() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"
    
    if [ "$IS_INTERACTIVE" -eq 1 ]; then
        echo -e "${YELLOW}${prompt}${NC}"
        if [ -n "$default" ]; then
            read -r input
            eval "$var_name=\"${input:-$default}\""
        else
            read -r input
            eval "$var_name=\"$input\""
        fi
    else
        if [ -n "$default" ]; then
            eval "$var_name=\"$default\""
            echo -e "${YELLOW}非交互式环境，使用默认值: $default${NC}"
        else
            echo -e "${RED}错误: 非交互式环境下必须提供默认值${NC}"
            exit 1
        fi
    fi
}

# 确认操作
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [ "$IS_INTERACTIVE" -eq 0 ]; then
        return 1
    fi
    
    echo -e "${YELLOW}${message} (y/n) [默认: $default]:${NC}"
    read -r response
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# 安全的命令执行函数（替换eval）
execute_command() {
    local description="$1"
    shift
    
    echo -e "\n${GREEN}开始执行: ${YELLOW}$description${NC}"
    echo -e "${BORDER}---执行输出开始---${NC}"
    
    if "$@"; then
        echo -e "${BORDER}---执行输出结束---${NC}"
        echo -e "${GREEN}✓ 命令执行成功！${NC}"
        return 0
    else
        local status=$?
        echo -e "${BORDER}---执行输出结束---${NC}"
        echo -e "${RED}✗ 命令执行失败，错误代码: $status${NC}"
        return $status
    fi
}

# 执行shell命令字符串（用于复杂管道命令）
execute_shell_command() {
    local description="$1"
    local cmd="$2"
    
    echo -e "\n${GREEN}开始执行: ${YELLOW}$description${NC}"
    echo -e "${BORDER}---执行输出开始---${NC}"
    
    if bash -c "$cmd"; then
        echo -e "${BORDER}---执行输出结束---${NC}"
        echo -e "${GREEN}✓ 命令执行成功！${NC}"
        return 0
    else
        local status=$?
        echo -e "${BORDER}---执行输出结束---${NC}"
        echo -e "${RED}✗ 命令执行失败，错误代码: $status${NC}"
        return $status
    fi
}

# 等待并返回菜单
wait_and_return() {
    local menu_func="$1"
    echo -e "\n${PURPLE}3秒后自动返回菜单...${NC}"
    sleep 3
    "$menu_func"
}

# 检测包管理器
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# 通用包安装函数
install_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    case $pm in
        apt)
            apt-get update -y && apt-get install -y "$package"
            ;;
        yum)
            yum install -y "$package"
            ;;
        dnf)
            dnf install -y "$package"
            ;;
        pacman)
            pacman -Sy --noconfirm "$package"
            ;;
        *)
            echo -e "${RED}不支持的包管理器${NC}"
            return 1
            ;;
    esac
}

# 通用系统更新函数
update_system() {
    local pm=$(detect_package_manager)
    
    case $pm in
        apt)
            apt-get update -y && apt-get upgrade -y
            ;;
        yum)
            yum update -y
            ;;
        dnf)
            dnf update -y
            ;;
        pacman)
            pacman -Syu --noconfirm
            ;;
        *)
            echo -e "${RED}不支持的包管理器${NC}"
            return 1
            ;;
    esac
}

# Docker安装函数
install_docker() {
    echo -e "\n${GREEN}正在为您安装Docker&Compose...${NC}"
    
    if ! update_system || ! install_package wget || ! install_package curl; then
        echo -e "\n${RED}更新系统或安装基础工具失败${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}正在安装Docker...${NC}"
    if ! execute_shell_command "安装Docker" "wget -qO- get.docker.com | bash"; then
        echo -e "\n${RED}Docker安装失败${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}正在启用Docker服务...${NC}"
    if ! execute_command "启用Docker服务" systemctl enable docker; then
        echo -e "\n${RED}Docker服务启用失败${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}正在安装Docker Compose插件...${NC}"
    local pm=$(detect_package_manager)
    case $pm in
        apt)
            if ! install_package docker-compose-plugin; then
                echo -e "\n${YELLOW}尝试手动安装Docker Compose...${NC}"
                install_docker_compose_manual
            fi
            ;;
        *)
            install_docker_compose_manual
            ;;
    esac
    
    # 验证安装
    if command -v docker &> /dev/null; then
        echo -e "\n${GREEN}Docker版本: $(docker -v)${NC}"
        if docker compose version &> /dev/null; then
            echo -e "${GREEN}Docker Compose版本: $(docker compose version)${NC}"
        fi
        echo -e "\n${GREEN}Docker环境安装完成！${NC}"
        return 0
    else
        echo -e "\n${RED}安装验证失败，请手动检查${NC}"
        return 1
    fi
}

# 手动安装Docker Compose
install_docker_compose_manual() {
    if ! execute_shell_command "下载Docker Compose" \
        "curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"; then
        echo -e "\n${RED}下载Docker Compose失败${NC}"
        return 1
    fi
    
    if ! execute_command "添加执行权限" chmod +x /usr/local/bin/docker-compose; then
        echo -e "\n${RED}为Docker Compose添加执行权限失败${NC}"
        return 1
    fi
}

# 检查Docker
check_docker() {
    # 检查Docker是否已安装
    if ! command -v docker &> /dev/null; then
        echo -e "\n${RED}检测到未安装Docker，请先安装基础环境。${NC}"
        echo -e ""
        echo -e "1. 自行安装"
        echo -e "2. 帮我安装"
        echo -e ""
        
        local docker_option
        safe_read "请选择选项 (1/2): " "1" docker_option
        
        case $docker_option in
            1)
                echo -e "\n${YELLOW}您选择了自行安装，正在返回主菜单...${NC}"
                sleep 1
                show_submenu_2
                return 1
                ;;
            2)
                if install_docker; then
                    sleep 2
                    return 0
                else
                    echo -e "\n${RED}安装失败，请尝试手动安装或检查系统环境${NC}"
                    sleep 2
                    return 1
                fi
                ;;
            *)
                echo -e "\n${RED}无效选项，返回主菜单。${NC}"
                sleep 1
                show_submenu_2
                return 1
                ;;
        esac
    else
        echo -e "\n---"
        echo -e "${GREEN}Docker已安装${NC}"
        echo -e "Docker版本: $(docker -v)"
        if docker compose version &> /dev/null; then
            echo -e "Docker Compose版本: $(docker compose version)"
        elif command -v docker-compose &> /dev/null; then
            echo -e "Docker Compose版本: $(docker-compose --version)"
        fi
        echo -e "---\n"
        return 0
    fi
}

# 获取docker compose命令
get_docker_compose_cmd() {
    if docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# 展示菜单头
show_header() {
    echo -e "\n${RED}=============================================${NC}"
    echo -e "${WHITE}              Vmenu❤   V0.64   ${NC}"
    echo -e "${RED}---------------------------------------------${NC}"
    echo -e " ${RED}● 博客地址:${NC} https://budongkeji.cc"
    echo -e " ${RED}● 脚本命令:${NC} bash <(curl -Ls s.v1v1.de/bash)"
    echo -e "${RED}=============================================${NC}"
}

# 展示主菜单
show_main_menu() {
    show_header
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}${RED}               主菜单                    ${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[1]${NC} ${WHITE}基础环境部署${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[2]${NC} ${WHITE}一键部署应用${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[3]${NC} ${WHITE}网站运维${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[9]${NC} ${WHITE}服务器测试${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[0]${NC} ${WHITE}退出脚本${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码 [0-9]:${NC} "
    
    local choice
    safe_read "" "" choice
    process_main_choice "$choice"
}

# 主菜单选择
process_main_choice() {
    local choice="$1"
    case $choice in
        1) show_submenu_1 ;;
        2) show_submenu_2 ;;
        3) show_submenu_3 ;;
        9) show_submenu_9 ;;
        0)
            echo -e "\n${YELLOW}感谢使用，再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            wait_and_return show_main_menu
            ;;
    esac
}

# 子菜单1
show_submenu_1() {
    show_header
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}${BORDER}${RED}         1.基础环境部署                  ${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[101]${NC} ${RED}**一键执行全部**${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[102]${NC} ${WHITE}更新软件包${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[103]${NC} ${WHITE}安装基础软件包${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[104]${NC} ${WHITE}安装/配置Fail2Ban${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[105]${NC} ${WHITE}开启原版BBR+FQ${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[106]${NC} ${WHITE}设置Swap虚拟内存${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[107]${NC} ${WHITE}设置上海时区${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[0]${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    local subchoice
    safe_read "" "" subchoice
    process_submenu_1_choice "$subchoice"
}

# 菜单1选择
process_submenu_1_choice() {
    local subchoice="$1"
    case $subchoice in
        101)
            local swap_size
            safe_read "请设置虚拟内存大小(单位: MiB, 输入0表示不设置):" "0" swap_size
            
            if ! validate_non_negative_integer "$swap_size"; then
                echo -e "${RED}错误: 请输入有效的数字!${NC}"
                wait_and_return show_submenu_1
                return
            fi

            # 构建基础命令
            update_system
            install_package wget
            install_package curl
            install_package unzip
            install_package fail2ban
            install_package rsyslog
            
            # BBR配置
            execute_shell_command "配置BBR" \
                "echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf && echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf && sysctl -p"
            
            # 时区配置
            execute_command "设置时区" timedatectl set-timezone Asia/Shanghai
            
            # Fail2ban
            execute_command "启动Fail2ban" systemctl start fail2ban
            execute_command "启用Fail2ban" systemctl enable fail2ban
            execute_command "重启Fail2ban" systemctl restart fail2ban
            
            # Swap配置
            if [ "$swap_size" -gt 0 ]; then
                execute_shell_command "配置Swap" \
                    "dd if=/dev/zero of=/var/swap bs=1M count=$swap_size && chmod 0600 /var/swap && mkswap -f /var/swap && swapon /var/swap && echo '/var/swap swap swap defaults 0 0' | tee -a /etc/fstab && swapon -a"
            fi
            
            wait_and_return show_submenu_1
            ;;

        102)
            update_system
            wait_and_return show_submenu_1
            ;;
            
        103)
            update_system
            install_package wget
            install_package curl
            install_package unzip
            install_package rsyslog
            wait_and_return show_submenu_1
            ;;

        104)
            echo -e "${YELLOW}=== Fail2Ban 配置 ===${NC}"
            
            local ssh_port max_retry ban_time find_time
            safe_read "请输入要保护的SSH端口 (默认: 22):" "22" ssh_port
            
            if ! validate_port "$ssh_port"; then
                echo -e "${RED}错误: 请输入有效的端口号 (1-65535)!${NC}"
                wait_and_return show_submenu_1
                return
            fi
            
            safe_read "请输入失败尝试次数上限 (默认: 5):" "5" max_retry
            if ! validate_positive_integer "$max_retry"; then
                echo -e "${RED}错误: 请输入有效的数字 (≥1)!${NC}"
                wait_and_return show_submenu_1
                return
            fi
            
            safe_read "请输入封禁时长 (单位: 分钟, 默认: 60):" "60" ban_time
            if ! validate_positive_integer "$ban_time"; then
                echo -e "${RED}错误: 请输入有效的数字 (≥1)!${NC}"
                wait_and_return show_submenu_1
                return
            fi
            
            safe_read "请输入查找时间窗口 (单位: 分钟, 默认: 10):" "10" find_time
            if ! validate_positive_integer "$find_time"; then
                echo -e "${RED}错误: 请输入有效的数字 (≥1)!${NC}"
                wait_and_return show_submenu_1
                return
            fi
            
            # 显示配置摘要
            echo -e "\n${GREEN}配置摘要:${NC}"
            echo -e "  SSH端口: ${YELLOW}$ssh_port${NC}"
            echo -e "  失败次数上限: ${YELLOW}$max_retry${NC}"
            echo -e "  封禁时长: ${YELLOW}$ban_time 分钟${NC}"
            echo -e "  查找时间窗口: ${YELLOW}$find_time 分钟${NC}"
            
            if ! confirm_action "确认安装?" "y"; then
                echo -e "${RED}已取消安装${NC}"
                wait_and_return show_submenu_1
                return
            fi
            
            # 转换为秒
            local ban_time_sec=$((ban_time * 60))
            local find_time_sec=$((find_time * 60))
            
            # 安装 Fail2Ban
            update_system
            install_package wget
            install_package curl
            install_package fail2ban
            execute_command "启动Fail2ban" systemctl start fail2ban
            execute_command "启用Fail2ban" systemctl enable fail2ban
            
            # 创建配置文件
            echo -e "${BLUE}[*] 配置Fail2Ban规则...${NC}"
            cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = ${ban_time_sec}
findtime = ${find_time_sec}
maxretry = ${max_retry}

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
logpath = /var/log/auth.log
maxretry = ${max_retry}
bantime = ${ban_time_sec}
findtime = ${find_time_sec}
EOF
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[✓] 配置Fail2Ban规则 - 成功${NC}"
            else
                echo -e "${RED}[✗] 配置Fail2Ban规则 - 失败${NC}"
            fi
            
            # 重启服务
            execute_command "重启Fail2ban" systemctl restart fail2ban
            
            echo -e "\n${GREEN}✓ Fail2Ban 已成功安装并配置!${NC}"
            echo -e "${GREEN}使用 'fail2ban-client status sshd' 查看状态${NC}"
            
            wait_and_return show_submenu_1
            ;;

        105)
            execute_shell_command "配置BBR" \
                "echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf && echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf && sysctl -p"
            wait_and_return show_submenu_1
            ;;
            
        106)
            local swap_size
            safe_read "请设置虚拟内存大小(单位: MiB):" "" swap_size
            
            if ! validate_positive_integer "$swap_size"; then
                echo -e "${RED}错误: 请输入有效的数字!${NC}"
                wait_and_return show_submenu_1
                return
            fi
            
            execute_shell_command "配置Swap(${swap_size}MiB)" \
                "dd if=/dev/zero of=/var/swap bs=1M count=$swap_size && chmod 0600 /var/swap && mkswap -f /var/swap && swapon /var/swap && echo '/var/swap swap swap defaults 0 0' | tee -a /etc/fstab && swapon -a"
            wait_and_return show_submenu_1
            ;;

        107)
            update_system
            install_package wget
            install_package curl
            execute_command "设置时区" timedatectl set-timezone Asia/Shanghai
            wait_and_return show_submenu_1
            ;;
            
        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            wait_and_return show_submenu_1
            ;;
    esac
}

# 子菜单2
show_submenu_2() {
    show_header
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}${BORDER}${RED}         2.一键部署Docker项目            ${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[200]${NC} ${WHITE}Docker&Compose安装${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[201]${NC} ${WHITE}NPM反代工具${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[202]${NC} ${WHITE}图床EasyImage${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[203]${NC} ${WHITE}最新版Vertex+Qbit${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[204]${NC} ${WHITE}jerry048/Dedicated-Seedbox${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[205]${NC} ${WHITE}影视站Libretv${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[206]${NC} ${WHITE}浏览器Chrome${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[207]${NC} ${WHITE}浏览器Firefox${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[999]${NC} ${WHITE}*一键删除所有容器及镜像* 慎用${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[0]${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    local subchoice
    safe_read "" "" subchoice
    process_submenu_2_choice "$subchoice"
}

# 菜单2选择
process_submenu_2_choice() {
    local subchoice="$1"
    case $subchoice in
        999)
            if ! confirm_action "${RED}警告: 将删除所有Docker容器和镜像，是否继续?${NC}" "n"; then
                echo -e "${YELLOW}已取消操作${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            execute_shell_command "清理Docker" \
                "docker ps -aq | xargs -r docker stop && docker ps -aq | xargs -r docker rm && docker images -q | sort -u | xargs -r docker rmi -f"
            wait_and_return show_submenu_2
            ;;

        200)
            install_docker
            wait_and_return show_submenu_2
            ;;
        201)
            check_docker || return
            
            local admin_port
            safe_read "设置NPM管理端口 [回车默认81]:" "81" admin_port
            
            if ! validate_port "$admin_port"; then
                echo -e "${RED}错误: 无效的端口号${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            mkdir -p /root/docker/npm
            cd /root/docker/npm
            
            cat > docker-compose.yml <<EOF
version: '3.8'
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '$admin_port:81'
      - '443:443'
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF
            
            local compose_cmd=$(get_docker_compose_cmd)
            execute_command "启动NPM" $compose_cmd up -d
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}NPM反代工具安装完成！${NC}"
            echo -e "${GREEN}管理界面: http://$SERVER_IP:$admin_port${NC}"
            echo -e "${GREEN}默认账户: admin@example.com${NC}"
            echo -e "${GREEN}默认密码: changeme${NC}"
            echo -e "${YELLOW}首次登录后请立即修改密码！${NC}"
            echo -e "${GREEN}================================${NC}"
            
            wait_and_return show_submenu_2
            ;;

        202)
            check_docker || return
            
            local port
            safe_read "设置EasyImage访问端口 [回车默认8080]:" "8080" port
            
            if ! validate_port "$port"; then
                echo -e "${RED}错误: 无效的端口号${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            mkdir -p /root/docker/easyimage
            cd /root/docker/easyimage
            
            cat > docker-compose.yml <<EOF
version: '3.3'
services:
  easyimage:
    image: ddsderek/easyimage:latest
    container_name: easyimage
    ports:
      - '$port:80'
    environment:
      - TZ=Asia/Shanghai
      - PUID=1000
      - PGID=1000
      - DEBUG=false
    volumes:
      - './config:/app/web/config'
      - './i:/app/web/i'
    restart: unless-stopped
EOF
            
            local compose_cmd=$(get_docker_compose_cmd)
            execute_command "启动EasyImage" $compose_cmd up -d
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}EasyImage图床安装完成！${NC}"
            echo -e "${GREEN}访问地址: http://$SERVER_IP:$port${NC}"
            echo -e "${GREEN}================================${NC}"
            
            wait_and_return show_submenu_2
            ;;
            
        203)
            check_docker || return
            
            update_system
            install_package qbittorrent-nox
            
            mkdir -p /root/docker/vertex
            chmod 777 /root/docker/vertex
            
            execute_command "启动Vertex" \
                docker run -d --name vertex --restart unless-stopped --network host \
                -v /root/docker/vertex:/vertex -e TZ=Asia/Shanghai lswl/vertex:stable
            
            cat > /etc/systemd/system/qbittorrent.service <<EOF
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080
User=root
Restart=always
RestartSec=10s
StartLimitInterval=60s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF
            
            execute_command "重载systemd" systemctl daemon-reload
            execute_command "启动qBittorrent" systemctl start qbittorrent
            execute_command "启用qBittorrent" systemctl enable qbittorrent
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}最新版Vertex安装完成！${NC}"
            echo -e "${GREEN}访问地址: http://$SERVER_IP:3000${NC}"
            echo -e "${GREEN}默认账户：admin${NC}"
            echo -e "${GREEN}查询默认密码：more /root/docker/vertex/data/password${NC}"
            echo -e "\n${GREEN}最新版Qbit安装完成！${NC}"
            echo -e "${GREEN}访问地址: http://$SERVER_IP:8080${NC}"
            echo -e "${GREEN}默认账户：admin | 默认密码：adminadmin${NC}"
            echo -e "${GREEN}================================${NC}"
            
            wait_and_return show_submenu_2
            ;;

        204)
            local QB_CACHE_SIZE QB_VERSION LT_VERSION INSTALL_VERTEX VERTEX_OPTION
            
            safe_read "请设置qBittorrent缓存大小（单位为MiB，建议设置为1/4内存大小）:" "" QB_CACHE_SIZE
            if ! validate_positive_integer "$QB_CACHE_SIZE"; then
                echo -e "${RED}错误: 请输入有效的数字${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            safe_read "请设置qBittorrent版本号（回车默认4.3.9）:" "4.3.9" QB_VERSION
            safe_read "请设置libtorrent版本号（回车默认v1.2.20）:" "v1.2.20" LT_VERSION
            
            local vertex_choice
            safe_read "是否安装vertex？（回车默认安装，0不安装）:" "1" vertex_choice
            
            if [ "$vertex_choice" = "0" ]; then
                INSTALL_VERTEX=0
                VERTEX_OPTION=""
            else
                INSTALL_VERTEX=1
                VERTEX_OPTION="-v"
            fi
            
            echo -e "\n${GREEN}您设置的参数如下:${NC}"
            echo -e "${GREEN}qBittorrent缓存大小: ${QB_CACHE_SIZE} MiB${NC}"
            echo -e "${GREEN}qBittorrent版本: ${QB_VERSION}  | libtorrent版本: ${LT_VERSION}${NC}"
            echo -e "${GREEN}默认用户名: admin${NC}"
            
            if [ "$INSTALL_VERTEX" -eq 1 ]; then
                echo -e "${GREEN}同时将安装最新版Vertex并启用BBRx${NC}"
            else
                echo -e "${YELLOW}不安装Vertex，自动启用BBRx${NC}"
            fi

            echo -e "\n${RED}❤ 原项目jerry048/Dedicated-Seedbox,好用记得给jerry大佬点个star！❤${NC}"
            
            if ! confirm_action "是否开始安装？" "y"; then
                echo -e "${YELLOW}已取消安装${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            local custom_password
            safe_read "请设置一个安全的管理密码:" "" custom_password
            
            if [ -z "$custom_password" ]; then
                echo -e "${RED}密码不能为空${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            execute_shell_command "安装Dedicated-Seedbox" \
                "bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u admin -p \"$custom_password\" -c ${QB_CACHE_SIZE} -q ${QB_VERSION} -l ${LT_VERSION} ${VERTEX_OPTION} -x"
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}Qbit访问地址: http://$SERVER_IP:8080${NC}"
            echo -e "${GREEN}默认账户：admin | 密码：您设置的密码${NC}"
            
            if [ "$INSTALL_VERTEX" -eq 1 ]; then
                echo -e "\n${GREEN}VT访问地址: http://$SERVER_IP:3000${NC}"
                echo -e "${GREEN}默认账户：admin | 密码：您设置的密码${NC}"
            fi
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}请执行reboot，重启服务器使配置生效。${NC}"
            
            wait_and_return show_submenu_2
            ;;

        205)
            check_docker || return
            
            local password_choice user_password admin_password custom_port
            
            safe_read "是否需要设置网站密码和管理员密码？(1=设置*强烈建议, 2=不设置)" "1" password_choice
            
            local password_env=""
            if [ "$password_choice" = "1" ]; then
                safe_read "设置网站访问密码:" "" user_password
                safe_read "设置管理员密码:" "" admin_password
                
                if [ -z "$user_password" ] || [ -z "$admin_password" ]; then
                    echo -e "${RED}密码不能为空${NC}"
                    wait_and_return show_submenu_2
                    return
                fi
                
                password_env="-e PASSWORD=$user_password -e ADMINPASSWORD=$admin_password"
                echo -e "${GREEN}已设置密码${NC}"
            else
                echo -e "${YELLOW}警告: 选择不设置密码存在安全风险${NC}"
            fi
            
            safe_read "设置访问端口 [回车默认 18899]:" "18899" custom_port
            
            if ! validate_port "$custom_port"; then
                echo -e "${RED}错误: 无效的端口号${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            if [ "$password_choice" = "1" ]; then
                execute_command "启动LibreTV" \
                    docker run -d --name libretv --restart unless-stopped \
                    -p "$custom_port:8080" $password_env bestzwei/libretv:latest
            else
                execute_command "启动LibreTV" \
                    docker run -d --name libretv --restart unless-stopped \
                    -p "$custom_port:8080" bestzwei/libretv:latest
            fi
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}浏览器访问 http://$SERVER_IP:$custom_port 即可打开LibreTV${NC}"
            
            if [ "$password_choice" = "1" ]; then
                echo -e "${GREEN}网站密码: $user_password${NC}"
                echo -e "${GREEN}管理员密码: $admin_password${NC}"
            fi
            
            echo -e "${GREEN}强烈建议使用NPM进行反代！${NC}"
            echo -e "${GREEN}================================${NC}"
            
            wait_and_return show_submenu_2
            ;;
        
        206)
            check_docker || return
            
            local kasm_port kasm_password
            
            while true; do
                safe_read "请输入KasmWeb Chrome访问端口 (10000-65535):" "" kasm_port
                if validate_port "$kasm_port" && [ "$kasm_port" -ge 10000 ]; then
                    break
                else
                    echo -e "${RED}端口必须是10000-65535之间的数字${NC}"
                fi
            done
            
            safe_read "请设置访问密码:" "" kasm_password
            
            if [ -z "$kasm_password" ]; then
                echo -e "${RED}密码不能为空${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            mkdir -p /root/docker/kasmweb
            cd /root/docker/kasmweb
            
            cat > docker-compose.yml <<EOF
version: '3.8'
services:
  chrome:
    image: kasmweb/chrome:1.16.0
    shm_size: 512m
    ports:
      - '$kasm_port:6901'
    environment:
      - VNC_PW=$kasm_password
    restart: unless-stopped
EOF
            
            local compose_cmd=$(get_docker_compose_cmd)
            execute_command "启动KasmWeb Chrome" $compose_cmd up -d

            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}浏览器访问 https://$SERVER_IP:$kasm_port 即可打开 KasmWeb Chrome${NC}"
            echo -e "${GREEN}默认账户：kasm_user  默认密码：$kasm_password${NC}"
            echo -e "${RED}用前须知：如果长期使用，请配置SSL证书确保数据安全！！！${NC}"
            echo -e "${GREEN}强烈建议使用NPM进行反代！${NC}"
            echo -e "${GREEN}================================${NC}"
        
            wait_and_return show_submenu_2
            ;;

        207)
            check_docker || return
            
            local firefox_http_port firefox_vnc_port firefox_password
            
            while true; do
                safe_read "请输入Firefox HTTP访问端口 (10000-65535):" "" firefox_http_port
                if validate_port "$firefox_http_port" && [ "$firefox_http_port" -ge 10000 ]; then
                    break
                else
                    echo -e "${RED}端口必须是10000-65535之间的数字${NC}"
                fi
            done
            
            while true; do
                safe_read "请输入Firefox VNC访问端口 (10000-65535):" "" firefox_vnc_port
                if validate_port "$firefox_vnc_port" && [ "$firefox_vnc_port" -ge 10000 ] && [ "$firefox_vnc_port" != "$firefox_http_port" ]; then
                    break
                else
                    echo -e "${RED}端口必须是10000-65535之间的数字且不能与HTTP端口相同${NC}"
                fi
            done
            
            safe_read "请设置Firefox VNC访问密码:" "" firefox_password
            
            if [ -z "$firefox_password" ]; then
                echo -e "${RED}密码不能为空${NC}"
                wait_and_return show_submenu_2
                return
            fi
            
            mkdir -p /root/docker/firefox
            cd /root/docker/firefox
            
            cat > docker-compose.yml <<EOF
version: '3'
services:
  firefox:
    image: jlesage/firefox
    container_name: firefox
    restart: unless-stopped
    environment:
      - TZ=America/New_York
      - DISPLAY_WIDTH=1920
      - DISPLAY_HEIGHT=1080
      - KEEP_APP_RUNNING=1
      - ENABLE_CJK_FONT=1
      - VNC_PASSWORD=$firefox_password
    ports:
      - "$firefox_http_port:5800"
      - "$firefox_vnc_port:5900"
    volumes:
      - /Docker/firefox:/config:rw
    shm_size: 6g
EOF
            
            local compose_cmd=$(get_docker_compose_cmd)
            execute_command "启动Firefox" $compose_cmd up -d
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}浏览器访问 http://$SERVER_IP:$firefox_http_port 即可打开 Firefox${NC}"
            echo -e "${GREEN}VNC端口:$firefox_vnc_port${NC}"
            echo -e "${GREEN}密码：$firefox_password${NC}"
            echo -e "${RED}用前须知：如果长期使用，请配置SSL证书确保数据安全！！！${NC}"
            echo -e "${GREEN}强烈建议使用NPM进行反代！${NC}"
            echo -e "${GREEN}================================${NC}"

            wait_and_return show_submenu_2
            ;;

        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            wait_and_return show_submenu_2
            ;;
    esac
}

# 子菜单3 - 网站运维
show_submenu_3() {
    show_header
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}${BORDER}${RED}            3.网站运维                     ${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[301]${NC} ${WHITE}安装/重启Nginx服务${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[302]${NC} ${WHITE}自签证书-Caddy${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[0]${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    local subchoice
    safe_read "" "" subchoice
    process_submenu_3_choice "$subchoice"
}

# 菜单3选择
process_submenu_3_choice() {
    local subchoice="$1"
    case $subchoice in
        301)
            manage_nginx
            wait_and_return show_submenu_3
            ;;
        302)
            echo -e "\n${GREEN}=== Caddy 自签证书配置 ===${NC}"
            
            # 检测并确认服务器IP
            local detected_ip=$SERVER_IP
            echo -e "${YELLOW}检测到服务器IP地址: ${GREEN}$detected_ip${NC}"
            
            local ip_confirm
            safe_read "检测到的IP地址是否正确？(y/n) [默认: y]:" "y" ip_confirm
            
            local server_ip
            if [[ "$ip_confirm" =~ ^[Nn]$ ]]; then
                safe_read "请手动输入服务器IP地址:" "" server_ip
                if [ -z "$server_ip" ]; then
                    echo -e "${RED}错误: IP地址不能为空${NC}"
                    wait_and_return show_submenu_3
                    return
                fi
            else
                server_ip=$detected_ip
            fi
            
            echo -e "\n${GREEN}使用的服务器IP: $server_ip${NC}"
            
            # 询问访问方式
            local access_type
            echo -e "\n${YELLOW}请选择访问方式:${NC}"
            echo -e "1. 使用域名访问 (需要域名已解析到此IP)"
            echo -e "2. 使用IP地址访问 (https://IP:端口)"
            
            safe_read "请选择 (1/2) [默认: 2]:" "2" access_type
            
            local domain_or_ip
            local caddy_address
            local https_port
            
            if [ "$access_type" = "1" ]; then
                # 域名访问模式
                safe_read "请输入要配置的域名 (例如: example.com):" "" domain_or_ip
                
                if [ -z "$domain_or_ip" ]; then
                    echo -e "${RED}错误: 域名不能为空${NC}"
                    wait_and_return show_submenu_3
                    return
                fi
                
                caddy_address="$domain_or_ip"
                https_port="443"
            else
                # IP访问模式
                domain_or_ip=$server_ip
                
                safe_read "请设置HTTPS访问端口 [默认: 443]:" "443" https_port
                
                if ! validate_port "$https_port"; then
                    echo -e "${RED}错误: 无效的端口号${NC}"
                    wait_and_return show_submenu_3
                    return
                fi
                
                caddy_address="https://$server_ip:$https_port"
            fi
            
            # 询问反代目标
            local backend_type
            echo -e "\n${YELLOW}请选择后端服务类型:${NC}"
            echo -e "1. 反向代理到本地端口"
            echo -e "2. 反向代理到其他服务器"
            echo -e "3. 静态网站目录"
            
            safe_read "请选择 (1/2/3) [默认: 1]:" "1" backend_type
            
            local backend_config=""
            local backend_desc=""
            case $backend_type in
                1)
                    local backend_port
                    safe_read "请输入后端服务端口 (例如: 8080):" "" backend_port
                    
                    if ! validate_port "$backend_port"; then
                        echo -e "${RED}错误: 无效的端口号${NC}"
                        wait_and_return show_submenu_3
                        return
                    fi
                    
                    backend_config="reverse_proxy localhost:$backend_port"
                    backend_desc="反向代理到 localhost:$backend_port"
                    ;;
                2)
                    local backend_url
                    safe_read "请输入后端服务器地址 (例如: 192.168.1.100:8080):" "" backend_url
                    
                    if [ -z "$backend_url" ]; then
                        echo -e "${RED}错误: 后端地址不能为空${NC}"
                        wait_and_return show_submenu_3
                        return
                    fi
                    
                    backend_config="reverse_proxy $backend_url"
                    backend_desc="反向代理到 $backend_url"
                    ;;
                3)
                    local root_dir
                    safe_read "请输入网站根目录路径 (默认: /var/www/html):" "/var/www/html" root_dir
                    
                    # 创建目录如果不存在
                    mkdir -p "$root_dir"
                    
                    backend_config="root * $root_dir
    file_server"
                    backend_desc="静态文件目录: $root_dir"
                    ;;
                *)
                    echo -e "${RED}错误: 无效的选择${NC}"
                    wait_and_return show_submenu_3
                    return
                    ;;
            esac
            
            # 显示配置摘要
            echo -e "\n${GREEN}=== 配置摘要 ===${NC}"
            echo -e "${GREEN}服务器IP: ${YELLOW}$server_ip${NC}"
            if [ "$access_type" = "1" ]; then
                echo -e "${GREEN}访问方式: ${YELLOW}域名 - $domain_or_ip${NC}"
                echo -e "${GREEN}HTTPS地址: ${YELLOW}https://$domain_or_ip${NC}"
            else
                echo -e "${GREEN}访问方式: ${YELLOW}IP地址${NC}"
                echo -e "${GREEN}HTTPS端口: ${YELLOW}$https_port${NC}"
                echo -e "${GREEN}HTTPS地址: ${YELLOW}https://$server_ip:$https_port${NC}"
            fi
            echo -e "${GREEN}后端配置: ${YELLOW}$backend_desc${NC}"
            
            if ! confirm_action "确认开始安装配置？" "y"; then
                echo -e "${YELLOW}已取消配置${NC}"
                wait_and_return show_submenu_3
                return
            fi
            
            # 检查并安装Caddy
            if ! command -v caddy &> /dev/null; then
                echo -e "\n${BLUE}正在安装Caddy...${NC}"
                update_system
                
                local pm=$(detect_package_manager)
                case $pm in
                    apt)
                        execute_shell_command "添加Caddy仓库" \
                            "apt install -y debian-keyring debian-archive-keyring apt-transport-https curl && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list && apt update"
                        install_package caddy
                        ;;
                    yum|dnf)
                        execute_shell_command "添加Caddy仓库" \
                            "$pm install yum-plugin-copr -y && $pm copr enable @caddy/caddy -y"
                        install_package caddy
                        ;;
                    *)
                        echo -e "${YELLOW}使用官方脚本安装Caddy...${NC}"
                        execute_shell_command "安装Caddy" \
                            "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
                        ;;
                esac
                
                if ! command -v caddy &> /dev/null; then
                    echo -e "${RED}Caddy安装失败${NC}"
                    wait_and_return show_submenu_3
                    return
                fi
                
                echo -e "${GREEN}✓ Caddy安装成功${NC}"
                echo -e "Caddy版本: $(caddy version)"
            else
                echo -e "${GREEN}Caddy已安装${NC}"
                echo -e "Caddy版本: $(caddy version)"
            fi
            
            # 创建Caddyfile
            echo -e "\n${BLUE}正在配置Caddyfile...${NC}"
            
            mkdir -p /etc/caddy
            
            # 根据访问类型生成不同的配置
            if [ "$access_type" = "1" ]; then
                # 域名模式
                cat > /etc/caddy/Caddyfile <<EOF
# Caddy 自签证书配置 (域名模式)
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

$caddy_address {
    tls internal
    
    $backend_config
    
    encode gzip
    
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF
            else
                # IP模式
                cat > /etc/caddy/Caddyfile <<EOF
# Caddy 自签证书配置 (IP模式)
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

{
    auto_https disable_redirects
}

$caddy_address {
    tls internal {
        on_demand
    }
    
    $backend_config
    
    encode gzip
    
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

# HTTP重定向（可选）
http://$server_ip:80 {
    redir https://$server_ip:$https_port{uri} permanent
}
EOF
            fi
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Caddyfile配置成功${NC}"
            else
                echo -e "${RED}✗ Caddyfile配置失败${NC}"
                wait_and_return show_submenu_3
                return
            fi
            
            # 创建日志目录
            mkdir -p /var/log/caddy
            
            # 验证配置
            echo -e "\n${BLUE}正在验证Caddy配置...${NC}"
            if execute_command "验证Caddy配置" caddy validate --config /etc/caddy/Caddyfile; then
                echo -e "${GREEN}✓ 配置验证通过${NC}"
            else
                echo -e "${RED}✗ 配置验证失败${NC}"
                wait_and_return show_submenu_3
                return
            fi
            
            # 停止可能冲突的服务
            if systemctl is-active --quiet nginx; then
                echo -e "${YELLOW}检测到Nginx正在运行${NC}"
                if [ "$https_port" = "443" ] || [ "$access_type" = "1" ]; then
                    echo -e "${YELLOW}端口可能冲突，建议停止Nginx${NC}"
                    if confirm_action "是否停止Nginx服务？" "y"; then
                        execute_command "停止Nginx" systemctl stop nginx
                    fi
                fi
            fi
            
            # 启动Caddy
            echo -e "\n${BLUE}正在启动Caddy服务...${NC}"
            execute_command "重载systemd" systemctl daemon-reload
            execute_command "启动Caddy" systemctl start caddy
            execute_command "启用Caddy开机自启" systemctl enable caddy
            
            # 检查服务状态
            sleep 2
            if systemctl is-active --quiet caddy; then
                echo -e "${GREEN}✓ Caddy服务运行中${NC}"
            else
                echo -e "${RED}✗ Caddy服务启动失败${NC}"
                echo -e "${YELLOW}查看错误日志: journalctl -u caddy -n 50${NC}"
                wait_and_return show_submenu_3
                return
            fi
            
            # 配置防火墙
            if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
                echo -e "\n${YELLOW}检测到UFW防火墙已启用${NC}"
                if confirm_action "是否配置防火墙规则？" "y"; then
                    if [ "$access_type" = "2" ]; then
                        execute_command "允许HTTP(80)" ufw allow 80/tcp
                        execute_command "允许HTTPS端口($https_port)" ufw allow "$https_port/tcp"
                    else
                        execute_command "允许HTTP(80)" ufw allow 80/tcp
                        execute_command "允许HTTPS(443)" ufw allow 443/tcp
                    fi
                    execute_command "重载UFW" ufw reload
                fi
            fi
            
            # 显示完成信息
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}✓ Caddy自签证书配置完成！${NC}"
            echo -e "${GREEN}================================${NC}"
            
            if [ "$access_type" = "1" ]; then
                echo -e "${GREEN}访问地址: ${YELLOW}https://$domain_or_ip${NC}"
                echo -e "${GREEN}域名: ${YELLOW}$domain_or_ip${NC}"
            else
                echo -e "${GREEN}HTTPS访问: ${YELLOW}https://$server_ip:$https_port${NC}"
                echo -e "${GREEN}HTTP访问: ${YELLOW}http://$server_ip:80${NC} (自动重定向到HTTPS)"
            fi
            
            echo -e "${GREEN}后端服务: ${YELLOW}$backend_desc${NC}"
            echo -e "${GREEN}证书类型: ${YELLOW}自签名证书 (Internal)${NC}"
            echo -e "${GREEN}配置文件: ${YELLOW}/etc/caddy/Caddyfile${NC}"
            echo -e "${GREEN}日志文件: ${YELLOW}/var/log/caddy/access.log${NC}"
            echo -e "${GREEN}================================${NC}"
            echo -e "${YELLOW}重要提示:${NC}"
            echo -e "1. ${RED}自签证书会导致浏览器显示安全警告${NC}"
            echo -e "2. 访问时需要在浏览器中点击'高级'→'继续访问'"
            echo -e "3. 或在浏览器中手动信任该证书"
            
            if [ "$access_type" = "1" ]; then
                echo -e "4. 请确保域名 $domain_or_ip 已正确解析到 $server_ip"
                echo -e "5. 如需使用受信任证书，需要公网域名并配置正确的DNS"
            else
                echo -e "4. 使用IP访问时，浏览器警告是正常现象"
                echo -e "5. 生产环境建议使用域名+Let's Encrypt证书"
            fi
            
            echo -e "\n${GREEN}常用管理命令:${NC}"
            echo -e "查看状态: ${YELLOW}systemctl status caddy${NC}"
            echo -e "重启服务: ${YELLOW}systemctl restart caddy${NC}"
            echo -e "查看日志: ${YELLOW}journalctl -u caddy -f${NC}"
            echo -e "查看访问日志: ${YELLOW}tail -f /var/log/caddy/access.log${NC}"
            echo -e "重载配置: ${YELLOW}caddy reload --config /etc/caddy/Caddyfile${NC}"
            echo -e "验证配置: ${YELLOW}caddy validate --config /etc/caddy/Caddyfile${NC}"
            echo -e "${GREEN}================================${NC}"
            
            wait_and_return show_submenu_3
            ;;
        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            wait_and_return show_submenu_3
            ;;
    esac
}

# Nginx管理函数
manage_nginx() {
    echo -e "\n${GREEN}=== Nginx 服务管理 ===${NC}"
    
    # 检查Nginx是否已安装
    if command -v nginx &> /dev/null; then
        echo -e "${GREEN}检测到Nginx已安装${NC}"
        echo -e "Nginx版本: $(nginx -v 2>&1)"
        
        # 检查Nginx状态
        if systemctl is-active --quiet nginx; then
            echo -e "${GREEN}Nginx服务运行中${NC}"
            
            if confirm_action "是否重启Nginx服务？" "y"; then
                # 先测试配置
                echo -e "${BLUE}正在测试Nginx配置...${NC}"
                if execute_command "测试Nginx配置" nginx -t; then
                    execute_command "重启Nginx" systemctl restart nginx
                    echo -e "${GREEN}✓ Nginx服务已成功重启${NC}"
                else
                    echo -e "${RED}✗ Nginx配置文件有错误，请先修复配置${NC}"
                    return 1
                fi
            fi
        else
            echo -e "${YELLOW}Nginx服务未运行${NC}"
            if confirm_action "是否启动Nginx服务？" "y"; then
                execute_command "启动Nginx" systemctl start nginx
                execute_command "启用Nginx开机自启" systemctl enable nginx
                echo -e "${GREEN}✓ Nginx服务已启动${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}未检测到Nginx，准备安装...${NC}"
        
        if ! confirm_action "是否安装Nginx？" "y"; then
            echo -e "${YELLOW}已取消安装${NC}"
            return 0
        fi
        
        # 安装Nginx
        echo -e "${BLUE}正在安装Nginx...${NC}"
        update_system
        install_package nginx
        
        if command -v nginx &> /dev/null; then
            echo -e "${GREEN}✓ Nginx安装成功${NC}"
            echo -e "Nginx版本: $(nginx -v 2>&1)"
            
            # 启动并启用Nginx
            execute_command "启动Nginx" systemctl start nginx
            execute_command "启用Nginx开机自启" systemctl enable nginx
            
            # 检查防火墙
            if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
                echo -e "${YELLOW}检测到UFW防火墙已启用${NC}"
                if confirm_action "是否允许HTTP(80)和HTTPS(443)端口？" "y"; then
                    execute_command "允许HTTP" ufw allow 80/tcp
                    execute_command "允许HTTPS" ufw allow 443/tcp
                    execute_command "重载UFW" ufw reload
                fi
            fi
            
            echo -e "\n${GREEN}================================${NC}"
            echo -e "${GREEN}Nginx安装完成！${NC}"
            echo -e "${GREEN}访问地址: http://$SERVER_IP${NC}"
            echo -e "${GREEN}配置文件: /etc/nginx/nginx.conf${NC}"
            echo -e "${GREEN}网站目录: /var/www/html${NC}"
            echo -e "${GREEN}================================${NC}"
        else
            echo -e "${RED}✗ Nginx安装失败${NC}"
            return 1
        fi
    fi
}

# 子菜单9
show_submenu_9() {
    show_header
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}${BORDER}${RED}          9.服务器测试                      ${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[901]${NC} ${WHITE}NodeQuality融合测试 *荐${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[902]${NC} ${WHITE}网速测试${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}│${NC}   ${GREEN}[0]${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${RED}│${NC}"
    echo -e "${RED}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    local subchoice
    safe_read "" "" subchoice
    process_submenu_9_choice "$subchoice"
}

# 菜单9选择
process_submenu_9_choice() {
    local subchoice="$1"
    case $subchoice in
        901)
            execute_shell_command "NodeQuality融合测试" \
                "bash <(curl -sL https://run.NodeQuality.com)"
            wait_and_return show_submenu_9
            ;;
        902)
            local pm=$(detect_package_manager)
            case $pm in
                apt)
                    execute_shell_command "安装Speedtest" \
                        "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash && apt-get install speedtest -y"
                    ;;
                yum|dnf)
                    execute_shell_command "安装Speedtest" \
                        "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash && $pm install speedtest -y"
                    ;;
                *)
                    echo -e "${YELLOW}尝试通用安装方式...${NC}"
                    execute_shell_command "安装Speedtest" \
                        "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash"
                    ;;
            esac
            
            execute_command "运行网速测试" speedtest
            wait_and_return show_submenu_9
            ;;
        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            wait_and_return show_submenu_9
            ;;
    esac
}

# 主函数
main() {
    initialize
    show_main_menu
}

# 执行主函数
main "$@"
