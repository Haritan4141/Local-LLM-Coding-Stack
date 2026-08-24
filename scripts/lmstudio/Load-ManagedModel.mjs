import { LMStudioClient } from "@lmstudio/sdk";

const options = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!key?.startsWith("--") || value === undefined) {
    throw new Error(`Invalid argument near: ${key ?? "<end>"}`);
  }
  options.set(key.slice(2), value);
}

const supportedOptions = new Set([
  "model-key",
  "identifier",
  "context",
  "mtp",
  "mtp-draft",
  "kv",
  "kv-k",
  "kv-v",
  "mmap",
  "keep-model-in-memory",
  "strict-vram-cap",
  "eval-batch",
  "priority",
  "disabled",
]);
for (const key of options.keys()) {
  if (!supportedOptions.has(key)) throw new Error(`Unsupported option: --${key}`);
}

const parseIntegerList = (value, name) => {
  if (value === undefined || value === "" || value === "none") return [];
  const result = value.split(",").map((item) => {
    const parsed = Number(item);
    if (!Number.isSafeInteger(parsed) || parsed < 0) {
      throw new Error(`Invalid GPU device id in --${name}: ${item}`);
    }
    return parsed;
  });
  if (new Set(result).size !== result.length) {
    throw new Error(`--${name} contains a duplicate GPU device id.`);
  }
  return result;
};

const modelKey = options.get("model-key");
const identifier = options.get("identifier");
const contextLength = Number(options.get("context"));
const mtpMode = options.get("mtp") ?? "on";
const mtpDraftTokens = options.has("mtp-draft")
  ? Number(options.get("mtp-draft"))
  : 2;
const legacyCacheMode = options.get("kv");
if (legacyCacheMode !== undefined && (options.has("kv-k") || options.has("kv-v"))) {
  throw new Error("--kv cannot be combined with --kv-k or --kv-v.");
}
const kCacheMode = legacyCacheMode ?? options.get("kv-k") ?? "q8_0";
const vCacheMode = legacyCacheMode ?? options.get("kv-v") ?? "q8_0";
const mmapMode = options.get("mmap") ?? "default";
const keepModelMode = options.get("keep-model-in-memory") ?? "default";
const strictVramCapMode = options.get("strict-vram-cap") ?? "off";
const evalBatchSize = options.has("eval-batch")
  ? Number(options.get("eval-batch"))
  : null;
const priority = parseIntegerList(options.get("priority"), "priority");
const disabledGpus = parseIntegerList(options.get("disabled"), "disabled");

if (!modelKey || !identifier) throw new Error("--model-key and --identifier are required.");
if (!Number.isSafeInteger(contextLength) || contextLength < 1024) {
  throw new Error("--context must be an integer of at least 1024 tokens.");
}
if (!new Set(["on", "off"]).has(mtpMode)) throw new Error("--mtp must be on or off.");
if (![2, 3, 4].includes(mtpDraftTokens)) {
  throw new Error("--mtp-draft must be 2, 3, or 4.");
}
const supportedCacheModes = new Set(["q8_0", "q4_0", "f16"]);
if (!supportedCacheModes.has(kCacheMode)) {
  throw new Error("--kv-k must be q8_0, q4_0, or f16.");
}
if (!supportedCacheModes.has(vCacheMode)) {
  throw new Error("--kv-v must be q8_0, q4_0, or f16.");
}
if ((kCacheMode === "f16") !== (vCacheMode === "f16")) {
  throw new Error("Mixed F16 and quantized K/V cache is unsupported by this helper.");
}
if (!new Set(["default", "on", "off"]).has(mmapMode)) {
  throw new Error("--mmap must be default, on, or off.");
}
if (!new Set(["default", "on", "off"]).has(keepModelMode)) {
  throw new Error("--keep-model-in-memory must be default, on, or off.");
}
if (!new Set(["on", "off"]).has(strictVramCapMode)) {
  throw new Error("--strict-vram-cap must be on or off.");
}
if (evalBatchSize !== null && (!Number.isSafeInteger(evalBatchSize) || evalBatchSize < 1)) {
  throw new Error("--eval-batch must be a positive integer.");
}
if (disabledGpus.some((deviceId) => priority.includes(deviceId))) {
  throw new Error("A GPU device id cannot appear in both --priority and --disabled.");
}
if (options.has("priority") && priority.length === 0) {
  throw new Error("--priority must contain at least one GPU device id.");
}
if (!options.has("priority") && options.has("disabled")) {
  throw new Error("--disabled requires --priority.");
}

const client = new LMStudioClient();
const useFp16ForKVCache = kCacheMode === "f16" && vCacheMode === "f16";
const kCacheQuantizationType = useFp16ForKVCache ? false : kCacheMode;
const vCacheQuantizationType = useFp16ForKVCache ? false : vCacheMode;
const gpuStrictVramCap = strictVramCapMode === "on";
const gpuSplitConfig = options.has("priority")
  ? { strategy: "priorityOrder", disabledGpus, priority, customRatio: [] }
  : null;

// SDK 1.5.0 exposes the documented cache, mmap, and offload settings. LM
// Studio's effective per-load config is used for parallel predictions, MTP,
// and the formal priority-order GPU split. Inject only those audited fields so
// device id 0 is not lost by the SDK GPUSetting truthiness conversion.
const convertLoadConfig = client.llm.loadConfigToKVConfig.bind(client.llm);
client.llm.loadConfigToKVConfig = (config) => {
  const kvConfig = convertLoadConfig(config);
  const injectedKeys = new Set([
    "load.gpuStrictVramCap",
    "llm.load.numParallelSessions",
    "llm.load.llama.speculativeDecoding.draftMtp",
    "llm.load.llama.speculativeDecoding.draftMaxTokens",
  ]);
  if (gpuSplitConfig !== null) injectedKeys.add("load.gpuSplitConfig");
  kvConfig.fields = kvConfig.fields.filter((field) => !injectedKeys.has(field.key));
  if (gpuSplitConfig !== null) {
    kvConfig.fields.push({ key: "load.gpuSplitConfig", value: gpuSplitConfig });
  }
  kvConfig.fields.push(
    { key: "load.gpuStrictVramCap", value: gpuStrictVramCap },
    { key: "llm.load.numParallelSessions", value: 1 },
    { key: "llm.load.llama.speculativeDecoding.draftMtp", value: mtpMode === "on" },
    { key: "llm.load.llama.speculativeDecoding.draftMaxTokens", value: mtpDraftTokens },
  );
  return kvConfig;
};

const modelConfig = {
  contextLength,
  gpu: { ratio: "max" },
  maxParallelPredictions: 1,
  flashAttention: true,
  offloadKVCacheToGpu: true,
  useFp16ForKVCache,
  llamaKCacheQuantizationType: kCacheQuantizationType,
  llamaVCacheQuantizationType: vCacheQuantizationType,
  speculativeDraftMtp: mtpMode === "on",
  speculativeDraftMaxTokens: mtpDraftTokens,
  gpuStrictVramCap,
};
if (mmapMode !== "default") modelConfig.tryMmap = mmapMode === "on";
if (keepModelMode !== "default") modelConfig.keepModelInMemory = keepModelMode === "on";
if (evalBatchSize !== null) modelConfig.evalBatchSize = evalBatchSize;

const model = await client.llm.load(modelKey, {
  identifier,
  verbose: true,
  config: modelConfig,
});

const effectiveLoadConfig = await model.getLoadConfig("post-load-audit");
const auditedLoadKeys = new Set([
  "load.gpuSplitConfig",
  "load.gpuStrictVramCap",
  "llm.load.contextLength",
  "llm.load.llama.evalBatchSize",
  "llm.load.llama.flashAttention",
  "llm.load.llama.keepModelInMemory",
  "llm.load.llama.speculativeDecoding.draftMtp",
  "llm.load.llama.speculativeDecoding.draftMaxTokens",
  "llm.load.llama.acceleration.offloadRatio",
  "llm.load.llama.tryMmap",
  "llm.load.llama.useFp16ForKVCache",
  "llm.load.llama.kCacheQuantizationType",
  "llm.load.llama.vCacheQuantizationType",
  "llm.load.numParallelSessions",
]);

console.log(JSON.stringify({
  loaded: true,
  modelKey,
  identifier: model.identifier,
  contextLength,
  kvCache: `${kCacheMode}/${vCacheMode}`,
  maxParallelPredictions: 1,
  mtp: mtpMode,
  maxDraftTokens: mtpDraftTokens,
  evalBatchSize,
  mmap: mmapMode,
  keepModelInMemory: keepModelMode,
  gpuStrictVramCap,
  gpuSplitConfig,
  effectiveLoadConfig: {
    fields: effectiveLoadConfig.fields.filter((field) => auditedLoadKeys.has(field.key)),
  },
}));
