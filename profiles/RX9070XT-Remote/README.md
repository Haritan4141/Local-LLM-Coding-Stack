# RED RX 9070 XT Remote LLM Node

家庭内PC名はGREENです。REDは本projectの旧labelであり、既存API IDの`-red`を含め識別子は変更しません。2026-10-19にhostname / IPv4とLM Studio processを確認しましたが、port1234は待受なし、loaded stateは`UNVERIFIED`です。以下の設定・測定値は2026-08の確認記録です。[現在状態](../../CURRENT_STATE.md)を参照してください。

MAINのGoose、Zoo Code、Kilo Code等から家庭内LAN経由で利用するAMD LM Studio nodeです。RTX5090 localhost CurrentおよびBLUE nodeとは別のBase URLとAPI identifierを使用します。

| Item | Value |
|---|---|
| COMPUTERNAME | `DESKTOP-LMB720F` |
| SSH Alias / IP | `pc7600x` / `192.168.0.103` |
| GPU | AMD Radeon RX 9070 XT 16 GB / `gfx1201` |
| RAM | 63.09 GiB |
| LM Studio | 0.4.21+2 |
| Runtime | AMD ROCm 2.29.1; Vulkan 2.29.1 retained as fallback |
| LAN URL | `http://192.168.0.103:1234` |

## Recommended Candidate

- JonathanColetti Qwen3.8 27B Uncensored `IQ4_XS`
- API ID `qwen3.8-27b-uncensored-iq4xs-red`
- 98,304 context、Q4_0/Q4_0 KV、Flash Attention、MTP draft 2、eval batch 512、parallel 1
- RX 9070 XTだけを有効化し、iGPUをper-load device IDで無効化
- Visionなし

96Kは70,082-token入力と3/3回収を完走しました。短文codingはMTP2で36.71–36.82 tok/s、MTP OFFは29.61–29.72 tok/sです。生成中peakはDedicated 14.845 GiB、Shared 3.570 GiBであり、完全VRAM内profileではありません。64GB RAMのRemote NodeとしてはPASSですが、ゲーム等の重いGPU workloadとの同時利用は避けます。64K fallbackはShared 2.604 GiBです。

Firewallは`Local-LLM-LMStudio-RX9070XT-In-TCP-1234-Private-LocalSubnet`で、TCP 1234 / Private / LocalSubnet / Edge Block / LM Studio executableに限定しました。変更前backupはnode.jsonに記録しています。

GooseのCustom Providerは`custom_lm_studio_rx9070xt_remote`です。既定のRTX5090 localhost providerは変更していません。Desktop起動中に追加したため、model switcherへ反映するにはGoose Desktopを一度完全終了して再起動します。

Loaderは`scripts/lmstudio/model-loaders/RX9070XT/Qwen3.8-JonathanColetti-IQ4XS/`にあります。GGUFとLM Studio dataはrepository外です。
