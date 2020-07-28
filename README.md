# createCertificates
# 証明書作成シェル

## 概要
１．認証局用の証明書を発行 （aes256 で鍵を作成 numbits 2048, x509 で証明）  
２．証明したいドメイン用の証明書を発行  

## 詳細
設定ファイル conf.txt  
関数ファイル function.sh  
createCertificates.sh を配置しているカレントディレクトリ配下に  
認証局用ディレクトリ作成、ドメイン用ディレクトリ作成  
認証局用証明書作成と鍵作成、ドメイン用証明書作成と鍵作成  
 
### input  
conf.txt  
function.sh    


### output  
認証局の秘密鍵  
./$ROOTCA/private/cakey.pem

ルートCA証明書  
./$ROOTCA/private/cakey.pem
   
ドメイン証明書の秘密鍵（サーバ証明書の秘密鍵）  
./$ROOTCA/$DOMAIN/private/privkey.pem  

ドメイン証明書（サーバ証明書）  
./$ROOTCA/$DOMAIN/certs/$DOMAIN.crt.pem  


