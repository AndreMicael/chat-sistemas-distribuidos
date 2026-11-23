import {ChatConnection} from "./transport.js";
import {messageElement} from "./messages.js";

const $ = id => document.getElementById(id);
const general = {id: "geral", nome: "Geral", tipo: "publica", criado_por: "Sistema"};
let usuario = "";
let network = false;
let roomOnline = false;
let current = null;
let publicRooms = [general];
let privateRooms = new Map();
let buffers = new Map();
let received = 0;
let switching = false;
let sending = false;
let selection = 0;
let roomPresences = {};

function renderOnlineUsers() {
  const container = $("online-users-list");
  const badge = $("presence-badge");
  const count = $("presence-count");
  const bar = $("online-users-bar");

  if (!current || !roomOnline) {
    if (badge) badge.hidden = true;
    if (bar) bar.hidden = true;
    return;
  }

  const users = Object.entries(roomPresences);
  if (count) count.textContent = `${users.length} online`;
  if (badge) badge.hidden = false;
  if (bar) bar.hidden = users.length === 0;

  if (container) {
    container.replaceChildren();
    for (const [name, meta] of users) {
      const chip = document.createElement("span");
      chip.className = "user-chip" + (name === usuario ? " is-me" : "");
      const dot = document.createElement("span");
      dot.className = "user-chip-dot";
      const label = document.createElement("strong");
      label.textContent = name;
      const nodeSpan = document.createElement("span");
      nodeSpan.className = "user-chip-node";
      const nodeName = meta.metas?.[0]?.no || "—";
      nodeSpan.textContent = ` (${nodeName})`;
      chip.append(dot, label, nodeSpan);
      container.append(chip);
    }
  }
}

function notice(text, error = false) { $("notice").textContent = text; $("notice").dataset.error = String(error); }
function enableComposer() {
  const ready = network && roomOnline && !!current;
  $("message-text").disabled = !ready;
  $("send-button").disabled = !ready || sending;
  $("new-room").disabled = !network;
  $("enter-private").disabled = !network;
}
function buffer(id) {
  if (!buffers.has(id)) {
    if (buffers.size >= 20) buffers.delete(buffers.keys().next().value);
    buffers.set(id, []);
  }
  return buffers.get(id);
}
function showMessages() {
  const list = $("messages");
  list.replaceChildren();
  const messages = current ? buffer(current.id) : [];
  for (const message of messages) list.append(messageElement(message, usuario));
  $("empty-state").hidden = messages.length > 0;
  $("conversation").scrollTop = $("conversation").scrollHeight;
}
function renderRooms() {
  function render(container, rooms) {
    container.replaceChildren();
    for (const room of rooms) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "room-choice" + (current?.id === room.id ? " active" : "");
      button.dataset.roomId = room.id;
      button.setAttribute("aria-pressed", String(current?.id === room.id));
      const mark = document.createElement("span");
      mark.className = "room-choice-icon";
      mark.textContent = room.tipo === "privada" ? "◇" : "#";
      const label = document.createElement("span");
      label.textContent = room.nome;
      button.append(mark, label);
      button.addEventListener("click", () => selectRoom(room, privateRooms.get(room.id)?.chave));
      container.append(button);
    }
  }
  render($("public-list"), publicRooms);
  render($("private-list"), [...privateRooms.values()].map(item => item.sala));
  $("private-section").hidden = privateRooms.size === 0;
  $("public-count").textContent = String(publicRooms.length);
}
function updateRoomHeading(key) {
  const room = current;
  roomPresences = {};
  renderOnlineUsers();
  $("room-title").textContent = room?.nome || "Escolha uma sala";
  $("room-icon").textContent = room?.tipo === "privada" ? "◇" : "#";
  $("room-tag").textContent = room?.tipo === "privada" ? "PRIVADA" : "PÚBLICA";
  $("room-tag").hidden = !room;
  $("room-description").textContent = !room ? "Crie uma conversa ou escolha uma na lista" : room.tipo === "privada" ? "Conversa com entrada por chave" : "Uma sala aberta para todos";
  $("leave-room").hidden = !room;
  $("room-key-bar").hidden = !room || room.tipo !== "privada" || !key;
  $("room-key").textContent = key || "";
}

const api = new ChatConnection({
  network(online, node) {
    network = online;
    if (!online) roomOnline = false;
    $("status").dataset.state = online ? "online" : "connecting";
    $("status").textContent = online ? "Conectado" : "Reconectando…";
    $("node-name").textContent = node || "—";
    enableComposer();
    if (!online) notice("Conexão interrompida. Tentando reconectar automaticamente…");
  },
  catalog(rooms) { publicRooms = rooms; renderRooms(); },
  roomState(online, room, node, error) {
    if (current?.id !== room.id) return;
    roomOnline = online;
    if (online) {
      $("status").dataset.state = "online";
      $("status").textContent = "Conectado";
      if (node) $("node-name").textContent = node;
      notice(`Você está em ${room.nome}. Mensagens apenas para os participantes desta sala.`);
    } else if (error) {
      roomPresences = {};
      renderOnlineUsers();
      notice(error + " Se o servidor reiniciou, volte à Geral ou crie a sala novamente.", true);
    }
    enableComposer();
  },
  presenceState(state) {
    roomPresences = state || {};
    renderOnlineUsers();
  },
  presenceDiff(diff) {
    for (const [user, data] of Object.entries(diff?.joins || {})) {
      roomPresences[user] = data;
    }
    for (const user of Object.keys(diff?.leaves || {})) {
      delete roomPresences[user];
    }
    renderOnlineUsers();
  },
  message(message) {
    if (!current || message.sala_id !== current.id) return;
    const messages = buffer(current.id);
    if (messages.some(item => item.id === message.id)) return;
    messages.push(message);
    if (messages.length > 300) messages.shift();
    received += 1;
    $("message-count").textContent = String(received);
    const area = $("conversation");
    const bottom = area.scrollHeight - area.scrollTop - area.clientHeight < 110;
    $("messages").append(messageElement(message, usuario));
    while ($("messages").children.length > 300) $("messages").firstElementChild.remove();
    $("empty-state").hidden = true;
    if (bottom || message.usuario === usuario) area.scrollTop = area.scrollHeight;
  }
});

async function selectRoom(room, key = null) {
  if (!network || switching) return;
  const token = ++selection;
  switching = true;
  roomOnline = false;
  sending = false;
  current = room;
  $("message-text").value = "";
  $("char-count").textContent = "0/500";
  updateRoomHeading(key);
  renderRooms();
  showMessages();
  enableComposer();
  notice(`Entrando em ${room.nome}…`);
  try {
    await api.openRoom(room, key);
    if (token === selection) $("message-text").focus();
  } catch (error) {
    if (token === selection && !error.cancelled) notice(error.reason || "Não foi possível entrar.", true);
  } finally {
    if (token === selection) switching = false;
  }
}

$("join-form").addEventListener("submit", async event => {
  event.preventDefault();
  const name = $("nickname").value.trim();
  if (!name) return;
  $("join-button").disabled = true;
  $("status").textContent = "Conectando…";
  $("status").dataset.state = "connecting";
  try {
    const reply = await api.connect(name);
    usuario = reply.usuario;
    $("current-user").textContent = usuario;
    $("join-form").hidden = true;
    $("identity-active").hidden = false;
    $("rooms-section").hidden = false;
    await selectRoom(publicRooms.find(room => room.id === "geral") || publicRooms[0]);
  } catch (error) {
    api.disconnect(); network = false;
    $("status").textContent = "Desconectado";
    $("status").dataset.state = "offline";
    notice(error.reason || "Não foi possível conectar.", true);
  } finally { $("join-button").disabled = false; }
});

$("leave-button").addEventListener("click", () => {
  selection += 1;
  api.disconnect();
  network = false; roomOnline = false; current = null;
  switching = false; sending = false; usuario = "";
  privateRooms.clear(); buffers.clear(); received = 0; roomPresences = {};
  $("message-count").textContent = "0";
  $("join-form").hidden = false;
  $("identity-active").hidden = true;
  $("rooms-section").hidden = true;
  $("status").textContent = "Desconectado";
  $("status").dataset.state = "offline";
  $("node-name").textContent = "—";
  updateRoomHeading(); showMessages(); enableComposer(); renderOnlineUsers();
  notice("Você saiu. Informe um apelido para entrar novamente.");
});

$("leave-room").addEventListener("click", () => {
  selection += 1; api.leaveRoom(); current = null; roomOnline = false; switching = false; sending = false;
  roomPresences = {};
  updateRoomHeading(); renderRooms(); showMessages(); enableComposer(); renderOnlineUsers();
  notice("Você saiu da sala. Escolha outra conversa na lista.");
});

$("new-room").addEventListener("click", () => {
  $("create-error").textContent = "";
  $("create-form").reset();
  $("create-dialog").showModal();
  $("room-name").focus();
});
$("enter-private").addEventListener("click", () => {
  $("key-error").textContent = "";
  $("key-form").reset();
  $("key-dialog").showModal();
  $("private-key").focus();
});
for (const button of document.querySelectorAll("[data-close]")) button.addEventListener("click", () => $(button.dataset.close).close());

$("create-form").addEventListener("submit", async event => {
  event.preventDefault();
  $("create-submit").disabled = true;
  try {
    const reply = await api.createRoom($("room-name").value, $("room-type").value);
    if (reply.sala.tipo === "privada") privateRooms.set(reply.sala.id, reply);
    $("create-dialog").close();
    await selectRoom(reply.sala, reply.chave);
  } catch (error) { $("create-error").textContent = error.reason || "Não foi possível criar a sala."; }
  finally { $("create-submit").disabled = false; }
});
$("key-form").addEventListener("submit", async event => {
  event.preventDefault();
  $("key-submit").disabled = true;
  const key = $("private-key").value.trim().toUpperCase();
  try {
    const reply = await api.findPrivate(key);
    privateRooms.set(reply.sala.id, {sala: reply.sala, chave: key});
    renderRooms();
    $("key-dialog").close();
    await selectRoom(reply.sala, key);
  } catch (error) { $("key-error").textContent = error.reason || "Não foi possível entrar na sala."; }
  finally { $("key-submit").disabled = false; }
});
$("copy-key").addEventListener("click", async () => {
  try { await navigator.clipboard.writeText($("room-key").textContent); notice("Chave copiada. Compartilhe com quem deseja convidar."); }
  catch { notice("Selecione a chave exibida e copie para compartilhar."); }
});
$("message-text").addEventListener("input", () => { $("char-count").textContent = `${$("message-text").value.length}/500`; });
$("message-form").addEventListener("submit", async event => {
  event.preventDefault();
  if (!network || !roomOnline || !current || sending) return;
  const text = $("message-text").value.trim();
  if (!text) return notice("Escreva uma mensagem antes de enviar.", true);
  const token = selection;
  sending = true; enableComposer();
  try {
    await api.send(text);
    if (token !== selection) return;
    if ($("message-text").value.trim() === text) $("message-text").value = "";
    $("char-count").textContent = `${$("message-text").value.length}/500`;
    notice("Mensagem aceita pelo servidor.");
    $("message-text").focus();
  } catch (error) { if (token === selection) notice(error.reason || "Não foi possível enviar.", true); }
  finally { if (token === selection) { sending = false; enableComposer(); } }
});
renderRooms();
