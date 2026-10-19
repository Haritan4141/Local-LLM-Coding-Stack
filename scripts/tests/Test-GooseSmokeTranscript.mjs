import assert from 'node:assert/strict';
import {auditControlledGooseRead} from '../qualification/Goose-SmokeTranscript.mjs';
const nonce='CONTROLLER_NONCE';
const fixture={messages:[
  {role:'assistant',content:[{type:'toolRequest',toolCall:{value:{name:'shell',arguments:{command:'type probe.txt'}}}}]},
  {role:'user',content:[{type:'toolResponse',toolResult:{status:'success'}}]},
  {role:'assistant',content:[{type:'text',text:nonce}]}
]};
const encode=value=>'Goose startup banner\r\n'+JSON.stringify(value,null,2);
assert.equal(auditControlledGooseRead(encode(fixture),nonce).toolRequests,1);
for(const mutate of [
  f=>f.messages[0].content[0].toolCall.value.name='text_editor',
  f=>f.messages[0].content[0].toolCall.value.arguments.command='echo fake',
  f=>f.messages[1].content[0].toolResult.status='error',
  f=>f.messages.push(f.messages[0]),
  f=>f.messages[2].content[0].text='wrong',
  f=>f.messages.shift()
]) {
  const bad=structuredClone(fixture);mutate(bad);
  assert.throws(()=>auditControlledGooseRead(encode(bad),nonce));
}
assert.throws(()=>auditControlledGooseRead('not JSON',nonce));
console.log('Goose smoke transcript tests: 8 passed');
