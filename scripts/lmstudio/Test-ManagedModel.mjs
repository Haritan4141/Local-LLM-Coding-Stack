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
  "vision-required",
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
const visionRequired = options.get("vision-required") ?? "off";
const evalBatchSize = options.has("eval-batch") ? Number(options.get("eval-batch")) : null;
const priority = parseIntegerList(options.get("priority"), "priority");
const disabledGpus = parseIntegerList(options.get("disabled"), "disabled");

if (!identifier) throw new Error("--identifier is required.");
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
if (!new Set(["on", "off"]).has(visionRequired)) {
  throw new Error("--vision-required must be on or off.");
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
const loadedModels = await client.llm.listLoaded();
const matches = [];
for (const model of loadedModels) {
  const info = await model.getModelInfo();
  if (info?.identifier !== identifier) continue;
  const loadConfig = await model.getLoadConfig("managed-model-preflight");
  matches.push({ info, fields: new Map(loadConfig.fields.map((field) => [field.key, field.value])) });
}

if (matches.length !== 1) {
  console.error(JSON.stringify({
    valid: false,
    identifier,
    reason: `Expected exactly one loaded instance, found ${matches.length}.`,
  }));
  process.exit(2);
}

const useFp16ForKVCache = kCacheMode === "f16" && vCacheMode === "f16";
const expectedFields = new Map([
  ["llm.load.contextLength", contextLength],
  ["llm.load.llama.flashAttention", true],
  ["llm.load.llama.speculativeDecoding.draftMtp", mtpMode === "on"],
  ["llm.load.llama.speculativeDecoding.draftMaxTokens", mtpDraftTokens],
  ["llm.load.llama.acceleration.offloadRatio", "max"],
  ["llm.load.llama.useFp16ForKVCache", useFp16ForKVCache],
  ["llm.load.llama.kCacheQuantizationType", useFp16ForKVCache ? { checked: false, value: "f16" } : kCacheMode],
  ["llm.load.llama.vCacheQuantizationType", useFp16ForKVCache ? { checked: false, value: "f16" } : vCacheMode],
  ["llm.load.numParallelSessions", 1],
  ["load.gpuStrictVramCap", strictVramCapMode === "on"],
]);
if (mmapMode !== "default") expectedFields.set("llm.load.llama.tryMmap", mmapMode === "on");
if (keepModelMode !== "default") {
  expectedFields.set("llm.load.llama.keepModelInMemory", keepModelMode === "on");
}
if (evalBatchSize !== null) expectedFields.set("llm.load.llama.evalBatchSize", evalBatchSize);
if (options.has("priority")) {
  expectedFields.set("load.gpuSplitConfig", {
    strategy: "priorityOrder",
    disabledGpus,
    priority,
    customRatio: [],
  });
}

const [{ info, fields }] = matches;
const mismatches = [];
for (const [key, expected] of expectedFields) {
  const actual = fields.get(key);
  const normalizedActual =
    actual !== null && typeof actual === "object" && actual.checked === true && Object.hasOwn(actual, "value")
      ? actual.value
      : actual;
  if (JSON.stringify(normalizedActual) !== JSON.stringify(expected)) {
    mismatches.push({ key, expected, actual: actual ?? null });
  }
}
if (visionRequired === "on" && info?.vision !== true) {
  mismatches.push({ key: "modelInfo.vision", expected: true, actual: info?.vision ?? null });
}

const result = {
  valid: mismatches.length === 0,
  identifier,
  contextLength,
  kvCache: `${kCacheMode}/${vCacheMode}`,
  maxParallelPredictions: 1,
  mtp: mtpMode,
  maxDraftTokens: mtpDraftTokens,
  evalBatchSize,
  mmap: mmapMode,
  keepModelInMemory: keepModelMode,
  gpuStrictVramCap: strictVramCapMode,
  gpuSplitConfig: options.has("priority")
    ? { strategy: "priorityOrder", disabledGpus, priority, customRatio: [] }
    : null,
  vision: info?.vision ?? null,
  mismatches,
};

if (!result.valid) {
  console.error(JSON.stringify(result));
  process.exit(3);
}
console.log(JSON.stringify(result));
