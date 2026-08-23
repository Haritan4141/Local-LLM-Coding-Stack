# Qwen3.8 HauhauCS Aggressive Q5_K_P Fallback Loaders

Q6_K_PがRTX 5090 32 GBの64K/96Kで実用的なVRAM余裕を確保できなかったため、同じCandidateのVRAM fallbackとしてQ5_K_Pを分離管理します。Q6_K_P用loaderは変更しません。

| Item | Value |
|---|---|
| Role | Candidate fallback / not adopted |
| Quantization | Q5_K_P |
| LM Studio model key | `hauhaucs/qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp-gguf/qwen3.8-27b-uncensored-hauhaucs-aggressive-q5_k_p.gguf` |
| API identifier | `qwen3.8-27b-hauhaucs-aggressive-q5kp` |
| Vision | Supported; shared BF16 mmproj is outside this repository |
| KV cache | Q8_0 / Q8_0 target through the same saved Candidate defaults; LM Studio CLI does not independently echo this value for the Q5_K_P variant |
| MTP | Embedded ON, max draft tokens 2 |
| FastMTP | OFF / not available in stock LM Studio runtime |

| BAT | Context | Use |
|---|---:|---|
| `Qwen3.8-HauhauCS-Q5KP_96K.bat` | 98,304 | Q6_K_Pで不足した96K VRAM余裕のfallback確認 |
| `Qwen3.8-HauhauCS-Q5KP_64K.bat` | 65,536 | VRChat / Unity比較 |
| `Qwen3.8-HauhauCS-Q5KP_32K.bat` | 32,768 | 軽量比較、Vision、Tool Calling確認 |

実測ではQ5_K_Pは32K/64K/96Kをロード・生成できましたが、MTP ONは32K固定fixtureでOFFより約10.5%遅く、Currentへの昇格対象ではありません。これらのBATはCurrentと同じMTP ON条件を再現するためのCandidate評価用です。モデル本体とmmprojをこのリポジトリへ保存しません。
