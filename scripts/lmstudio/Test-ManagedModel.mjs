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

const identifier = options.get("identifier");
const contextLength = Number(options.get("context"));
const mtpMode = options.get("mtp") ?? "on";

if (!identifier) {
  throw new Error("--identifier is required.");
}
if (!Number.isSafeInteger(contextLength) || contextLength < 1024) {
  throw new Error("--context must be an integer of at least 1024 tokens.");
}
if (!new Set(["on", "off"]).has(mtpMode)) {
  throw new Error("--mtp must be on or off.");
}

const client = new LMStudioClient();
const loadedModels = await client.llm.listLoaded();
const matches = [];

for (const model of loadedModels) {
  const info = await model.getModelInfo();
  if (info?.identifier !== identifier) {
    continue;
  }

  const loadConfig = await model.getLoadConfig("managed-model-preflight");
  matches.push({
    info,
    fields: new Map(loadConfig.fields.map((field) => [field.key, field.value])),
  });
}

if (matches.length !== 1) {
  console.error(JSON.stringify({
    valid: false,
    identifier,
    reason: `Expected exactly one loaded instance, found ${matches.length}.`,
  }));
  process.exit(2);
}

const expectedFields = new Map([
  ["llm.load.contextLength", contextLength],
  ["llm.load.llama.flashAttention", true],
  ["llm.load.llama.speculativeDecoding.draftMtp", mtpMode === "on"],
  ["llm.load.llama.speculativeDecoding.draftMaxTokens", 2],
  ["llm.load.llama.acceleration.offloadRatio", "max"],
  ["llm.load.llama.useFp16ForKVCache", false],
  ["llm.load.llama.kCacheQuantizationType", "q8_0"],
  ["llm.load.llama.vCacheQuantizationType", "q8_0"],
  ["llm.load.numParallelSessions", 1],
]);

const [{ fields }] = matches;
const mismatches = [];
for (const [key, expected] of expectedFields) {
  const actual = fields.get(key);
  const normalizedActual =
    actual !== null &&
    typeof actual === "object" &&
    actual.checked === true &&
    Object.hasOwn(actual, "value")
      ? actual.value
      : actual;
  if (normalizedActual !== expected) {
    mismatches.push({ key, expected, actual: actual ?? null });
  }
}

const result = {
  valid: mismatches.length === 0,
  identifier,
  contextLength,
  kvCache: "q8_0/q8_0",
  maxParallelPredictions: 1,
  mtp: mtpMode,
  maxDraftTokens: 2,
  mismatches,
};

if (!result.valid) {
  console.error(JSON.stringify(result));
  process.exit(3);
}

console.log(JSON.stringify(result));
