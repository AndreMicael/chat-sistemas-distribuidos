import {Socket} from "/vendor/phoenix.mjs";

// Contrato de transporte. A interface não precisa conhecer o catálogo ou cluster.
export class ChatConnection {
  constructor(events) { this.events = events; this.socket = null; this.catalog = null; this.room = null; this.roomCancel = null; }

  connect(usuario) {
    this.disconnect();
    this.usuario = usuario;
    const socket = new Socket("/socket", {});
    this.socket = socket;
    const active = () => this.socket === socket;
    socket.onClose(() => { if (active()) this.events.network(false); });
    socket.onError(() => { if (active()) this.events.network(false); });
    const catalog = socket.channel("catalog:rooms", {usuario});
    this.catalog = catalog;
    catalog.on("public_rooms", ({salas}) => { if (active()) this.events.catalog(salas); });
    catalog.onError(() => { if (active()) this.events.network(false); });
    socket.connect();
    return new Promise((resolve, reject) => {
      catalog.join()
        .receive("ok", (reply) => {
          if (!active()) return;
          this.usuario = reply.usuario;
          this.events.catalog(reply.salas);
          this.events.network(true, reply.no);
          resolve(reply);
        })
        .receive("error", (error) => { if (active()) reject(error); })
        .receive("timeout", () => { if (active()) reject({reason: "Servidor demorou a responder. Tente entrar novamente."}); });
    });
  }

  request(event, payload = {}) { return this.push(this.catalog, event, payload); }
  createRoom(nome, tipo) { return this.request("create_room", {nome, tipo}); }
  findPrivate(chave) { return this.request("find_private", {chave}); }
  send(texto) { return this.push(this.room, "new_msg", {texto}); }

  openRoom(sala, chave = null) {
    this.leaveRoom();
    const channel = this.socket.channel(`room:${sala.id}`, {usuario: this.usuario, chave});
    this.room = channel;
    const active = () => this.room === channel;
    channel.on("new_msg", message => { if (active()) this.events.message(message); });
    channel.on("presence_state", state => { if (active()) this.events.presenceState?.(state); });
    channel.on("presence_diff", diff => { if (active()) this.events.presenceDiff?.(diff); });
    channel.onError(() => { if (active()) this.events.roomState(false, sala); });
    return new Promise((resolve, reject) => {
      this.roomCancel = () => reject({cancelled: true});
      channel.join()
        .receive("ok", reply => {
          if (!active()) return;
          this.roomCancel = null;
          this.events.roomState(true, reply.sala, reply.no);
          resolve(reply);
        })
        .receive("error", error => {
          if (!active()) return;
          this.roomCancel = null;
          this.events.roomState(false, sala, null, error.reason);
          reject(error);
        })
        .receive("timeout", () => {
          if (!active()) return;
          this.events.roomState(false, sala, null, "Aguardando a reconexão com a sala…");
          reject({reason: "A sala demorou a responder. A conexão continuará sendo tentada."});
        });
    });
  }

  leaveRoom() {
    const channel = this.room;
    this.room = null;
    if (this.roomCancel) { this.roomCancel(); this.roomCancel = null; }
    if (channel) channel.leave();
  }

  disconnect() {
    this.leaveRoom();
    const socket = this.socket;
    this.socket = null;
    this.catalog = null;
    if (socket) socket.disconnect();
  }

  push(channel, event, payload) {
    if (!channel || !channel.isJoined()) return Promise.reject({reason: "Aguarde a conexão para continuar."});
    return new Promise((resolve, reject) => {
      channel.push(event, payload)
        .receive("ok", resolve)
        .receive("error", reject)
        .receive("timeout", () => reject({reason: "Sem confirmação do servidor. Confira a conversa antes de reenviar."}));
    });
  }
}
