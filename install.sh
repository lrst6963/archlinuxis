#!/bin/bash
# Arch Linux 自动安装脚本
# 作者：Lrst_6963
# 功能：支持基础系统安装、Chroot配置、图形界面安装
# 注意：请以root用户执行，安装前请备份重要数据！

#-----------------------------
# 颜色定义
#-----------------------------
red='\033[31m'     # 错误提示
green='\033[32m'   # 成功提示
yellow='\033[33m'   # 警告提示
blue='\033[34m'     # 菜单选项
een='\033[0m'       # 颜色重置

#-----------------------------
# 通用功能函数
#-----------------------------

# 暂停等待用户按键
pause() {
    echo -e "${green}\n按任意键继续...${een}"
    read -n1 -s
}

# 错误处理函数
error_exit() {
    echo -e "${red}[错误] $1${een}" 1>&2
    exit 1
}
# 错误提示函数
error_echo() {
    echo -e "${red}[错误] $1${een}" >&2
    return 1
}
# 成功提示函数
success_echo() {
    echo -e "${green}[成功] $1${een}" >&2
    return 1
}

# 检查命令执行结果
check_result() {
    if [ $? -ne 0 ]; then
        error_exit "步骤失败：$1"
    fi
}

# 获取合适的普通用户
get_normal_user() {
    # 如果已经是普通用户，直接返回当前用户名
    [ "$EUID" -ne 0 ] && { echo "$USER"; return; }

    # 尝试按优先级获取可能的普通用户
    local candidates=(
        "$SUDO_USER"                  # sudo 执行时的原始用户
        "$(logname 2>/dev/null)"      # 登录用户
        "$(who | awk 'NR==1{print $1}')"  # 当前登录的第一个用户
        "$(ls /home | head -n 1)"     # /home 下的第一个用户
    )

    for user in "${candidates[@]}"; do
        # 验证用户是否存在且不是系统用户（UID >= 1000）
        if id -u "$user" >/dev/null 2>&1 && \
           [ "$(id -u "$user")" -ge 1000 ] && \
           [ "$user" != "root" ]; then
            echo "$user"
            return
        fi
    done

    error_echo "未找到合适的普通用户！请手动创建普通用户后再执行。"
    return 1
}

# yay安装函数
install_yay() {
    # 检查运行环境
    if ! uname -a | grep -qi 'arch'; then
        error_echo "此脚本仅适用于 Arch Linux 及其衍生发行版"
        return 1
    fi
    # 获取执行用户身份
    if [ "$EUID" -eq 0 ]; then
        NORMAL_USER=$(get_normal_user) || return 1
        RUN_CMD="sudo -u $NORMAL_USER"
        echo -e "${yellow}[信息] 检测到 root 身份，将使用普通用户 $NORMAL_USER 执行安装${een}"
    else
        RUN_CMD=""
        NORMAL_USER="$USER"
    fi

    # 安装依赖（需要root权限）
    echo -e "${yellow}[信息] 正在安装依赖...${een}"
    sudo pacman -S --needed --noconfirm git base-devel go || {
        error_echo "依赖安装失败，请检查：\n1. 网络连接\n2. 软件源配置\n3. sudo权限"
        return 1
    }
    safe_mktemp_dir() {
	    local max_retries=5
	    local retry_count=0
	    
	    while [ $retry_count -lt $max_retries ]; do
	        local temp_dir=$($RUN_CMD mktemp -d)
	        # 检查目录是否为空
	        if [ -d "$temp_dir" ] && [ -z "$(ls -A $temp_dir)" ]; then
	            echo "$temp_dir"
	            return 0
	        else
	            # 如果不是空目录则删除重试
	            rm -rf "$temp_dir"
	            ((retry_count++))
	        fi
	    done
	    
	    error_echo "无法创建空临时目录（重试 $max_retries 次后失败）"
	    return 1
    }
    # 创建临时构建目录（使用安全创建函数）
    build_dir=$(safe_mktemp_dir) || return 1
    echo -e "${yellow}[信息] 使用临时构建目录: $build_dir${een}"

    # 克隆仓库（指定目标目录）
    echo -e "${yellow}[信息] 正在克隆 yay 仓库...${een}"
    if ! $RUN_CMD git clone https://aur.archlinux.org/yay.git "$build_dir/yay"; then
        error_echo "仓库克隆失败，请检查：\n1. 网络连接\n2. git 是否安装\n3. 磁盘空间"
        return 1
    fi

    # 构建安装
    echo -e "${yellow}[信息] 正在构建安装 yay...${een}"
    if ! (cd "$build_dir/yay" && $RUN_CMD makepkg -si --noconfirm); then
        rm -rf "$build_dir"
        error_echo "构建安装失败，请检查：\n1. 依赖是否完整\n2. 磁盘空间\n3. 网络连接"
        return 1
    fi

    # 清理临时目录
    rm -rf "$build_dir" && success_echo "已清理临时构建文件"

    # 验证安装
    if command -v yay &>/dev/null; then
        success_echo "yay 安装成功！版本信息：$($RUN_CMD yay --version | head -n 1)"
    else
        error_echo "安装验证失败，yay 命令未找到"
        return 1
    fi

    # 显示使用说明
    echo -e "\n${yellow}常用命令："
    echo -e "  yay -S 包名      # 安装软件包"
    echo -e "  yay -Ss 关键词   # 搜索软件包"
    echo -e "  yay -Syu         # 更新系统和AUR包"
    echo -e "  yay -Qu          # 查看可更新包"
    echo -e "  yay -Rns 包名    # 彻底卸载软件包${een}"
    return 0
}


#-----------------------------
# 阶段A：基础系统安装
#-----------------------------

# 网络连接测试
test_network() {
    echo -e "${blue}[1/5] 正在测试网络连接...${een}"
    ping -c 4 www.bing.com || error_exit "网络连接失败，请检查网络设置"
    echo -e "${green}✓ 网络连接正常${een}"
}

# 镜像源配置
configure_mirrors() {
    echo -e "${blue}[2/5] 正在配置镜像源...${een}"
    cat > /etc/pacman.d/mirrorlist <<-EOF
## 中国镜像源（优化列表）
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch
Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch
Server = https://mirror.bfsu.edu.cn/archlinux/\$repo/os/\$arch
EOF
    pacman -Syy
    check_result "镜像源配置失败"
}

# 时间同步
sync_time() {
    echo -e "${blue}[3/5] 正在配置时间同步...${een}"
    
    # 备份原始配置
    cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.bak
    
    # 自定义NTP服务器（国内推荐）
    cat > /etc/systemd/timesyncd.conf <<-'EOF'
[Time]
# 国内NTP服务器列表
NTP=ntp.aliyun.com  ntp.tencent.com  cn.ntp.org.cn  ntp.tuna.tsinghua.edu.cn
FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
# 加快初始同步速度
PollIntervalMinSec=16
PollIntervalMaxSec=32
EOF

    # 启用并强制同步
    timedatectl set-ntp true
    systemctl restart systemd-timesyncd
    
    # 验证同步状态
    echo -e "${green}当前使用的NTP服务器：${een}"
    timedatectl show-timesync --property=ServerName --value
    
    echo -e "${green}时间同步状态：${een}"
    if timedatectl status | grep -q "synchronized: yes"; then
        echo -e "${green}✓ 时间同步成功${een}"
    else
        echo -e "${yellow}⚠ 时间未立即同步，正在后台处理...${een}"
        sleep 3
        timedatectl status || error_exit "时间同步失败"
    fi
}

# 磁盘分区提示
show_partition_guide() {
    clear
    echo -e "${yellow}====================== 分区指南 ======================${een}"
    echo -e "请使用 fdisk/cfdisk/gdisk 完成以下分区："
    echo -e "1. EFI系统分区 (建议≥300MB，类型为EFI System)"
    echo -e "2. 根分区 (建议≥20GB，类型为Linux filesystem)"
    echo -e "3. 交换分区 (可选，建议≥内存大小，类型为Linux swap)"
    echo -e "${yellow}======================================================${een}"
    echo -e "${blue}完成后请继续本安装程序${een}"
    pause
}
# 验证分区有效性
validate_partition() {
    local partition=$1
    if [ ! -b "$partition" ]; then
        error_exit "分区 $partition 不存在，请检查设备路径"
    fi
}
# 自动挂载分区
auto_mount() {
    # 卸载已有挂载
    umount -R /mnt 2>/dev/null

    # 获取用户输入
    echo -e "\n${green}请输入根分区路径（如/dev/nvme0n1p2）：${een}\c"
    read -r root_part
    validate_partition "$root_part"

    echo -e "${green}请输入EFI分区路径（如/dev/nvme0n1p1）：${een}\c"
    read -r efi_part
    validate_partition "$efi_part"

    # 格式化确认（危险操作，默认跳过）
    echo -e "${red}警告：格式化会清除分区所有数据！${een}"
    echo -e -n "${green}是否格式化根分区？(y/N): ${een}"
    read -r format_confirm
    if [[ "${format_confirm,,}" == "y" ]]; then
        mkfs.ext4 -F "$root_part" || error_exit "根分区格式化失败"
    fi
    echo -e -n "${green}是否格式化EFI分区？(y/N): ${een}"
    read -r format_efi_confirm
    if [[ "${format_efi_confirm,,}" == "y" ]]; then
        mkfs.vfat -F 32 "$efi_part" || error_exit "EFI分区格式化失败"
    fi

    # 挂载根分区
    echo -e "${blue}正在挂载根分区...${een}"
    mount "$root_part" /mnt || error_exit "根分区挂载失败"

    # 创建并挂载EFI分区
    echo -e "${blue}正在挂载EFI分区...${een}"
    mkdir -p /mnt/boot/efi
    mount "$efi_part" /mnt/boot/efi || error_exit "EFI分区挂载失败"

    # 检查挂载结果
    echo -e "${green}当前挂载信息：${een}"
    lsblk -o NAME,MOUNTPOINT,FSTYPE,SIZE "$root_part" "$efi_part"
    pause
}

# 基础系统安装
install_base() {
    echo -e "${blue}[4/5] 正在安装基础系统...${een}"
    pacstrap /mnt base base-devel linux linux-firmware linux-headers dhcpcd nano sudo iwd vim bash-completion networkmanager usbutils
    check_result "基础系统安装失败"
    echo -e "${blue}[5/5] 生成文件系统表...${een}"
    genfstab -U /mnt >> /mnt/etc/fstab
    cat /mnt/etc/fstab || error_exit "fstab生成失败"
}

#-----------------------------
# 阶段B：Chroot系统配置
#-----------------------------

# 检测蓝牙硬件
detect_bluetooth() {
    echo -e "${blue}[硬件检测] 正在检测蓝牙设备...${een}"
    if lsusb | grep -i "bluetooth" || lspci | grep -i "bluetooth"; then
        echo -e "${green}检测到蓝牙硬件${een}"
        return 0
    else
        echo -e "${yellow}未检测到蓝牙设备${een}"
        return 1
    fi
}

# 安装蓝牙支持
install_bluetooth() {
    if detect_bluetooth; then
        echo -e "${green}检测到蓝牙设备，开始安装支持组件...${een}"
        # 安装基础软件包
 	echo -e "${blue}[1/3] 正在安装蓝牙核心组件...${een}"
    	pacman -S --noconfirm bluez bluez-utils bluez-plugins  
    	# 安装音频支持
    	echo -e "${blue}[3/3] 正在安装蓝牙音频支持...${een}"
    	pacman -S --noconfirm pulseaudio-bluetooth
    	# 配置服务
    	echo -e "${green}启用蓝牙服务...${een}"
    	systemctl enable --now bluetooth.service
    else
        echo -e "${yellow}跳过蓝牙组件安装${een}"
    fi
    }


# 设置时区与本地化
configure_localization() {
    echo -e "${blue}[1/6] 正在配置本地化设置...${een}"
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock --systohc
    sed -i 's/#zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
}

# 设置主机名
set_hostname() {
    echo -e "${green}请输入主机名：${een}"
    read -r hostname
    echo "$hostname" > /etc/hostname
    cat > /etc/hosts <<-EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
}

# 配置Root密码
set_root_password() {
    echo -e "${blue}[3/6] 设置root密码${een}"
    passwd root || error_exit "密码设置失败"
}

# 安装引导程序
install_bootloader() {
    echo -e "${blue}[4/6] 正在安装GRUB引导...${een}"
    pacman -S grub efibootmgr --noconfirm
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux
    if [ $? -ne 0 ];then 
    	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --removable || error_exit "GRUB安装失败"
    	success_echo "GRUB安装成功"
    fi
    success_echo "GRUB安装成功"
    grub-mkconfig -o /boot/grub/grub.cfg || error_exit "GRUB配置失败"
}

# 安装微码
install_ucode() {
    echo -e "${blue}[5/6] 检测并安装CPU微码...${een}"
    if grep -q "Intel" /proc/cpuinfo; then
        pacman -S intel-ucode --noconfirm
    elif grep -q "AMD" /proc/cpuinfo; then
        pacman -S amd-ucode --noconfirm
    fi
}
# 启用32位库支持并安装基础网络管理程序和SSH
network_install(){
    grep -x "\[multilib\]" /etc/pacman.conf > /dev/null
    if [ "$?" != "0" ];then
       	echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | tee -a /etc/pacman.conf > /dev/null
    fi
    /etc/pacman.conf
    echo -e "${blue}[5/6] 安装SSH和网络管理器...${een}"
    pacman -Sy networkmanager openssh --noconfirm
    systemctl disable iwd                                                  #确保iwd开机处于关闭状态，其无线连接会与NetworkManager冲突
    systemctl enable NetworkManager
    #允许ROOT用户密码登陆SSH
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    systemctl enable sshd
}

#-----------------------------
# 阶段C：桌面环境安装
#-----------------------------

# 创建普通用户
create_user() {
    echo -e "${green}请输入要创建的用户名：${een}\c"
    read -r username
    useradd -m -G wheel -s /bin/bash "$username"
    echo -e "${green}设置用户 $username 的密码：${een}"
    passwd "$username"
    echo ' %wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers
}

# 安装KDE桌面
install_kde() {
    echo -e "${blue}[2/4] 正在安装完整KDE桌面环境...${een}"
    pacman -Sq kde-applications plasma wayland sddm --noconfirm
    pacman -Sq adobe-source-han-serif-cn-fonts wqy-zenhei noto-fonts-cjk noto-fonts-emoji noto-fonts-extra --noconfirm
    systemctl enable sddm
}

# 安装中文输入法
install_fcitx() {
    echo -e "${blue}[3/4] 正在安装中文输入法...${een}"
    pacman -S fcitx5-im fcitx5-chinese-addons fcitx5-pinyin-zhwiki --noconfirm
    cat >> /etc/environment <<-EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
}

# 安装常用软件
install_software() {
    echo -e "${blue}[4/4] 正在安装常用软件...${een}"
    pacman -Sq firefox chromium make ntfs-3g neofetch git wget kate bind --noconfirm
}
# 检测显卡类型
detect_gpu() {
    local gpu_info=$(lspci -k | grep -A 2 -E "(VGA|3D)")
    
    if echo "$gpu_info" | grep -iq "nvidia"; then
        echo "nvidia"
    elif echo "$gpu_info" | grep -iq "amd/ati"; then
        echo "amd"
    elif echo "$gpu_info" | grep -iq "intel"; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# 安装NVIDIA驱动
install_nvidia() {
    echo -e "${green}检测到NVIDIA显卡，推荐安装方案："
    echo "1. 专有驱动 (性能优化)"
    echo "2. 开源驱动 (nouveau)"
    echo -e "${red}请选择安装类型 (1/2): ${een}"
    read -r choice
    
    case $choice in
        1)
            echo -e "${blue}正在安装NVIDIA专有驱动...${een}"
            pacman -S --noconfirm nvidia nvidia-settings nvidia-utils lib32-nvidia-utils
            # 处理Optimus双显卡
            if lspci | grep -iq "intel"; then
                echo -e "${yellow}检测到双显卡配置，安装Optimus管理器...${een}"
                pacman -S --noconfirm optimus-manager
                cat > /etc/optimus-manager/optimus-manager.conf <<-EOF
[optimus]
switching=bbswitch
pci_power_control=no
EOF
                systemctl enable optimus-manager
            fi
            # 更新内核镜像
            mkinitcpio -P
            ;;
        2)
            echo -e "${blue}正在安装开源驱动...${een}"
            pacman -S --noconfirm xf86-video-nouveau
            ;;
        *)
            echo -e "${red}无效选择，跳过NVIDIA驱动安装${een}"
            ;;
    esac
}

# 安装AMD驱动
install_amd() {
    echo -e "${blue}正在安装AMD显卡驱动...${een}"
    pacman -S --noconfirm mesa lib32-mesa vulkan-radeon libva-mesa-driver mesa-vdpau
    echo "加速视频解码支持："
    pacman -S --noconfirm radeontool radeontop rocm-llvm vulkan-radeon lib32-vulkan-radeon
}

# 安装Intel驱动
install_intel() {
    echo -e "${blue}正在安装Intel核显驱动...${een}"
    pacman -S --noconfirm mesa lib32-mesa vulkan-intel intel-media-driver libva-utils
    # 启用早期KMS启动
    sed -i 's/MODULES=()/MODULES=(i915)/' /etc/mkinitcpio.conf
    mkinitcpio -P
}

# 显卡驱动主函数
install_gpu_drivers() {
    echo -e "${blue}[硬件检测] 正在识别显卡类型...${een}"
    local gpu_type=$(detect_gpu)
    
    case $gpu_type in
        "nvidia")
            install_nvidia
            ;;
        "amd")
            install_amd
            ;;
        "intel")
            install_intel
            ;;
        *)
            echo -e "${red}无法识别的显卡类型，请手动安装驱动${een}"
            echo -e "${yellow}检测到的显卡信息："
            lspci -k | grep -A 2 -E "(VGA|3D)"
            echo -e "${een}"
            ;;
    esac
    
    # 安装通用Vulkan支持
    pacman -S --noconfirm vulkan-icd-loader lib32-vulkan-icd-loader
}

#-----------------------------
# 主菜单系统
#-----------------------------

main_menu() {
    #clear
    echo -e "${blue}==============================================${een}"
    echo -e "          Arch Linux 全自动安装向导"
    echo -e "${blue}==============================================${een}"
    echo -e "1. 全新安装Arch Linux"
    echo -e "2. 进入Chroot配置"
    echo -e "3. 安装桌面环境"
    echo -e "4. 安装yay(AUR助手)(仅限高级用户)"
    echo -e "0. 退出"
    echo -e "${blue}==============================================${een}"
}

# 安装流程控制
install_flow() {
    while true; do
        main_menu
        read -rp "请输入选项 (0-4): " choice
        case $choice in
            1)
                # 全新安装流程
                test_network
                show_partition_guide
		auto_mount
                configure_mirrors
                sync_time
                install_base
		chmod +x ./install.sh && cp ./install.sh /mnt/root/install.sh
                echo -e "${green}基础系统安装完成！请退出脚本输入:arch-chroot /mnt /root/install.sh 继续安装${een}"
                ;;
            2)
                # Chroot配置流程
                configure_localization
                set_hostname
                set_root_password
		network_install
                install_bootloader
                install_ucode
  		install_gpu_drivers
                echo -e "${green}系统配置完成！建议重启后继续安装桌面环境${een}"
                ;;
            3)
                # 桌面环境安装
                create_user
		install_bluetooth
                install_kde
                install_fcitx
                install_software
                echo -e "${green}桌面环境安装完成！输入 reboot 重启系统${een}"
                ;;
            4)
                install_yay
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "${red}无效选项，请重新输入${een}"
                ;;
        esac
        pause
    done
}

#-----------------------------
# 脚本执行入口
#-----------------------------
if [ "$(id -u)" -ne 0 ]; then
    error_exit "请以root用户运行此脚本！"
fi

install_flow
