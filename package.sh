#!/bin/bash

IN_FILES="squashfs-root"
OUT_FILE="root.squashfs"

if [ ! `command -v mksquashfs` ]; then
    echo "mksquashfs 未安装！请先安装"
    exit 1
fi

if [ ! -z "$1" -a -d "$1" ]; then
    IN_FILES=$1
fi

if [ ! -z "$2" ]; then
    OUT_FILE=$2
fi

if [ -f "$OUT_FILE" ]; then
    rm -rf $OUT_FILE
fi

echo -e "\033[35m 开始打包文件: Pack ${IN_FILES} To ${OUT_FILE} \033[0m"

mksquashfs "$IN_FILES" "$OUT_FILE" -comp xz -all-root
res="$?"

out_size=`ls -l $OUT_FILE |awk '{ print $5}'`
size_limit=33554432

if [ -f "$OUT_FILE" ]; then
    echo "---------------------------------------------------------------------"
    echo
    echo -e "\033[32m 打包成功：文件名：${OUT_FILE} ； 文件大小：${out_size} \033[0m"
    if (( $out_size >= $size_limit )); then
        echo -e "\033[41;33m 生成的文件大小已经超出32M！\033[0m"
        echo -e "\033[41;33m 严禁将该文件刷入系统，否则一定会刷入失败！  \033[0m"
        echo -e "\033[41;33m 刷入失败后该系统将无法启动！ \033[0m"
    fi
    echo
    echo "---------------------------------------------------------------------"
fi


