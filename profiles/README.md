# Hardware Node Profiles

PCごとの実行環境、接続経路、導入モデル、推奨context、実測結果を分離管理します。モデルのGGUF、projector、LM Studio実データ、資格情報は保存しません。

- `RTX3090-Remote/`: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`上のLAN接続LM Studio node
- `RX9070XT-Remote/`: `pc7600x / DESKTOP-LMB720F / 192.168.0.103`上のAMD ROCm LAN接続LM Studio node

RTX5090のCurrent model lifecycleは`CURRENT_STATE.md`と`configs/current/`を正とし、Remote Node profileを追加してもCurrent昇格を意味しません。
