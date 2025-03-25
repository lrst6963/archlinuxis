#!/bin/bash
# Arch Linux 全自动安装脚本
# 作者：Lrst_6963 (优化：助手)
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

# 检查命令执行结果
check_result() {
    if [ $? -ne 0 ]; then
        error_exit "步骤失败：$1"
    fi
}

#-----------------------------
# 阶段A：基础系统安装
#-----------------------------

# 网络连接测试
test_network() {
    echo -e "${blue}[1/5] 正在测试网络连接...${een}"
    ping -c 4 archlinux.org || error_exit "网络连接失败，请检查网络设置"
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
    echo -e "${blue}[3/5] 正在同步系统时间...${een}"
    timedatectl set-ntp true
    timedatectl status || error_exit "时间同步失败"
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
    echo -e "\n${green}请输入根分区路径（如/dev/nvme0n1p2）：${een}"
    read -r root_part
    validate_partition "$root_part"

    echo -e "${green}请输入EFI分区路径（如/dev/nvme0n1p1）：${een}"
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
        mkfs.ext4 -F "$efi_part" || error_exit "EFI分区格式化失败"
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
    pacstrap /mnt base base-devel linux linux-firmware dhcpcd nano sudo iwd vim bash-completion networkmanager
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
    	# 安装图形管理工具
    	echo -e "${blue}[2/3] 正在安装蓝牙管理工具...${een}"
    	pacman -S --noconfirm blueman
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
# 安装基础网络管理程序和SSH
network_install(){
    echo -e "${blue}[5/6] 安装SSH和网络管理器...${een}"
    pacman -S networkmanager openssh --noconfirm
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
    sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
}

# 安装KDE桌面
install_kde() {
    echo -e "${blue}[2/4] 正在安装KDE桌面环境...${een}"
    pacman -S --needed kde-applications konsole dolphin sddm plasma-nm --noconfirm
    pacman -S --needed adobe-source-han-serif-cn-fonts wqy-zenhei noto-fonts-cjk noto-fonts-emoji noto-fonts-extra --noconfirm
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
    pacman -S firefox chromium make ntfs-3g neofetch git wget kate bind --noconfirm
}
# 检测显卡类型
detect_gpu() {
    echo -e "${blue}[硬件检测] 正在识别显卡类型...${een}"
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
    pacman -S --noconfirm radeontop radeon-profile
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
    clear
    echo -e "${blue}=============================================="
    echo "          Arch Linux 全自动安装向导"
    echo "=============================================="
    echo "1. 全新安装Arch Linux"
    echo "2. 进入Chroot配置"
    echo "3. 安装桌面环境"
    echo "0. 退出"
    echo -e "==============================================${een}"
}

# 安装流程控制
install_flow() {
    while true; do
        main_menu
        read -rp "请输入选项 (0-3): " choice
        case $choice in
            1)
                # 全新安装流程
                test_network
                show_partition_guide
		auto_mount
                configure_mirrors
                sync_time
                install_base
                echo -e "${green}基础系统安装完成！请输入 arch-chroot /mnt 进入配置${een}"
                ;;
            2)
                # Chroot配置流程
                configure_localization
                set_hostname
                set_root_password
		network_install
                install_bootloader
                install_ucode
		install_gpu_drives
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
