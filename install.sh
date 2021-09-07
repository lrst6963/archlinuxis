#!/bin/bash
#By Lrst_6963
red='\033[31m'
green='\033[32m'
een='\033[0m'
blue='\033[34m'
pause(){
    get_char() {
        SAVEDSTTY=$(stty -g)
        stty -echo
        stty raw
        dd if=/dev/tty bs=1 count=1 2>/dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }

    if [ -z "$1" ]; then
        echo 'Please press any key to continue...'
    else
        echo -e "$1"
    fi
    get_char
}

#A
testnet() {
    ping www.gnu.org -c 4
    if [ $? != 0 ]; then
        echo -e "$red NetWork error! $een"
        exit
    else
        clear
        echo -e "$green Network connection is successful $een"
    fi
}
cml() {
    clear
    echo -e "$green Do you update Arch Linux CN mirror? $red (yes/no) $een $een "
    read cmor
    if [ $cmor == 'yes' ]; then
        echo "
##
## Arch Linux repository mirrorlist
## Generated on 2021-09-07
##

## China
Server = http://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.cqu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.dgut.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.hit.edu.cn/archlinux/$repo/os/$arch
Server = http://mirror.lzu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.neusoft.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.nju.edu.cn/archlinux/$repo/os/$arch
Server = http://mirror.redrock.team/archlinux/$repo/os/$arch
Server = http://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.wsyu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.zju.edu.cn/archlinux/$repo/os/$arch" >/etc/pacman.d/mirrorlist
    pacman -Syy
    fi
}
timeupdate() {
    timedatectl set-ntp true
    timedatectl status
}
installlinux() {
    clear
    echo -e "$green Do you have an Archlinux infrastructure? $red (yes/no) $een $een"
    read ilor
    if [ $ilor == 'yes' ]; then
        pacstrap /mnt base base-devel linux linux-firmware
        pacstrap /mnt dhcpcd iwd vim sudo bash-completion
        genfstab -U /mnt >> /mnt/etc/fstab
        cat /mnt/etc/fstab
    fi
}
swchroot() {
    echo -e "$green Do you enter a new system? $red (yes/no) $een $een"
    read scor
    if [ $scor == 'yes' ]; then
        arch-chroot /mnt bash /install.sh
    fi
}
#A

#B
sethn() {
    echo -e "$green Set the hostname you want (for example: MyLinux) $een"
    read hn
    echo "
    127.0.0.1   localhost
    ::1         localhost
    127.0.1.1   $hn
    "
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock --systohc
}
setlang() {
    echo '
 en_US.UTF-8 UTF-8
 zh_CN.UTF-8 UTF-8
 ja_JP.UTF-8 UTF-8
    ' >> /etc/locale.gen
    locale-gen
    echo 'LANG=zh_CN.UTF-8' >/etc/locale.conf
}
iucode() {
    pacman -S intel-ucode #Intel
    pacman -S amd-ucode   #AMD
}
srootp() {
    clear
    echo -e "$green Please keep in mind the Root User password you set $een"
    passwd root
}
igrub() {
    pacman -S grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ArchLinux
    grub-mkconfig -o /boot/grub/grub.cfg
    mkdir -p /efi/EFI/BOOT
    cp /efi/EFI/ArchLinux/grubx64.efi /efi/EFI/BOOT/BOOTX64.EFI
}
reb() {
    echo -e "$green Note that before restarting, install the installation drive first, otherwise you will be restarted or enter the installer instead of the installed system. $een"
    echo -e "$green After restart, please perform this step and select step 2, whether it is restarted? $red (yes/no) $een $een"
    read reor
    if [ $reor == 'yes' ]; then
        reboot
    fi
}
#B

#C
sdni() {
    systemctl start dhcpcd
    pacman -Syyu
}
snnu() {
    echo -e "$green Create a new non-root user $een"
    echo -e "$green Enter a New User name $een"
    read nur
    groupadd -g 1000 $nur
    useradd -m -g $nur -s /bin/bash $nur
    echo -e "$green Set the password for the new user $nur $een"
    passwd $nur
    echo "%$nur ALL=(ALL) ALL" >> /etc/sudoers
}
iked() {
    pacman -S plasma-meta konsole dolphin
    if [ $? != '0' ]; then
        pacman -S plasma-meta konsole dolphin
    fi
    systemctl enable sddm
}
setswap() {
    clear
    echo -e "$green Do you set SWAP? $red (yes/no) $een $een"
    read sewor
    if [ $sewor == 'yes' ]; then
        echo -e "$green Enter the size of your SWAP file(MB): $een"
        read swsize
        dd if=/dev/zero of=/swapfile bs=1M count=$swsize status=progress
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
    fi
}
ibf() {
    systemctl disable iwd
    systemctl stop iwd
    systemctl enable --now NetworkManager
    pacman -S ntfs-3g adobe-source-han-serif-cn-fonts wqy-zenhei noto-fonts-cjk noto-fonts-emoji noto-fonts-extra firefox chromium ark packagekit-qt5 packagekit appstream-qt appstream gwenview
    echo -e "$gerrn Do you have Bluetooth? $red (yes/No) $een $een"
    read bor
    if [ $bor == 'yes' ]; then
        systemctl enable --now bluetooth
    fi
}
iiim() {
    echo "[multilib]
 Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
    echo "[archlinuxcn]
 Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch" >> /etc/pacman.conf
    pacman -Syu haveged
    systemctl start haveged
    systemctl enable haveged
    rm -fr /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --populate archlinuxcn
    pacman -S archlinuxcn-keyring                                          #cnԴ�е�ǩ��(archlinuxcn-keyring��archLinuxCn)
    pacman -S yay   
    pacman -S fcitx5-im fcitx5-chinese-addons fcitx5-anthy fcitx5-pinyin-moegirl fcitx5-material-color
    echo "
    GTK_IM_MODULE=fcitx
    QT_IM_MODULE=fcitx
    XMODIFIERS=@im=fcitx
    SDL_IM_MODULE=fcitx
    " >/etc/environment
}
sgpu() {
    echo -e "$green If you have NVIDIA GPU, you can install the driver $red (yes/no) $een $een"
    read sgpuor
    if [ $sgpuor == 'yes' ]; then
        pacman -S nvidia nvidia-settings lib32-nvidia-utils
    fi
}
#C

A1() {
    echo "
        1. Test network.
        2. Change the mirror.
        3. Update the network time.
        4. Install basic Linux System.
        5. Switch to new Chroot system.
        6. Exit.
    "
}
B2() {
    echo "
        1. Set hostname.
        2. Set up the language.
        3. Install the ucode.
        4. Set ROOT User Password.
        5. Install the GRUB Boot Manager.
        6. Reboot.
        7. Exit.
    "
}
C3() {
    echo "
        1. Initialization.
        2. Set non-root users.
        3. Install the KED desktop environment.
        4. Set SWAP.
        5. Install basic software.
        6. Install Chinese input method.
        7. Install NVIDIA driver.
        8. Exit.
    "
}

installe() {
    echo -e "$blue
        A. Install

        B. Arch-chroot Install

        C. Gui Install
    $een"
    echo "Enter options:"
    read opt
    if [ $opt == 'A' ]; then
        while true; do
            clear
            A1
            echo -e "$blue Enter options: $een"
            read oopt
            if [ $oopt == '1' ]; then
                testnet
                pause
            elif [ $oopt == '2' ]; then
                cml
                pause
            elif [ $oopt == '3' ]; then
                timeupdate
                pause
            elif [ $oopt == '4' ]; then
                installlinux
                pause
            elif [ $oopt == '5' ]; then
                swchroot
                pause
            elif [ $oopt == '6' ]; then
                exit
            fi
        done
    elif [ $opt == 'B' ]; then
        while true; do
            clear
            B2
            echo -e "$blue Enter options: $een"
            read oopt
            if [ $oopt == '1' ]; then
                sethn
                pause
            elif [ $oopt == '2' ]; then
                setlang
                pause
            elif [ $oopt == '3' ]; then
                iucode
                pause
            elif [ $oopt == '4' ]; then
                srootp
                pause
            elif [ $oopt == '5' ]; then
                igrub
                pause
            elif [ $oopt == '6' ]; then
                reb
            elif [ $oopt == '7' ]; then
                exit
            fi
        done
    elif [ $opt == 'C' ]; then
        while true; do
            clear
            C3
            echo -e "$blue Enter options: $een"
            read oopt
            if [ $oopt == '1' ]; then
                sdni
                pause
            elif [ $oopt == '2' ]; then
                snnu
                pause
            elif [ $oopt == '3' ]; then
                iked
                pause
            elif [ $oopt == '4' ]; then
                setswap
                pause
            elif [ $oopt == '5' ]; then
                ibf
                pause
            elif [ $oopt == '6' ]; then
                iiim
                pause
            elif [ $oopt == '7' ]; then
                sgpu
                pause
            elif [ $oopt == '8' ]; then
                exit
            fi
        done
    fi
}
wii() {
    while true; do
        installe
    done
}
main() {
    clear
    echo -e "$blue Arch Linux $red shell script Installer $een $een"
    echo -e "$green Is it new installed?

            1. New installer
            
            2. Mounted installer
        
    $een"
    echo -e "$blue Enter your options: $een"
    read oopt
    if [ $oopt == '1' ]; then
        echo -e "$red Are you ready for your disk partition? Minimum 20GB EXT4 partition, 100MB EFI partition $een"
        echo "(yes/no)"
        read sii
        if [ $sii != 'yes' ]; then
            echo -e "$red \nPlease have a hard disk partition\n $een"
            exit
        fi
        clear
        echo "Enter your EFI partition name(example:/dev/sda1)"
        read mfatm
        echo "Enter your ext4 partition name"
        read mextm
        mount $mextm /mnt
        cp ./install.sh /mnt
        mkdir /mnt/home
        mkdir /mnt/efi
        mount $mfatm /mnt/efi
        wii
    elif [ $oopt == '2' ]; then
        wii
    else
	    echo "Enter error!"
	    exit 111
    fi
}
main
