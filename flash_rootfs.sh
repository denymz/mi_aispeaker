#!/bin/sh

klogger(){
	local msg1="$1"
	local msg2="$2"

	if [ "$msg1" = "-n" ]; then
		echo  -n "$msg2" >> /dev/kmsg 2>/dev/null
	else
		echo "$msg1" >> /dev/kmsg 2>/dev/null
	fi

	return 0
}

Upgrade_rootfs() {
    local file_name=$1
	local segment_name=$2
	local dest=$3
	local ret=0

	klogger -n "正在将 $segment_name 刷入到 $dest ..."
	exec 9>&1
	local pipestatus0=`((cat $file_name || echo $? >&8) | \
		mtd write - $dest) 8>&1 >&9`
	if [ -z "$pipestatus0" -a $? -eq 0 ]; then
		ret=0
	else
		ret=1
	fi
	exec 9>&-
	return $ret
}

upfs_squash() {

	local target="root.squashfs"
	local dev="/dev/mtd"$rootfs_mtd_target""

	echo -e "\033[1;41;33m 正在将 $1 刷入到 $dev ... [请勿断电，请勿执行任何操作] \033[0m"

	Upgrade_rootfs $1 $target $dev
	if [ $? -eq 0 ]; then
 		klogger "刷写成功"
 		return 0
	fi
 
	# rootfs upgrade failed. failure
	return 1
}

board_system_upgrade() {
	local filename="$1"
	uboot_mtd=$(grep bootloader /proc/mtd | awk -F: '{print substr($1,4)}')

	kernel0_mtd=$(grep boot0 /proc/mtd | awk -F: '{print substr($1,4)}')
	kernel1_mtd=$(grep boot1 /proc/mtd | awk -F: '{print substr($1,4)}')

	rootfs0_mtd=$(grep system0 /proc/mtd | awk -F: '{print substr($1,4)}')
	rootfs1_mtd=$(grep system1 /proc/mtd | awk -F: '{print substr($1,4)}')

	kernel_mtd_current=`fw_env -g boot_part`
	either="boot0"

	if [ "$kernel_mtd_current" = "boot0" ]; then
		either="boot1"
	fi

    echo
    echo "------------------------------------------------------------------------"
    echo

    reboot_flag=0
    switch_flag=0

	if [ "$2" = "0" ]; then
		#对当前分区进行操作
		echo -ne "\033[33m 对运行中的分区进行操作可能会发生意外，是否继续？ [Y|N](注意大小写，默认为N): \033[0m"
		read answer
		[ $answer != "Y" ] && echo -e "\033[36m 已经取消本次操作 \033[0m" && exit 1
        echo -ne "\033[33m 刷入完成后是否重启？ [Y|N](注意大小写，默认为Y): \033[0m"
		read is_reboot
        [ $is_reboot != "N" ] && echo -e "\033[36m 系统将会在刷入完成后自动重启 \033[0m" && reboot_flag=1
	elif [ "$2" = "1" ]; then
		#对另外一个分区进行操作
		kernel_mtd_current="$either"
        echo -ne "\033[33m 刷入完成后是否切换到另一系统启动？ [Y|N](注意大小写，默认为Y): \033[0m"
		read switch_os
        [ $switch_os != "N" ] && echo -e "\033[36m 系统将会在刷入完成后自动切换系统并重启 \033[0m" && switch_flag=1;
	else
		kernel_mtd_current="other"
	fi

	if [ "$kernel_mtd_current" = "boot1" ]; then
		kernel_mtd_target=$kernel1_mtd
		rootfs_mtd_target=$rootfs1_mtd
		klogger "updating part 1"
	elif [ "$kernel_mtd_current" = "boot0" ]; then
		kernel_mtd_target=$kernel0_mtd
		rootfs_mtd_target=$rootfs0_mtd
		klogger "updating part 0"
	else
		klogger "error boot env: can not find boot_part."
		echo -e "\033[1;41;33m Error：系统里没有这个分区 \033[0m"
		return 1
	fi

    echo -e "\033[33m 请按任意键继续，或者按 Ctrl+C 取消操作本次操作. \033[0m"
	read is_continue

	upfs_squash $filename || return 1

	echo -e "\033[32m -------- 刷入成功 -------- \033[0m"
    echo

    if [ $reboot_flag -eq 1 ]; then
        echo -e "\033[32m 正在重新启动 ... \033[0m"
        reboot -f
    fi

    if [ $switch_flag -eq 1 ]; then
        echo -e "\033[32m 正在切换系统并重新启动 ... \033[0m"
        fw_env -s boot_part ${kernel_mtd_current}
        reboot -f
    fi
	return 0
}


if [ $# -lt 1 ]; then
	echo "Usage: $0 <0:Update runing part> <input file>"
	exit 1
fi

if [ ! -z "$2" -a -f "$2" ]; then
	file=$2
else
	file="/tmp/update/root.squashfs"
fi

if [ ! -f $file ]; then
	echo " $file 文件不存在！"
	exit 1
fi

sync
echo 3 > /proc/sys/vm/drop_caches

board_system_upgrade $file $1
if [ $? -ne 0 ]; then
    error_msg="文件刷入失败"
    [ $1 -eq 0 ] && error_msg="文件刷入失败,正在尝试重启并切换系统，[如果无法正常重启，可以尝试断开电源]"
    echo -e "\033[1;41;33m ${error_msg} \033[0m"
    echo -e "\033[1;41;33m 如果你不知道该如何补救，那么请暂时不要再进行刷机操作，因为如果两个系统都出现问题的话，将无法开机. \033[0m"
    sleep 1
    [ $1 -eq 0 ] && reboot -f
fi