#!/bin/bash

# 概要
# １．認証局用の証明書を発行 （aes256 で鍵を作成 numbits 2048, x509 で証明）
# ２．証明したいドメイン用の証明書を発行

# 詳細
# 設定ファイル conf.txt
# createCertificates.sh を配置しているカレントディレクトリ配下に
# 認証局用ディレクトリ作成、ドメイン用ディレクトリ作成
# 認証局用証明書作成と鍵作成、ドメイン用証明書作成と鍵作成
# 
# input 
#   conf.txt
#   function.sh
# 
# output
#   認証局の秘密鍵
#   ./$ROOTCA/private/cakey.pem
#
#   ルートCA証明書
#   ./$ROOTCA/private/cakey.pem
#   
#   ドメイン証明書の秘密鍵（サーバ証明書の秘密鍵）
#   ./$ROOTCA/$DOMAIN/private/privkey.pem
#
#   ドメイン証明書（サーバ証明書）
#   ./$ROOTCA/$DOMAIN/certs/$DOMAIN.crt.pem
#   


# ０．前準備
# functions.sh を読み込み
FUNCTIONSFILE="functions.sh"
if [ -e $FUNCTIONSFILE ]; then
    . ./$FUNCTIONSFILE
else
    echo "File does not exit (functions.sh)"
fi

# 設定ファイルを読み込み
CONFFILE="conf.txt"
if [ -e $CONFFILE ]; then
    . ./$CONFFILE
else
    echo "File does not exit (conf.txt)"
fi

# 設定ファイルの内容を確認
echo "$CONFFILE" -------------------
cat $CONFFILE
echo --------------------------------

read -p "Please check the settings. ok? (y/n): " yn
case "$yn" in
    [yY]|yes|Yes|YES) 
        echo "Continue" 
        ;;
    *) 
        echo "Exit"
        exit 0
        ;;
esac

# 認証局用ディレクトリを作成する 
# ディレクトリがある場合削除するか確認
if [ -e $ROOTCA ]; then
    read -p "Delete $ROOTCA directory create new $ROOTCA directory. ok? (y|n):" yn
    case "$yn" in
        [yY]|yes|Yes|YES) 
            rm -rf $ROOTCA
            createDir 
            ;;
        *)
            echo "Back up the $ROOTCA directory and then execute the script."
            exit
            ;;
    esac
else
    createDir
fi

# openssl.cnf をコピーする
sudo cp /etc/ssl/openssl.cnf $ROOTCA/.

# 認証局のディレクトリを変更する
sudo sed -i -e 's/^dir.*=.\.\/demoCA/dir\t\t\= \.\/rootCA/g' ./$ROOTCA/openssl.cnf 
# Can't load /home/a_user/.rnd into RNG 対応
sudo sed -i -e 's/RANDFILE\t\t= \$ENV::HOME\/\.rnd/# RANDFILE\t\t= \$ENV::HOME\/\.rnd/g' ./$ROOTCA/openssl.cnf

# openssl の存在チェック
OPENSSLCMD=`which openssl`
if [ -z $OPENSSLCMD ]; then
    echo "openssl is not installed. Please install."
    exit 0
fi

# シェル自動実行できるか確認
EXPECTCMD=`which expect`
AUTOMATIC=true
if [ -z "$KEYPASSWORD" ] || [ -z "$EXPECTCMD" ]; then
    AUTOMATIC=false
    echo 
    echo "Run INTERACTIVELY. (No key password or There is no except command!)"
    echo
fi

# １．認証局用の証明書を発行（認証局の作成）
# 認証局用の秘密鍵を作成する(cakey.pem)
echo
echo "Create a private key. (cakey.pem)"
echo
if "${AUTOMATIC}"; then
    expect -c "
    set timeout 5
    spawn env LANG=C \
    $OPENSSLCMD genrsa -aes256 -out ./$ROOTCA/private/cakey.pem 2048
    expect \"Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"Verifying - Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"$\"
    exit 0
    "
else
    $OPENSSLCMD genrsa -aes256 -out ./$ROOTCA/private/cakey.pem 2048
fi

# CSR を作成(cacert.csr)
echo 
echo "Create a CSR. (cacert.csr)"
echo
if "${AUTOMATIC}"; then
    expect -c "
    set timeout 5
    spawn env LANG=C \
        $OPENSSLCMD req \
            -new -key ./$ROOTCA/private/cakey.pem \
            -config ./$ROOTCA/openssl.cnf \
            -subj "/C=$C_NAME/ST=$ST_NAME/L=$L_NAME/O=$O_NAME/OU=$OU_NAME/CN=$CN_NAME/" \
            -out ./rootCA/cacert.csr
    expect \"Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"$\"
    exit 0
    "
else
    $OPENSSLCMD req \
        -new -key ./$ROOTCA/private/cakey.pem \
        -config ./$ROOTCA/openssl.cnf \
        -subj "/C=$C_NAME/ST=$ST_NAME/L=$L_NAME/O=$O_NAME/OU=$OU_NAME/CN=$CN_NAME/" \
        -out ./rootCA/cacert.csr
fi

# ルートCA証明書を自分自身で証明(cacert.pem)
#$ openssl x509 -days 825 -in ./rootCA/cacert.csr -req -signkey ./rootCA/private/cakey.pem -out ./rootCA/cacert.pem
echo
echo "Create a Root CA certificate. (cacert.pem)"
echo
if "${AUTOMATIC}"; then
    expect -c "
    set timeout 5
    spawn env LANG=C \
    $OPENSSLCMD x509 \
        -days $EXPIRATIONDATE \
        -in ./$ROOTCA/cacert.csr \
        -req -signkey ./$ROOTCA/private/cakey.pem \
        -out ./$ROOTCA/cacert.pem
    expect \"Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"$\"
    exit 0
    "
else
$OPENSSLCMD x509 \
    -days $EXPIRATIONDATE \
    -in ./$ROOTCA/cacert.csr \
    -req -signkey ./$ROOTCA/private/cakey.pem \
    -out ./$ROOTCA/cacert.pem
fi

# 認証局で鍵を管理するために必要なファイルを作成
touch $ROOTCA/index.txt
touch $ROOTCA/index.txt.attr
echo 00 > ./rootCA/serial

echo
echo Compleate Certificate Authority!
echo

# ２．証明したいドメインの証明書を発行（サーバ証明書作成）
# 秘密鍵を作成
echo
echo "Create a Domain private key. (privkey.pem)"
echo
if "${AUTOMATIC}"; then
    expect -c "
    set timeout 5
    spawn env LANG=C \
    $OPENSSLCMD genrsa -aes256 -out ./$ROOTCA/$DOMAIN/private/privkey.pem 2048
    expect \"Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"Verifying - Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"$\"
    exit 0
    "
else
    $OPENSSLCMD genrsa \
        -aes256 -out ./$ROOTCA/$DOMAIN/private/privkey.pem 2048
fi

# CSRを作成（$DOMAIN.csr)
echo
echo "Create a $DOMAIN CSR. ($DOMAIN.csr)"
echo
if "${AUTOMATIC}"; then
    expect -c "
    set timeout 5
    spawn env LANG=C \
    $OPENSSLCMD req \
        -config ./$ROOTCA/openssl.cnf \
        -new -key ./$ROOTCA/$DOMAIN/private/privkey.pem \
        -subj "/C=$C_NAME/ST=$ST_NAME/L=$L_NAME/O=$O_NAME/OU=$OU_NAME/CN=$CN_NAME/" \
        -out ./$ROOTCA/$DOMAIN/certs/$DOMAIN.csr
    expect \"Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"$\"
    exit 0
    "
else
    $OPENSSLCMD req \
        -config ./$ROOTCA/openssl.cnf \
        -new -key ./$ROOTCA/$DOMAIN/private/privkey.pem \
        -subj "/C=$C_NAME/ST=$ST_NAME/L=$L_NAME/O=$O_NAME/OU=$OU_NAME/CN=$CN_NAME/" \
        -out ./$ROOTCA/$DOMAIN/certs/$DOMAIN.csr
fi

# ドメインの証明書を発行
echo
echo "Create a $DOMAIN Certificate"
echo
if "${AUTOMATIC}"; then
    expect -c "
    set timeout 5
    spawn env LANG=C \
     $OPENSSLCMD ca \
        -config ./$ROOTCA/openssl.cnf \
        -keyfile ./$ROOTCA/private/cakey.pem \
        -cert ./$ROOTCA/cacert.pem \
        -in ./$ROOTCA/$DOMAIN/certs/$DOMAIN.csr \
        -out ./$ROOTCA/$DOMAIN/certs/$DOMAIN.crt.pem \
        -days $EXPIRATIONDATE \
        -outdir ./$ROOTCA/newcerts \
        -extensions SAN \
        -extfile ./$CONFFILE
    expect \"Enter pass phrase for\"
    send \"${KEYPASSWORD}\n\"
    expect \"Sign the certificate\"
    send \"y\n\"
    expect \"1 out of 1 certificate requests certified, commit\"
    send \"y\n\"
    expect \"$\"
    exit 0
    "
else
    $OPENSSLCMD ca \
    -config ./$ROOTCA/openssl.cnf \
    -keyfile ./$ROOTCA/private/cakey.pem \
    -cert ./$ROOTCA/cacert.pem \
    -in ./$ROOTCA/$DOMAIN/certs/$DOMAIN.csr \
    -out ./$ROOTCA/$DOMAIN/certs/$DOMAIN.crt.pem \
    -days $EXPIRATIONDATE \
    -outdir ./$ROOTCA/newcerts \
    -extensions SAN \
    -extfile ./$CONFFILE

    # $OPENSSLCMD ca \
    # -config ./$ROOTCA/openssl.cnf \
    # -keyfile ./$ROOTCA/private/cakey.pem \
    # -cert ./$ROOTCA/cacert.pem \
    # -in ./$ROOTCA/$DOMAIN/certs/$DOMAIN.csr \
    # -out ./$ROOTCA/$DOMAIN/certs/$DOMAIN.crt.pem \
    # -days $EXPIRATIONDATE \
    # -outdir ./$ROOTCA/newcerts \
    # -extensions SAN \
    # -extfile <(printf "
    #     [SAN]
    #     subjectAltName=@alt_names
    #     basicConstraints=CA:FALSE
    #     [alt_names]
    #     DNS.1=$DOMAIN
    #     DNS.2=*.$DOMAIN
    # ")
fi