# RX 9070 XT model loaders

`pc7600x / DESKTOP-LMB720F / 192.168.0.103`を、MAINから利用するAMD LM Studio Remote Nodeとして管理します。

- GPU: AMD Radeon RX 9070 XT 16 GB (`gfx1201`)
- Runtime: LM Studio llama.cpp AMD ROCm 2.29.1
- LAN API: `http://192.168.0.103:1234/v1`
- Loader実行場所: MAIN (`DESKTOP-5NPLIIV`)
- Remote Node lifecycle: `Candidate`。repository-wide Currentは変更しません。

モデルごとに`RX9070XT/<Model-Variant-Quantization>/`を追加します。GGUF、LM Studio data、runtime cacheはこのrepositoryへ保存しません。
