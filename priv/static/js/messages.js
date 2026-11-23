// Renderização isolada. Todo conteúdo recebido é tratado como texto.
export function messageElement(message, usuario) {
  const item = document.createElement("li");
  item.className = "message" + (message.usuario === usuario ? " mine" : "");
  item.dataset.messageId = message.id;
  const meta = document.createElement("div");
  meta.className = "message-meta";
  const name = document.createElement("strong");
  name.textContent = message.usuario;
  const time = document.createElement("time");
  time.dateTime = message.enviado_em;
  time.textContent = new Date(message.enviado_em).toLocaleTimeString("pt-BR", {hour: "2-digit", minute: "2-digit"});
  const node = document.createElement("span");
  node.textContent = `via ${message.no}`;
  meta.append(name, time, node);
  const body = document.createElement("p");
  body.className = "message-bubble";
  body.textContent = message.texto;
  item.append(meta, body);
  return item;
}
