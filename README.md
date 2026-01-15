# Snipe-ITの使い方
## 環境
Ubuntu Server(Proxmox VEのVM推奨)

## 必要なパッケージ
Docker Composeが使用できる環境
cifs-utils
rsync

## 共有ファイルサーバーへバックアップするための資格情報ファイル
```
sudo nano /root/.smbcredentials
```
内容
```
username=user
password=password
domain=WORKGROUP
```
```
sudo chmod 600 /root/.smbcredentials
```

## サービス開始方法
bash ./scripts/startup.sh
