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

const modelKey = options.get("model-key");
const identifier = options.get("identifier");
const contextLength = Number(options.get("context"));
const mtpMode = options.get("mtp") ?? "on";

if (!modelKey || !identifier) {
  throw new Error("--model-key and --identifier are required.");
}
if (!Number.isSafeInteger(contextLength) || contextLength < 1024) {
  throw new Error("--context must be an integer of at least 1024 tokens.");
}
if (!new Set(["on", "off"]).has(mtpMode)) {
  throw new Error("--mtp must be on or off.");
}

const client = new LMStudioClient();

// SDK 1.5.0 exposes K/V cache quantization, while the bundled LMS CLI exposes
// max parallel predictions. LM Studio's load config key is obtained from the
// effective config emitted by `lms load --parallel 1`. Inject that one field so
// both settings are applied to the same model instance. Verify with `lms ps`
// and getLoadConfig after every managed load.
const convertLoadConfig = client.llm.loadConfigToKVConfig.bind(client.llm);
client.llm.loadConfigToKVConfig = (config) => {
  const kvConfig = convertLoadConfig(config);
  kvConfig.fields = kvConfig.fields.filter((field) => !new Set([
    "llm.load.numParallelSessions",
    "llm.load.llama.speculativeDecoding.draftMtp",
  ]).has(field.key));
  kvConfig.fields.push(
    { key: "llm.load.numParallelSessions", value: 1 },
    {
      key: "llm.load.llama.speculativeDecoding.draftMtp",
      value: mtpMode === "on",
    },
  );
  return kvConfig;
};

const model = await client.llm.load(modelKey, {
  identifier,
  verbose: true,
  config: {
    contextLength,
    gpu: { ratio: "max" },
    maxParallelPredictions: 1,
    flashAttention: true,
    offloadKVCacheToGpu: true,
    useFp16ForKVCache: false,
    llamaKCacheQuantizationType: "q8_0",
    llamaVCacheQuantizationType: "q8_0",
    speculativeDraftMtp: mtpMode === "on",
    speculativeDraftMaxTokens: 2,
  },
});

const effectiveLoadConfig = await model.getLoadConfig("post-load-audit");
const auditedLoadKeys = new Set([
  "llm.load.contextLength",
  "llm.load.llama.flashAttention",
  "llm.load.llama.speculativeDecoding.draftMtp",
  "llm.load.llama.speculativeDecoding.draftMaxTokens",
  "llm.load.llama.acceleration.offloadRatio",
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
  kvCache: "q8_0/q8_0",
  maxParallelPredictions: 1,
  mtp: mtpMode,
  maxDraftTokens: 2,
  effectiveLoadConfig: {
    fields: effectiveLoadConfig.fields.filter((field) => auditedLoadKeys.has(field.key)),
  },
}));
