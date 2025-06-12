#!/bin/bash

#  2025.4.27 v0.6
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BORDER='\033[38;2;255;119;119m' 
WHITE='\033[1;37m'
NC='\033[0m' 

# 定义本机ip
server_ip=$(ip -4 addr | grep -v "127.0.0.1" | grep -Po 'inet \K[\d.]+' | head -1)
if [ -z "$server_ip" ]; then
    server_ip="服务器IP"
fi

# 定义DockerCompose函数
install_docker() {
    echo -e "\n${GREEN}正在为您安装Docker&Compose...${NC}"
    
    if ! apt update -y && apt upgrade -y && apt install -y sudo wget curl; then
        echo -e "\n${RED}更新系统或安装基础工具失败${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}正在安装Docker...${NC}"
    if ! sudo bash -c "wget -qO- get.docker.com | bash"; then
        echo -e "\n${RED}Docker安装失败${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}正在启用Docker服务...${NC}"
    if ! sudo systemctl enable docker; then
        echo -e "\n${RED}Docker服务启用失败${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}正在安装Docker Compose...${NC}"
    if ! sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
        echo -e "\n${RED}下载Docker Compose失败${NC}"
        return 1
    fi
    
    if ! sudo chmod +x /usr/local/bin/docker-compose; then
        echo -e "\n${RED}为Docker Compose添加执行权限失败${NC}"
        return 1
    fi
    
    # 验证安装
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        echo -e "\n${GREEN}Docker版本:$(docker -v)${NC}"
        echo -e "\n${GREEN}Docker Compose版本:$(docker-compose --version)${NC}"
        echo -e "\n${GREEN}Docker环境安装完成！${NC}"
        return 0
    else
        echo -e "\n${RED}安装验证失败，请手动检查${NC}"
        return 1
    fi
}

check_docker() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\n${RED}请以root用户或使用sudo运行此脚本${NC}"
        return 1
    fi
    
    # 检查Docker是否已安装
    if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
        missing=""
        if ! command -v docker &> /dev/null; then
            missing="Docker"
        fi
        
        if ! command -v docker-compose &> /dev/null; then
            if [ -n "$missing" ]; then
                missing="$missing和Docker Compose"
            else
                missing="Docker Compose"
            fi
        fi
        
        echo -e "\n${RED}检测到未安装${missing}，请先安装基础环境。${NC}"
        echo -e ""
        echo -e "1. 自行安装"
        echo -e ""
        echo -e "2. 帮我安装"
        echo -e ""
        read -p "请选择选项 (1/2): " docker_option
        
        case $docker_option in
            1)
                echo -e "\n${YELLOW}您选择了自行安装，正在返回主菜单...${NC}"
                sleep 1
                # show_submenu_2
                if type show_submenu_2 &>/dev/null; then
                    show_submenu_2
                else
                    echo -e "\n${RED}返回主菜单失败，函数未定义${NC}"
                fi
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
                # show_submenu_2
                if type show_submenu_2 &>/dev/null; then
                    show_submenu_2
                else
                    echo -e "\n${RED}返回主菜单失败，函数未定义${NC}"
                fi
                return 1
                ;;
        esac
    else
        echo -e "\n---"
        echo -e "${GREEN}Docker和Docker Compose已安装${NC}"
        echo -e "Docker版本: $(docker -v)  Docker Compose版本: $(docker-compose --version)"
        echo -e "---\n"
        return 0
    fi
}


execute_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "\n${GREEN}开始执行: ${YELLOW}$description${NC}"
    echo -e "${BORDER}---执行输出开始---${NC}"
    eval "$cmd"
    local status=$?
    echo -e "${BORDER}---执行输出结束---${NC}"
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ 命令执行成功！${NC}"
    else
        echo -e "${RED}✗ 命令执行失败，错误代码: $status${NC}"
    fi
    
    return $status
}


show_header() {
    echo -e "\n${BORDER}=============================================${NC}"
    echo -e "${BORDER}${WHITE}              VV菜单❤   V0.6   ${BORDER}${NC}"
    echo -e "${BORDER}─────────────────────────────────────────────${NC}"
    echo -e "${BORDER}${NC} ${RED}● 博客地址:${NC} https://budongkeji.cc     ${BORDER}${NC}"
    echo -e "${BORDER}${NC} ${RED}● 脚本命令:${NC} bash <(curl -Ls s.v1v1.de/bash)     ${BORDER}${NC}"
    
    echo -e "${BORDER}=============================================${NC}"
}

show_main_menu() {

    show_header
    echo -e "${BORDER}${NC}   ${GREEN}      ${BORDER}${NC}"
    echo -e "${BORDER}${WHITE}                    主菜单                       ${BORDER}${NC}"
    echo -e "${BORDER}${NC}   ${GREEN}      ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}      ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${RED}[1]${NC} 基础环境部署                                    ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}      ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[2]${NC} 一键部署Docker项目                     ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}                                                            ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[3]${NC} 服务器测试                                           ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}                                                            ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[0]${NC} 退出脚本                                             ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}      ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"

    # 运行次数
    echo -e "\n${BLUE}→ 脚本总计运行: - 次${NC}\n"

    echo -e "${YELLOW}请输入选项号码 [0-3]:${NC} "
    

    if [ -t 0 ]; then
        read -r choice
        process_main_choice "$choice"
    else
        echo -e "${YELLOW}非交互式环境，无法读取输入。${NC}"
        exit 0
    fi
}

process_main_choice() {
    local choice="$1"
    case $choice in
        1)
            show_submenu_1
            ;;
        2)
            show_submenu_2
            ;;
        3)
            show_submenu_3
            ;;
        0)
            echo -e "\n${YELLOW}感谢使用，再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            echo -e "\n${PURPLE}1秒后自动返回主菜单...${NC}"
            sleep 1
            show_main_menu
            ;;
    esac
}

# 子菜单1
show_submenu_1() {
    show_header
    echo -e "${BORDER}${WHITE}        1.基础环境部署                  ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${RED}[101]${NC} **一键执行全部**                                      ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[102]${NC} 更新软件包                                         ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[103]${NC} 安装基础软件包                                     ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[104]${NC} 安装Fail2Ban                                      ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[105]${NC} 开启原版BBR+FQ                                    ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[106]${NC} 设置Swap虚拟内存                             ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[107]${NC} 设置上海时区                                       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[0]${NC} 返回主菜单                                           ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    if [ -t 0 ]; then
        read -r subchoice
        process_submenu_1_choice "$subchoice"
    else
        echo -e "${YELLOW}非交互式环境，无法读取输入。${NC}"
        exit 0
    fi
}

process_submenu_1_choice() {
    local subchoice="$1"
    case $subchoice in

        101)
            echo -e "${YELLOW}请设置虚拟内存大小(单位: MiB, 输入0表示不设置):${NC}"
            read -p "> " swap_size
            
            if ! [[ "$swap_size" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}错误: 请输入有效的数字!${NC}"
                echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
                sleep 1
                show_submenu_1
                break
            fi

            base_command="apt update -y && apt upgrade -y && apt install -y sudo && sudo apt install -y wget curl unzip fail2ban rsyslog && echo \"net.core.default_qdisc=fq\" | sudo tee -a /etc/sysctl.conf && echo \"net.ipv4.tcp_congestion_control=bbr\" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo timedatectl set-timezone Asia/Shanghai && sudo systemctl start fail2ban && sudo systemctl enable fail2ban && sudo systemctl restart fail2ban"
            
            if [ "$swap_size" -gt 0 ]; then
                full_command="$base_command && sudo dd if=/dev/zero of=/var/swap bs=1M count=$swap_size && sudo chmod 0600 /var/swap && sudo mkswap -f /var/swap && sudo swapon /var/swap && echo '/var/swap swap swap defaults 0 0' | sudo tee -a /etc/fstab && sudo swapon -a"
                swap_info="虚拟内存:${swap_size}MiB,"
            else
                full_command="$base_command"
                swap_info="不设置虚拟内存,"
            fi
            
            execute_command "$full_command" "一键执行全部"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;

        102)
            execute_command "apt update -y && apt upgrade -y && apt install -y sudo" "更新软件包"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;
        103)
            execute_command "apt update -y && apt upgrade -y && apt install -y sudo && sudo apt install -y wget curl && sudo apt install -y wget curl unzip rsyslog" "安装基础软件包"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;
        104)
            execute_command "apt update -y && apt upgrade -y && apt install -y sudo && sudo apt install -y wget curl && apt install -y fail2ban && sudo systemctl start fail2ban && sudo systemctl enable fail2ban && sudo systemctl restart fail2ban" "安装Fail2Ban"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;

        105)
            execute_command "echo \"net.core.default_qdisc=fq\" | sudo tee -a /etc/sysctl.conf && echo \"net.ipv4.tcp_congestion_control=bbr\" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p" "开启原版BBR+FQ"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;
            
        106)
            echo -e "${YELLOW}请设置虚拟内存大小(单位: MiB):${NC}"
            read -p "> " swap_size
            
            # 检查
            if ! [[ "$swap_size" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}错误: 请输入有效的数字!${NC}"
                echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
                sleep 1
                show_submenu_1
                break
            fi
            
            execute_command "apt update -y && apt upgrade -y && apt install -y sudo && sudo dd if=/dev/zero of=/var/swap bs=1M count=$swap_size && sudo chmod 0600 /var/swap && sudo mkswap -f /var/swap && sudo swapon /var/swap && echo '/var/swap swap swap defaults 0 0' | sudo tee -a /etc/fstab && sudo swapon -a" "开启${swap_size}MiB虚拟内存"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;

        107)
            execute_command "apt update -y && apt upgrade -y && apt install -y sudo && sudo apt install -y wget curl && sudo timedatectl set-timezone Asia/Shanghai" "设置上海时区"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;
        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_1
            ;;
    esac
}

# 子菜单2
show_submenu_2() {
    show_header
    echo -e "${BORDER}${WHITE}            2.一键部署Docker项目                      ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[200]${NC} Docker&Compose安装   ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[201]${NC} NPM反代工具                                    ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[202]${NC} 图床EasyImage                                 "
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[203]${NC} 最新版Vertex+Qbit                                       "
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[204]${NC} jerry048/Dedicated-Seedbox    "
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}" 
    echo -e "${BORDER}│${NC}   ${GREEN}[205]${NC} 影视站Libretv    "
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[206]${NC} 浏览器Chrome    "
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[207]${NC} 浏览器Firefox    "
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"   
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${RED}[999]${NC} *一键删除所有容器及镜像* 慎用   ${BORDER}${NC}" 
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[0]${NC} 返回主菜单                                           "
    echo -e ""
    echo -e "${BORDER}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    if [ -t 0 ]; then
        read -r subchoice
        process_submenu_2_choice "$subchoice"
    else
        echo -e "${YELLOW}非交互式环境，无法读取输入。${NC}"
        exit 0
    fi
}

process_submenu_2_choice() {
    local subchoice="$1"
    case $subchoice in



        999)
        #清理docker
            execute_command "docker ps -aq | xargs -r docker stop && docker ps -aq | xargs -r docker rm && docker images -q | sort -u | xargs -r docker rmi -f" "停止、删除所有容器及镜像"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_2
            ;;

        200)
        #Docker & Compose
            execute_command "apt update -y && apt upgrade -y && apt install -y sudo wget curl && curl -fsSL https://get.docker.com | sudo bash && docker -v && sudo systemctl enable docker && sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose && docker-compose --version" "安装Docker&Compose"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_2
            ;;

        201)
        #Docker安装------NPM
            check_docker
            echo -e "${YELLOW}设置NPM管理端口 [回车默认81]:${NC} "
            if [ -t 0 ]; then
                read -r admin_port
                admin_port=${admin_port:-81}
                execute_command "mkdir -p /root/docker/npm && cd /root/docker/npm && echo -e \"version: '3.8'\nservices:\n  app:\n    image: 'jc21/nginx-proxy-manager:latest'\n    restart: unless-stopped\n    ports:\n      - '80:80'\n      - '$admin_port:81'\n      - '443:443'\n    volumes:\n      - ./data:/data\n      - ./letsencrypt:/etc/letsencrypt\" > docker-compose.yml && docker-compose up -d" "NPM反代工具安装，管理界面端口:$admin_port"
            else
                admin_port=81
                echo -e "${YELLOW}非交互式环境，使用默认管理界面端口 $admin_port${NC}"
                execute_command "mkdir -p /root/docker/npm && cd /root/docker/npm && echo -e \"version: '3.8'\nservices:\n  app:\n    image: 'jc21/nginx-proxy-manager:latest'\n    restart: unless-stopped\n    ports:\n      - '80:80'\n      - '$admin_port:81'\n      - '443:443'\n    volumes:\n      - ./data:/data\n      - ./letsencrypt:/etc/letsencrypt\" > docker-compose.yml && docker-compose up -d" "NPM反代工具安装，管理界面端口:$admin_port"
            fi
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            echo -e "\n${GREEN}默认账户：admin@example.com | 默认密码：changeme ${NC}"
            sleep 1
            show_submenu_2
            ;;

        202)
        #Docker安装------Easyimage2
            check_docker
            echo -e "${YELLOW}设置图床端口 [回车默认18080]:${NC} "
            if [ -t 0 ]; then
                read -r port
                port=${port:-18080}
                execute_command "mkdir -p /root/docker/easyimage && cd /root/docker/easyimage && echo -e \"version: '3.3'\nservices:\n  easyimage:\n    image: ddsderek/easyimage:latest\n    container_name: easyimage\n    ports:\n      - '$port:80'\n    environment:\n      - TZ=Asia/Shanghai\n      - PUID=1000\n      - PGID=1000\n      - DEBUG=false\n    volumes:\n      - '/root/docker/easyimage/config:/app/web/config'\n      - '/root/docker/easyimage/i:/app/web/i'\n    restart: unless-stopped\" > docker-compose.yml && docker-compose up -d" "图床EasyImage安装，端口:$port"
            else
                port=18080
                echo -e "${YELLOW}非交互式环境，使用默认端口 $port${NC}"
                execute_command "mkdir -p /root/docker/easyimage && cd /root/docker/easyimage && echo -e \"version: '3.3'\nservices:\n  easyimage:\n    image: ddsderek/easyimage:latest\n    container_name: easyimage\n    ports:\n      - '$port:80'\n    environment:\n      - TZ=Asia/Shanghai\n      - PUID=1000\n      - PGID=1000\n      - DEBUG=false\n    volumes:\n      - '/root/docker/easyimage/config:/app/web/config'\n      - '/root/docker/easyimage/i:/app/web/i'\n    restart: unless-stopped\" > docker-compose.yml && docker-compose up -d" "图床EasyImage安装，端口:$port"
            fi
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_2
            ;;
            
        203)
        #Docker安装------VT+QB
            check_docker
            if [ $? -eq 0 ]; then
                execute_command "apt update -y && apt upgrade -y && mkdir -p /root/docker/vertex && chmod 777 /root/docker/vertex && docker run -d --name vertex --restart unless-stopped --network host -v /root/docker/vertex:/vertex -e TZ=Asia/Shanghai lswl/vertex:stable && apt install sudo -y && sudo apt install qbittorrent-nox -y && echo -e \"[Unit]\nDescription=qBittorrent Command Line Client\nAfter=network.target\n\n[Service]\nExecStart=/usr/bin/qbittorrent-nox --webui-port=8080\nUser=root\nRestart=always\nRestartSec=10s\nStartLimitInterval=60s\nStartLimitBurst=5\n\n[Install]\nWantedBy=multi-user.target\" | sudo tee /etc/systemd/system/qbittorrent.service > /dev/null && sudo systemctl daemon-reload && sudo systemctl start qbittorrent && sudo systemctl enable qbittorrent && docker ps && systemctl list-units --type=service --state=running" "VT+QB安装"
                echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
                echo -e "\n${GREEN}Vertex默认账户：admin | 查询默认密码：more /root/docker/vertex/data/password ${NC}"
                echo -e "\n${GREEN}Qbit默认账户：admin | 默认密码：adminadmin ${NC}"
                sleep 1
            fi
            show_submenu_2
            ;;

        204)
        #Docker安装------jerrySeed
            # 定义
            QB_CACHE_SIZE=""
            QB_VERSION="4.3.9"
            LT_VERSION="v1.2.20"
            INSTALL_VERTEX=1  # 默认安装vt
            VERTEX_OPTION="-v"  # 默认包含-v选项
            
            # 自定义设置
            echo -e "${YELLOW}请设置qBittorrent缓存大小（单位为MiB，建议设置为1/4内存大小）:${NC}"
            read -p "请输入缓存大小: " QB_CACHE_SIZE
            
            echo -e "${YELLOW}请设置qBittorrent版本号（回车默认4.3.9）:${NC}"
            read -p "请输入版本号 [4.3.9]: " QB_VERSION_INPUT
            if [ -z "$QB_VERSION_INPUT" ]; then
                QB_VERSION="4.3.9"
            else
                QB_VERSION=$QB_VERSION_INPUT
            fi
            
            echo -e "${YELLOW}请设置libtorrent版本号（回车默认v1.2.20）:${NC}"
            read -p "请输入版本号 [v1.2.20]: " LT_VERSION_INPUT
            if [ -z "$LT_VERSION_INPUT" ]; then
                LT_VERSION="v1.2.20"
            else
                LT_VERSION=$LT_VERSION_INPUT
            fi
            
            # 询问是否安装vertex
            echo -e "${YELLOW}是否安装vertex？（回车默认安装，0不安装）:${NC}"
            read -p " [1/0]: " VERTEX_CHOICE
            if [ "$VERTEX_CHOICE" = "0" ]; then
                INSTALL_VERTEX=0
                VERTEX_OPTION=""  # 不包含-v选项
            fi
            
            # 确认
            echo -e "\n${GREEN}您设置的参数如下:${NC}"
            echo -e "${GREEN}qBittorrent缓存大小: ${QB_CACHE_SIZE} MiB${NC}"
            echo -e "${GREEN}qBittorrent版本: ${QB_VERSION}  | libtorrent版本: ${LT_VERSION} ${NC}"
            echo -e "${GREEN}默认用户名: admin  | 默认密码: budongkeji.cc${NC}"
            if [ "$INSTALL_VERTEX" -eq 1 ]; then
                echo -e "${GREEN}同时将安装最新版Vertex并启用BBRx${NC}"
            else
                echo -e "${YELLOW}不安装Vertex，自动启用BBRx${NC}"
            fi

            echo -e "\n${RED} ❤ 原项目jerry048/Dedicated-Seedbox,好用记得给jerry大佬点个star！❤${NC}"
            echo -e "\n${YELLOW}"
            echo -e "\n${YELLOW}请选择操作:${NC}"
            echo -e "${GREEN}1) 开始安装${NC}"
            echo -e "${GREEN}2) 重新设置${NC}"
            read -p "请输入选择 [1/2]: " CHOICE
            
            if [ "$CHOICE" -eq 1 ]; then
                    execute_command "bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u admin -p budongkeji.cc -c ${QB_CACHE_SIZE} -q ${QB_VERSION} -l ${LT_VERSION} ${VERTEX_OPTION} -x" "Jerry大佬的Dedicated-Seedbox安装"
                    echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
                    echo -e "\n${GREEN}Qbit的默认账户：admin | 默认密码：budongkeji.cc ${NC}"
                    if [ "$INSTALL_VERTEX" -eq 1 ]; then
                        echo -e "\n${GREEN}Vt的默认账户：admin | 默认密码：budongkeji.cc ${NC}"
                    fi
                    echo -e "\n${GREEN}请输入reboot，重启小鸡使配置生效。 ${NC}"
                    sleep 1
            elif [ "$CHOICE" -eq 2 ]; then
                # 重新设置
                show_submenu_2
                return
            else
                echo -e "${RED}无效的选择，请重新选择${NC}"
                show_submenu_2
                return
            fi
            show_submenu_2
            ;;

        205)
        #Docker安装------LibreTV
            check_docker
            
            echo -e "${YELLOW}是否需要设置网站密码和管理员密码？${NC}"
            echo -e "${YELLOW}1) 设置*强烈建议${NC}"
            echo -e "${YELLOW}2) 不设置${NC}"
            if [ -t 0 ]; then
                read -r password_choice
                password_choice=${password_choice:-2}
            else
                password_choice=2
                echo -e "${YELLOW}非交互式环境，默认不设置密码${NC}"
            fi
            
            # 根据选择处理密码
            password_env=""
            if [ "$password_choice" = "1" ]; then
                echo -e "${YELLOW}设置网站访问密码 [回车默认 budongkeji.cc]:${NC} "
                if [ -t 0 ]; then
                    read -r user_password
                    user_password=${user_password:-budongkeji.cc}
                else
                    user_password="budongkeji.cc"
                fi
                
                echo -e "${YELLOW}设置管理员密码 [回车默认 budongkeji.cc]:${NC} "
                if [ -t 0 ]; then
                    read -r admin_password
                    admin_password=${admin_password:-budongkeji.cc}
                else
                    admin_password="budongkeji.cc"
                fi
                
                password_env="-e PASSWORD=$user_password -e ADMINPASSWORD=$admin_password"
                echo -e "${GREEN}已设置密码 - 访问: $user_password, 管理员: $admin_password${NC}"
            else
                echo -e "${GREEN}选择不设置密码${NC}"
            fi
            
            # 设置端口
            echo -e "${YELLOW}设置访问端口 [回车默认 18899]:${NC} "
            if [ -t 0 ]; then
                read -r custom_port
                custom_port=${custom_port:-18899}
            else
                custom_port=18899
                echo -e "${YELLOW}非交互式环境，使用默认端口 $custom_port${NC}"
            fi
            
            # 执行安装
            if [ "$password_choice" = "1" ]; then
                execute_command "docker run -d --name libretv --restart unless-stopped -p $custom_port:8080 $password_env bestzwei/libretv:latest" "LibreTV 安装，端口:$custom_port，已设置密码"
            else
                execute_command "docker run -d --name libretv --restart unless-stopped -p $custom_port:8080 bestzwei/libretv:latest" "LibreTV 安装，端口:$custom_port，无密码"
            fi
            
            echo -e "\n${GREEN}1 秒后自动返回子菜单...${NC}"
            if [ "$password_choice" = "1" ]; then
                echo -e "\n${GREEN}浏览器访问 http://$server_ip:$custom_port 即可打开LibreTV${NC}"
                echo -e "\n${GREEN}网站密码: $user_password${NC}"
                echo -e "\n${GREEN}管理员密码: $admin_password${NC}"
                echo -e "\n${GREEN}强烈建议使用NP进行反代！${NC}"
            else
                echo -e "\n${GREEN}浏览器访问 http://$server_ip:$custom_port (默认为http://$server_ip:18899) 即可打开，强烈建议使用NP进行反代！${NC}"
            fi
            
            sleep 1
            show_submenu_2
            ;;
        
        206)
            #Docker安装------KasmWebChrome
            check_docker
            
            # 设置端口
            while true; do
                read -p "请输入KasmWeb Chrome访问端口 (10000-65535): " kasm_port
                if [[ "$kasm_port" =~ ^[0-9]+$ && "$kasm_port" -ge 10000 && "$kasm_port" -le 65535 ]]; then
                    break
                else
                    echo -e "${RED}端口必须是10000-65535之间的数字，请重新输入${NC}"
                fi
            done
            
            # 设置密码
            read -p "请设置访问密码 (回车默认budongkeji.cc): " kasm_password
            if [ -z "$kasm_password" ]; then
                kasm_password="budongkeji.cc"
            fi
            
            execute_command "mkdir -p /root/docker/kasmweb && cd /root/docker/kasmweb && echo -e \"version: '3.8'\nservices:\n  chrome:\n    image: kasmweb/chrome:1.16.0\n    shm_size: 512m\n    ports:\n      - '$kasm_port:6901'\n    environment:\n      - VNC_PW=$kasm_password\n    restart: unless-stopped\" > docker-compose.yml && docker-compose up -d" "KasmWeb Chrome 安装，端口:$kasm_port ，密码$kasm_password "
            echo -e "\n${GREEN}1 秒后自动返回子菜单...${NC}"
            echo -e "\n${GREEN}浏览器访问 https://$server_ip:$kasm_port 即可打开 KasmWeb Chrome ${NC}"
            echo -e "\n${RED}注意：请访问https！！！默认账户：kasm_user  默认密码 $kasm_password${NC}"
            echo -e "\n${RED}用前须知：如果长期使用，请配置SSL证书确保数据安全！！！${NC}"
            sleep 1
            show_submenu_2
            ;;

        207)
            #Docker安装------Firefox
            check_docker
            
            # 设置HTTP端口
            while true; do
                read -p "请输入Firefox HTTP访问端口 (10000-65535): " firefox_http_port
                if [[ "$firefox_http_port" =~ ^[0-9]+$ && "$firefox_http_port" -ge 10000 && "$firefox_http_port" -le 65535 ]]; then
                    break
                else
                    echo -e "${RED}端口必须是10000-65535之间的数字，请重新输入${NC}"
                fi
            done
            
            # 设置VNC端口
            while true; do
                read -p "请输入Firefox VNC访问端口 (10000-65535): " firefox_vnc_port
                if [[ "$firefox_vnc_port" =~ ^[0-9]+$ && "$firefox_vnc_port" -ge 10000 && "$firefox_vnc_port" -le 65535 && "$firefox_vnc_port" != "$firefox_http_port" ]]; then
                    break
                else
                    echo -e "${RED}端口必须是10000-65535之间的数字且不能与HTTP端口相同，请重新输入${NC}"
                fi
            done
            
            # 设置密码
            read -p "请设置Firefox VNC访问密码 (回车默认budongkeji.cc): " firefox_password
            if [ -z "$firefox_password" ]; then
                firefox_password="budongkeji.cc"
            fi
            
            execute_command "mkdir -p /root/docker/firefox && cd /root/docker/firefox && echo -e \"version: '3'\nservices:\n  firefox:\n    image: jlesage/firefox\n    container_name: firefox\n    restart: unless-stopped\n    environment:\n      - TZ=America/New_York\n      - DISPLAY_WIDTH=1920\n      - DISPLAY_HEIGHT=1080\n      - KEEP_APP_RUNNING=1\n      - ENABLE_CJK_FONT=1\n      - VNC_PASSWORD=$firefox_password\n    ports:\n      - \\\"$firefox_http_port:5800\\\"\n      - \\\"$firefox_vnc_port:5900\\\"\n    volumes:\n      - /Docker/firefox:/config:rw\n    shm_size: 6g\" > docker-compose.yml && docker-compose up -d" "Firefox 安装，端口:$firefox_http_port&$firefox_vnc_port"
            echo -e "\n${GREEN}1 秒后自动返回子菜单...${NC}"
            echo -e "\n${GREEN}浏览器访问 http://$server_ip:$firefox_http_port 即可打开 Firefox，VNC端口:$firefox_vnc_port，密码为 $firefox_password${NC}"
            echo -e "\n${RED}用前须知：如果长期使用，请配置SSL证书确保数据安全！！！${NC}"
            sleep 1
            show_submenu_2
            ;;

        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_2
            ;;
    esac
}

# 子菜单3
show_submenu_3() {
    show_header
    echo -e "${BORDER}${WHITE}           3.服务器测试                      ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[301]${NC} ${RED}${BOLD}NodeQuality融合测试 *荐${NC}   ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[302]${NC} 网速测试    ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}       ${BORDER}${NC}"
    echo -e "${BORDER}│${NC}   ${GREEN}[0]${NC} 返回主菜单    ${BORDER}${NC}"
    echo -e "${BORDER}=============================================${NC}"

    echo -e "\n${YELLOW}请输入选项号码:${NC} "
    
    if [ -t 0 ]; then
        read -r subchoice
        process_submenu_3_choice "$subchoice"
    else
        echo -e "${YELLOW}非交互式环境，无法读取输入。${NC}"
        exit 0
    fi
}

process_submenu_3_choice() {
    local subchoice="$1"
    case $subchoice in
        301)
            execute_command "bash <(curl -sL https://run.NodeQuality.com)" "NodeQuality融合测试"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_3
            ;;
        302)
            execute_command "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash && sudo apt-get install speedtest -y && speedtest" "网速测试"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_3
            ;;
        0)
            show_main_menu
            ;;
        *)
            echo -e "\n${RED}错误: 无效的选项！${NC}"
            echo -e "\n${PURPLE}1秒后自动返回子菜单...${NC}"
            sleep 1
            show_submenu_3
            ;;
    esac
}

# 主函数
main() {
    show_main_menu
}

# 执行主函数
main "$@"
