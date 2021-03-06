#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear
#Current folder
cur_dir=`pwd`

# Make sure only root can run our script
rootness(){
echo "***************************************************"
echo " *                 rootness()                      *"
echo "***************************************************"
    if [[ $EUID -ne 0 ]]; then
        echo "Error:This script must be run as root!" 1>&2
        exit 1
    fi
}

# Disable selinux
disable_selinux(){
echo "***************************************************"
echo "*                 disable_selinux()               *"
echo "***************************************************"
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

#Check system
check_sys(){
echo "***************************************************"
echo "*                 check_sys()                     *"
echo "***************************************************"
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
echo "***************************************************"
echo "*                getversion()                     *"
echo "***************************************************"
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
echo "***************************************************"
echo "*                centosversion()                  *"
echo "***************************************************"
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Get public IP address
get_ip(){
echo "***************************************************"
echo "*                get_ip()                         *"
echo "***************************************************"
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_char(){

    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# Pre-installation settings
pre_install(){
echo "***************************************************"
echo "*                pre_install()                    *"
echo "***************************************************"
    if check_sys packageManager yum || check_sys packageManager apt; then
        # Not support CentOS 5
        if centosversion 5; then
            echo "Error: Not supported CentOS 5, please change to CentOS 6+/Debian 7+/Ubuntu 12+ and try again."
            exit 1
        fi
    else
        echo "Error: Your OS is not supported. please change OS to CentOS/Debian/Ubuntu and try again."
        exit 1
    fi
    # Set shadowsocks config password
    echo "Please input password for shadowsocks-python:"
    shadowsockspwd="w164053616"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo
    # Set shadowsocks config port
    
    echo -e "Please input port for shadowsocks-python [1-65535]:"
    shadowsocksport="443"
    expr ${shadowsocksport} + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ]; then
            echo
            echo "---------------------------"
            echo "port = ${shadowsocksport}"
            echo "---------------------------"
            echo
            break
        else
            echo "Input error, please input correct number"
        fi
    else
        echo "Input error, please input correct number"
    fi

    echo
    echo "Press any key to start...or Press Ctrl+C to cancel"
   
    #Install necessary dependencies
    if check_sys packageManager yum; then
        yum install -y unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel
    elif check_sys packageManager apt; then
        apt-get -y update
        apt-get -y install python python-dev python-pip python-setuptools python-m2crypto curl wget unzip gcc swig automake make perl cpio build-essential
    fi
    cd ${cur_dir}
}

# Download files
download_files(){
echo "***************************************************"
echo "*                download_files()                 *"
echo "***************************************************"
    # Download libsodium file
    if ! wget --no-check-certificate -O libsodium-1.0.11.tar.gz https://github.com/jedisct1/libsodium/releases/download/1.0.11/libsodium-1.0.11.tar.gz; then
        echo "Failed to download libsodium-1.0.11.tar.gz!"
        exit 1
    fi
    # Download Shadowsocks file
    if ! wget --no-check-certificate -O shadowsocks-master.zip https://github.com/shadowsocks/shadowsocks/archive/master.zip; then
        echo "Failed to download shadowsocks python file!"
        exit 1
    fi
    # Download Shadowsocks init script
    if check_sys packageManager yum; then
        if ! wget --no-check-certificate https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks -O /etc/init.d/shadowsocks; then
            echo "Failed to download shadowsocks chkconfig file!"
            exit 1
        fi
    elif check_sys packageManager apt; then
        if ! wget --no-check-certificate https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-debian -O /etc/init.d/shadowsocks; then
            echo "Failed to download shadowsocks chkconfig file!"
            exit 1
        fi
    fi
}

# Config shadowsocks
config_shadowsocks(){
echo "***************************************************"
echo "*                config_shadowsocks()             *"
echo "***************************************************"
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open":false
}
EOF
}

# Firewall set
firewall_set(){
echo "***************************************************"
echo "*               firewall_set()                    *"
echo "***************************************************"
    echo "firewall set start..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "port ${shadowsocksport} has been set up."
            fi
        else
            echo "WARNING: iptables looks like shutdown or not installed, please manually set it if necessary."
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo "Firewalld looks like not running, try to start..."
            systemctl start firewalld
            if [ $? -eq 0 ]; then
                firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
                firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
                firewall-cmd --reload
            else
                echo "WARNING: Try to start firewalld failed. please enable port ${shadowsocksport} manually if necessary."
            fi
        fi
    fi
    echo "firewall set completed..."
}

# Install Shadowsocks
install(){
echo "***************************************************"
echo "*              install()                          *"
echo "***************************************************"
    # Install libsodium
    tar zxf libsodium-1.0.11.tar.gz
    cd libsodium-1.0.11
    ./configure && make && make install
    if [ $? -ne 0 ]; then
        echo "libsodium install failed!"
        install_cleanup
        exit 1
    fi
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf
    ldconfig
    # Install Shadowsocks
    cd ${cur_dir}
    unzip -q shadowsocks-master.zip
    if [ $? -ne 0 ];then
        echo "unzip shadowsocks-master.zip failed! please check unzip command."
        install_cleanup
        exit 1
    fi

    cd ${cur_dir}/shadowsocks-master
    python setup.py install --record /usr/local/shadowsocks_install.log

    if [ -f /usr/bin/ssserver ] || [ -f /usr/local/bin/ssserver ]; then
        chmod +x /etc/init.d/shadowsocks
        if check_sys packageManager yum; then
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks defaults
        fi
        /etc/init.d/shadowsocks start
    else
        echo
        echo "Shadowsocks install failed! please visit https://teddysun.com/342.html and contact."
        install_cleanup
        exit 1
    fi

    clear
    echo
    echo "Congratulations, shadowsocks server install completed!"
    echo -e "Your Server IP: \033[41;37m $(get_ip) \033[0m"
    echo -e "Your Server Port: \033[41;37m ${shadowsocksport} \033[0m"
    echo -e "Your Password: \033[41;37m ${shadowsockspwd} \033[0m"
    echo -e "Your Local IP: \033[41;37m 127.0.0.1 \033[0m"
    echo -e "Your Local Port: \033[41;37m 1080 \033[0m"
    echo -e "Your Encryption Method: \033[41;37m aes-256-cfb \033[0m"
    echo
    echo "Welcome to visit:https://teddysun.com/342.html"
    echo "Enjoy it!"
    echo
}

# Install cleanup
install_cleanup(){
echo "***************************************************"
echo "*              install_cleanup()                  *"
echo "***************************************************"
    cd ${cur_dir}
    rm -rf shadowsocks-master.zip shadowsocks-master libsodium-1.0.11.tar.gz libsodium-1.0.11
}

# Uninstall Shadowsocks
uninstall_shadowsocks(){
    printf "Are you sure uninstall Shadowsocks? (y/n) "
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        ps -ef | grep -v grep | grep -i "ssserver" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        if check_sys packageManager yum; then
            chkconfig --del shadowsocks
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks remove
        fi
        # delete config file
        rm -f /etc/shadowsocks.json
        rm -f /var/run/shadowsocks.pid
        rm -f /etc/init.d/shadowsocks
        rm -f /var/log/shadowsocks.log
        if [ -f /usr/local/shadowsocks_install.log ]; then
            cat /usr/local/shadowsocks_install.log | xargs rm -rf
        fi
        echo "Shadowsocks uninstall success!"
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}

# Install Shadowsocks-python
install_shadowsocks(){
echo "***************************************************"
echo "*              install_shadowsocks()               *"
echo "***************************************************"
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    if check_sys packageManager yum; then
        firewall_set
    fi
    install
    install_cleanup
}

# Initialization step
start_instal_time=$(date +%s)
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_shadowsocks
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [install|uninstall]"
    ;;
esac



red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1

[[ -d "/proc/vz" ]] && echo -e "${red}Error:${plain} Your VPS is based on OpenVZ, not be supported." && exit 1

if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi

get_latest_version() {
echo "***************************************************"
echo "*              get_latest_version()              *"
echo "***************************************************"
    latest_version=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[4-9]./{print $2}' | cut -d/ -f1 | grep -v -  | sort -V | tail -1)

    [ -z ${latest_version} ] && return 1

    if [[ `getconf WORD_BIT` == "32" && `getconf LONG_BIT` == "64" ]]; then
        deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
        deb_kernel_name="linux-image-${latest_version}-amd64.deb"
    else
        deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
        deb_kernel_name="linux-image-${latest_version}-i386.deb"
    fi

    [ ! -z ${deb_name} ] && return 0 || return 1
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

opsy=$( get_opsy )
arch=$( uname -m )
lbit=$( getconf LONG_BIT )
kern=$( uname -r )

get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

getversion() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion() {
    if [ "${release}" == "centos" ]; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

check_bbr_status() {
echo "***************************************************"
echo "*              check_bbr_status()                *"
echo "***************************************************"
    local param=$(sysctl net.ipv4.tcp_available_congestion_control | awk '{print $3}')
    if uname -r | grep -Eqi "4.10."; then
        if [[ "${param}" == "bbr" ]]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

install_elrepo() {
echo "***************************************************"
echo "*             install_elrepo()                    *"
echo "***************************************************"
    if centosversion 5; then
        echo -e "${red}Error:${plain} not supported CentOS 5."
        exit 1
    fi

    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

    if centosversion 6; then
        rpm -Uvh http://www.elrepo.org/elrepo-release-6-6.el6.elrepo.noarch.rpm
    elif centosversion 7; then
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
    fi

    if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
        echo -e "${red}Error:${plain} Install elrepo failed, please check it."
        exit 1
    fi
}

install_config() {
echo "***************************************************"
echo "*             install_config()                    *"
echo "***************************************************"
    if [[ "${release}" == "centos" ]]; then
        if centosversion 6; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "${red}Error:${plain} /boot/grub/grub.conf not found, please check it."
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif centosversion 7; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "${red}Error:${plain} /boot/grub2/grub.cfg not found, please check it."
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        /usr/sbin/update-grub
    fi

    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

install_bbr() {
echo "***************************************************"
echo "*             install_bbr()                       *"
echo "***************************************************"
    check_bbr_status
    if [ $? -eq 0 ]; then
        echo
        echo -e "${green}Info:${plain} TCP BBR has been successfully installed. nothing to do..."
        exit
    fi

    if [[ "${release}" == "centos" ]]; then
        install_elrepo
        yum --enablerepo=elrepo-kernel -y install kernel-ml kernel-ml-devel
        if [ $? -ne 0 ]; then
            echo -e "${red}Error:${plain} Install latest kernel failed, please check it."
            exit 1
        fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        [[ ! -e "/usr/bin/wget" ]] && apt-get -y update && apt-get -y install wget
        get_latest_version
        [ $? -ne 0 ] && echo -e "${red}Error:${plain} Get latest kernel version failed." && exit 1
        wget -c -t3 -T60 -O ${deb_kernel_name} ${deb_kernel_url}
        if [ $? -ne 0 ]; then
            echo -e "${red}Error:${plain} Download ${deb_kernel_name} failed, please check it."
            exit 1
        fi
        dpkg -i ${deb_kernel_name}
        rm -fv ${deb_kernel_name}
    else
        echo -e "${red}Error:${plain} OS is not be supported, please change to CentOS/Debian/Ubuntu and try again."
        exit 1
    fi

    install_config
}

echo " Auto install latest kernel for TCP BBR"

install_bbr
end_install_time=$(date +%s)
echo "install cost time"
echo $(( end_install_time-start_install_time ))
cp /tmp/firstboot.log  /root
reboot