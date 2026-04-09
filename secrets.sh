#!/bin/bash

# 配置：加密后的文件名
ENCRYPTED_FILE=".env.gpg"
DECRYPTED_FILE=".env"

# 加密函数
encrypt() {
    echo "正在加密 $DECRYPTED_FILE..."
    # --symmetric 使用对称加密
    # --batch 减少交互
    # --yes 覆盖已存在的文件
    gpg --symmetric --cipher-algo AES256 --batch --yes --output $ENCRYPTED_FILE $DECRYPTED_FILE
    echo "✅ 加密完成：$ENCRYPTED_FILE"
}

# 解密函数
decrypt() {
    echo "正在解密 $ENCRYPTED_FILE..."
    gpg --decrypt --batch --yes --output $DECRYPTED_FILE $ENCRYPTED_FILE
    echo "✅ 解密完成：$DECRYPTED_FILE"
}

# 根据参数判断操作
case "$1" in
    encrypt)
        encrypt
        ;;
    decrypt)
        decrypt
        ;;
    *)
        echo "使用方法: $0 {encrypt|decrypt}"
        exit 1
esac