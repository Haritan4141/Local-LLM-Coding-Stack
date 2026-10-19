import assert from 'node:assert/strict';
export function auditControlledGooseRead(stdout, nonce) {
  const start=stdout.search(/^\{\s*"messages":/m);
  assert(start>=0,'Missing Goose JSON transcript');
  const transcript=JSON.parse(stdout.slice(start));
  const content=transcript.messages.flatMap(r=>r.content??[]);
  const calls=content.filter(r=>r.type==='toolRequest');
  const responses=content.filter(r=>r.type==='toolResponse');
  assert.equal(calls.length,1); assert.equal(responses.length,1);
  assert.equal(calls[0].toolCall.value.name,'shell');
  assert.equal(calls[0].toolCall.value.arguments.command.trim(),'type probe.txt');
  assert.equal(responses[0].toolResult.status,'success');
  const final=transcript.messages.findLast(r=>r.role==='assistant').content.filter(r=>r.type==='text').map(r=>r.text).join('');
  assert.equal(final.trim(),nonce);
  return {toolRequests:1,toolResponses:1,function:'shell',command:'type probe.txt'};
}
