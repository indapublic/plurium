#!/usr/bin/env node
// Minimal Chrome DevTools Protocol client for checking the test build.
// Usage: node cdp.mjs <Method> [json-params] [--target <targetId>]
//   node cdp.mjs Target.getTargets
//   node cdp.mjs Runtime.evaluate '{"expression":"document.cookie"}' --target <id>
//   node cdp.mjs Browser.close
// Needs Node 22+ (global WebSocket). Port: CDP_PORT (default 9222).
const port = process.env.CDP_PORT || 9222;
const args = process.argv.slice(2);
const targetIndex = args.indexOf('--target');
const target = targetIndex >= 0 ? args.splice(targetIndex, 2)[1] : null;
const [method, rawParams] = args;
if (!method) {
  console.error('usage: node cdp.mjs <Method> [json-params] [--target <id>]');
  process.exit(2);
}
const params = rawParams ? JSON.parse(rawParams) : {};

const version = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
const ws = new WebSocket(version.webSocketDebuggerUrl);
let nextId = 0;
const pending = new Map();
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    pending.get(message.id)(message);
    pending.delete(message.id);
  }
};
const send = (m, p = {}, sessionId) =>
  new Promise((resolve) => {
    const id = ++nextId;
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method: m, params: p, sessionId }));
  });
await new Promise((resolve, reject) => {
  ws.onopen = resolve;
  ws.onerror = reject;
});

let sessionId;
if (target) {
  const attached = await send('Target.attachToTarget', { targetId: target, flatten: true });
  sessionId = attached.result.sessionId;
}
// Browser.close never answers; don't wait forever.
const reply = await Promise.race([
  send(method, params, sessionId),
  new Promise((resolve) => setTimeout(() => resolve({ result: { timeout: true } }), 5000)),
]);
console.log(JSON.stringify(reply.error ?? reply.result, null, 2));
ws.close();
process.exit(reply.error ? 1 : 0);
