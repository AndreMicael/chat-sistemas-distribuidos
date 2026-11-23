// Carga curta do protótipo: Node.js 22+, sem pacotes npm.
// O script mede o resultado desta execução; não estima capacidade em milhões.
const base = process.env.TARGET_URL || "http://localhost:4000";
const clients = Number(process.env.CLIENTS || 15);
const rounds = Number(process.env.MESSAGES || 20);
const room = process.env.ROOM_ID || "geral";
const key = process.env.ROOM_KEY || null;
if (!Number.isInteger(clients) || clients < 1 || clients > 1000 || !Number.isInteger(rounds) || rounds < 1 || rounds > 100000) throw Error("CLIENTS: 1..1000; MESSAGES: 1..100000.");
const endpoint = new URL("/socket/websocket?vsn=2.0.0", base);
endpoint.protocol = endpoint.protocol === "https:" ? "wss:" : "ws:";
const sockets = [];
const run = `carga-${Date.now()}-`;
const expected = clients * rounds;
let received = 0;
let duplicated = 0;
let heartbeat;
const deliveries = [];
const pending = new Map();
let ref = 1;
function waitFor(fn, ms = 30000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    const timer = setInterval(() => {
      if (fn()) { clearInterval(timer); resolve(); }
      else if (Date.now() - start > ms) { clearInterval(timer); reject(Error("Tempo esgotado aguardando entregas.")); }
    }, 25);
  });
}
function push(ws, index, event, payload, topic = `room:${room}`, joinRef = "1") {
  return new Promise((resolve, reject) => {
    const id = String(ref++);
    const timer = setTimeout(() => {pending.delete(`${index}:${id}`); reject(Error(`Sem confirmação: cliente ${index}, evento ${event}`));}, 15000);
    pending.set(`${index}:${id}`, {resolve, reject, timer});
    ws.send(JSON.stringify([joinRef, id, topic, event, payload]));
  });
}
const started = performance.now();
try {
  await Promise.all(Array.from({length: clients}, (_, index) => new Promise((resolve, reject) => {
    const ws = new WebSocket(endpoint);
    sockets.push(ws);
    const ids = new Set();
    deliveries[index] = ids;
    ws.addEventListener("error", () => reject(Error(`Falha de conexão do cliente ${index}`)));
    ws.addEventListener("message", ({data}) => {
      const [, messageRef,, event, payload] = JSON.parse(data);
      if (event === "phx_reply") {
        const item = pending.get(`${index}:${messageRef}`);
        if (item) {
          clearTimeout(item.timer); pending.delete(`${index}:${messageRef}`);
          if (payload.status === "ok") item.resolve(payload.response);
          else item.reject(Error(payload.response?.reason || "Mensagem rejeitada"));
        }
      }
      if (event === "new_msg" && payload.texto.startsWith(run)) {
        if (ids.has(payload.id)) duplicated += 1;
        else {ids.add(payload.id); received += 1;}
      }
    });
    ws.addEventListener("open", async () => {
      try { await push(ws, index, "phx_join", {usuario: `bot-${index}`, chave: key}); resolve(); }
      catch (error) { reject(error); }
    });
  })));
  heartbeat = setInterval(() => sockets.forEach((ws, index) => {
    if (ws.readyState === WebSocket.OPEN) push(ws, index, "heartbeat", {}, "phoenix", null).catch(() => {});
  }), 20000);
  const sendingStarted = performance.now();
  // Uma rodada por vez limita mensagens pendentes e mantém pressão controlada.
  for (let round = 0; round < rounds; round++) {
    await Promise.all(sockets.map((ws, index) => push(ws, index, "new_msg", {texto: `${run}${index}-${round}`})));
  }
  await waitFor(() => deliveries.every(ids => ids.size === expected));
  const duration = (performance.now() - sendingStarted) / 1000;
  console.log(JSON.stringify({clientes: clients, mensagens_enviadas: expected, entregas_esperadas: expected * clients, entregas_recebidas: received, duplicadas: duplicated, segundos: Number(duration.toFixed(3)), mensagens_por_segundo_observadas: Math.round(expected / duration), tempo_total_segundos: Number(((performance.now() - started) / 1000).toFixed(3))}, null, 2));
  if (duplicated) process.exitCode = 1;
} catch (error) { console.error(error.message); process.exitCode = 1; }
finally {
  clearInterval(heartbeat);
  for (const {timer} of pending.values()) clearTimeout(timer);
  for (const ws of sockets) if (ws.readyState <= WebSocket.OPEN) ws.close();
}
