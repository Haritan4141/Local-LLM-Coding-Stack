// Explicit, short MAIN-only acceptance. Never loads/unloads models or edits client config.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawnSync, spawn} from 'node:child_process';
import {auditControlledGooseRead} from './Goose-SmokeTranscript.mjs';
const root=path.resolve(import.meta.dirname,'../..');
const base='http://127.0.0.1:18080';
const alias='qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o';
const stamp=new Date().toISOString().replace(/[:.]/g,'-');
const out=path.join(root,'benchmarks/raw',`main-iq4xs256k-${stamp}`);
fs.mkdirSync(out,{recursive:true});
assert.equal(process.env.COMPUTERNAME,'DESKTOP-5NPLIIV');
const probe=()=> {
  const result=spawnSync('python.exe',['-B',path.join(root,'scripts/standalone-turbo/Read-MainExtendedMemory.py')],{encoding:'utf8',windowsHide:true,timeout:45000});
  assert.equal(result.status,0,'MAIN strict memory gate failed');
  return JSON.parse(result.stdout);
};
const evidence={startedAt:new Date().toISOString(),host:process.env.COMPUTERNAME,endpoint:base,alias,tests:[],memory:[probe()]};
const props=await(await fetch(base+'/props',{signal:AbortSignal.timeout(15000)})).json();
assert.equal(props.model_alias,alias);assert.equal(props.default_generation_settings.n_ctx,262144);assert.equal(props.modalities.vision,true);
fs.writeFileSync(path.join(out,'props.json'),JSON.stringify(props,null,2));
async function chat(name,content,tools) {
  const start=Date.now();
  const body={model:alias,messages:[{role:'system',content:'Follow the short test precisely. Reasoning OFF.'},{role:'user',content}],temperature:0,max_tokens:256,stream:false,...(tools?{tools,tool_choice:'required'}:{})};
  const response=await fetch(base+'/v1/chat/completions',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(180000)});
  assert.equal(response.status,200,`${name} HTTP failed`);
  const result=await response.json();
  fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(result,null,2));
  return {result,elapsedSeconds:(Date.now()-start)/1000};
}
if (process.argv[2] !== 'goose-only') {
const text=await chat('text','Return exactly MAIN_IQ4XS_256K_OK and nothing else.');
assert.equal(text.result.choices[0].message.content.trim(),'MAIN_IQ4XS_256K_OK');
evidence.tests.push({name:'text',pass:true,elapsedSeconds:text.elapsedSeconds,usage:text.result.usage});
const tool=await chat('tool','Call verify_profile with host MAIN and context 262144. No prose.',[{type:'function',function:{name:'verify_profile',description:'Verify controlled test parameters.',parameters:{type:'object',properties:{host:{type:'string'},context:{type:'integer'}},required:['host','context'],additionalProperties:false}}}]);
const calls=tool.result.choices[0].message.tool_calls;
assert.equal(calls.length,1);assert.equal(calls[0].function.name,'verify_profile');assert.deepEqual(JSON.parse(calls[0].function.arguments),{host:'MAIN',context:262144});
evidence.tests.push({name:'tool',pass:true,elapsedSeconds:tool.elapsedSeconds,usage:tool.result.usage});
const image=fs.readFileSync(path.join(process.env.LOCALAPPDATA,'Local-AI-Agent-Stack/dsh-smoke/20261011/probe.png'));
const vision=await chat('vision',[{type:'text',text:'Identify the two large color regions in the image. Reply exactly LEFT=<ENGLISH COLOR> RIGHT=<ENGLISH COLOR>.'},{type:'image_url',image_url:{url:'data:image/png;base64,'+image.toString('base64')}}]);
assert.equal(vision.result.choices[0].message.content.trim().toUpperCase(),'LEFT=GREEN RIGHT=MAGENTA');
evidence.tests.push({name:'vision',pass:true,elapsedSeconds:vision.elapsedSeconds,usage:vision.result.usage});
}
evidence.memory.push(probe());
// Isolated controller-owned working directory; only a nonce file and bounded read.
const nonce='MAIN_GOOSE_PROBE_3B71A9';
fs.writeFileSync(path.join(out,'probe.txt'),nonce);
const goose='C:/Users/Haritan/Applications/goose/v1.52.0/dist-windows/resources/bin/goose.exe';
const gooseHome=path.join(out,'goose-home');
fs.mkdirSync(path.join(gooseHome,'config'),{recursive:true});
fs.writeFileSync(path.join(gooseHome,'config/config.yaml'),'GOOSE_PROVIDER: openai\nGOOSE_MODEL: '+alias+'\nGOOSE_MODE: auto\n');
const isolatedEnv={...process.env};
delete isolatedEnv.GOOSE_ADDITIONAL_CONFIG_FILES;
delete isolatedEnv.GOOSE_SYSTEM_PROMPT_FILE_PATH;
const prompt='Use the developer shell tool exactly once, with command: type probe.txt . Read-only file-content check. Reply exactly the file contents. Do not edit/create files, use Web/delegation, or repeat the command after success.';
const start=Date.now();
const child=spawn(goose,['run','--no-session','--no-profile','--provider','openai','--model',alias,'--with-builtin','developer','--max-turns','4','--max-tool-repetitions','2','--output-format','json','-t',prompt],{
  cwd:out,windowsHide:true,env:{...isolatedEnv,GOOSE_PATH_ROOT:gooseHome,GOOSE_STATE_MACHINE:'false',OPENAI_HOST:base,OPENAI_BASE_PATH:'/v1/chat/completions',OPENAI_API_KEY:'managed-turbo-local-only',GOOSE_CONTEXT_LIMIT:'237568',GOOSE_MAX_TOKENS:'16384',GOOSE_AUTO_COMPACT_THRESHOLD:'0.6',GOOSE_TEMPERATURE:'0',PATH:'C:/Program Files/Git/usr/bin;'+process.env.PATH},stdio:['ignore','pipe','pipe']
});
let stdout='',stderr='';
child.stdout.on('data',c=>stdout+=c.toString());child.stderr.on('data',c=>stderr+=c.toString());
const timer=setTimeout(()=>child.kill(),150000);
const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});
clearTimeout(timer);
fs.writeFileSync(path.join(out,'goose.stdout.json'),stdout);fs.writeFileSync(path.join(out,'goose.stderr.log'),stderr);
assert.equal(code,0,'Goose CLI failed');assert(stdout.includes(nonce),'Goose did not recover file nonce');
const toolAudit=auditControlledGooseRead(stdout,nonce);
evidence.tests.push({name:'goose-controlled-read-only-shell',pass:true,elapsedSeconds:(Date.now()-start)/1000,nonceObserved:true,...toolAudit});
evidence.memory.push(probe());evidence.endedAt=new Date().toISOString();evidence.full256KInputTest='NOT_RUN';evidence.pass=true;
fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(evidence,null,2));
console.log(JSON.stringify({pass:true,artifacts:out,tests:evidence.tests,memory:evidence.memory.map(m=>m.gpus.map(g=>({usedMiB:g.used_mib,freeMiB:g.headroom_mib,sharedGiB:g.shared_bytes/1024**3})))}));
