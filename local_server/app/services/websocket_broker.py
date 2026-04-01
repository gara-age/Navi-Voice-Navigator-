import asyncio
from collections import defaultdict


class WebSocketBroker:
    def __init__(self) -> None:
        self._listeners: dict[str, list[asyncio.Queue]] = defaultdict(list)

    async def publish(self, session_id: str, event: dict) -> None:
        for queue in list(self._listeners.get(session_id, [])):
            await queue.put(event)

    def subscribe(self, session_id: str) -> asyncio.Queue:
        queue: asyncio.Queue = asyncio.Queue()
        self._listeners[session_id].append(queue)
        return queue

    def unsubscribe(self, session_id: str, queue: asyncio.Queue) -> None:
        listeners = self._listeners.get(session_id, [])
        if queue in listeners:
            listeners.remove(queue)
        if not listeners and session_id in self._listeners:
            del self._listeners[session_id]


broker = WebSocketBroker()
