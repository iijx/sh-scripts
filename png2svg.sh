#!/bin/bash

# 检查用户是否输入了足够的文件名参数
if [ "$#" -ne 2 ]; then
    echo "用法: ./png2svg.sh <输入文件.png> <输出文件.svg>"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_FILE=$2
TEMP_FILE="temp_$$.bmp" # 使用进程ID生成唯一临时文件名，防止冲突

echo "正在转换: $INPUT_FILE -> $OUTPUT_FILE ..."

# 执行转换
magick "$INPUT_FILE" -alpha remove -threshold 50% "$TEMP_FILE"
potrace "$TEMP_FILE" -s -o "$OUTPUT_FILE"

# 清理临时文件
rm "$TEMP_FILE"

echo "转换成功！"
