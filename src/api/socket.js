// Native WebSocket client with capped exponential backoff. No broker, no extra library.
export function createSocket({ path = '/ws', onMessage, onStatus }) {
  let ws;
  let attempt = 0;
  let closed = false;
  let timer;

  const connect = () => {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    ws = new WebSocket(`${proto}://${location.host}${path}`);
    ws.onopen = () => { attempt = 0; onStatus?.('open'); };
    ws.onmessage = (e) => {
      try { onMessage?.(JSON.parse(e.data)); } catch { /* ignore malformed frames */ }
    };
    ws.onclose = () => {
      onStatus?.('closed');
      if (closed) return;
      timer = setTimeout(connect, Math.min(30_000, 500 * 2 ** attempt++));
    };
  };
  connect();

  return {
    send: (msg) => ws?.readyState === WebSocket.OPEN && ws.send(JSON.stringify(msg)),
    close: () => { closed = true; clearTimeout(timer); ws?.close(); },
  };
}
