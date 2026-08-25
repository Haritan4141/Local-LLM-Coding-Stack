# JonathanColetti Qwen3.8 IQ4_XS — RX 9070 XT Remote

| Item | Value |
|---|---|
| Model | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Artifact | `Qwen3.8-27B-Uncensored-IQ4_XS.gguf` |
| Size | 15,309,039,008 bytes |
| API identifier | `qwen3.8-27b-uncensored-iq4xs-red` |
| Backend | AMD ROCm 2.29.1 / RX 9070 XT only; iGPU disabled |
| Context | 96K Recommended Candidate / 64K Lower-memory fallback |
| KV cache | Q4_0 / Q4_0, GPU offload ON |
| MTP | ON / draft 2 |
| Other | Flash Attention ON, eval batch 512, mmap ON, strict VRAM cap ON, parallel 1 |
| Vision | OFF; projector is not installed for this node |

`Qwen3.8-JonathanColetti-IQ4XS_96K_REMOTE.bat`をMAINで実行すると、SSH Alias、hostname、IPv4、ROCm runtime、RX 9070 XT、Firewall、model artifact、active predictionを確認してからRED nodeをロードします。64K BATは96Kで問題がある場合のfallbackです。どちらもMAINのLM Studio Currentを変更しません。

96K実測では70,082-token入力と3点回収が成功しました。短いcoding fixtureは36.71–36.82 tok/s、MTP OFFは29.61–29.72 tok/sでした。96K生成中のWDDM peakはDedicated 14.845 GiB / Shared 3.570 GiBです。Sharedを使うため、同PCで重いGPUアプリを併用しない前提のRemote Node profileです。

GooseではCustom Provider `LM Studio RX 9070 XT Remote`を選びます。Base URLは`http://192.168.0.103:1234/v1/chat/completions`です。Global defaultはRTX5090 localhostのまま維持します。

GGUF、LM Studio本体データ、runtime cacheはrepository外のLM Studio管理領域に置きます。
