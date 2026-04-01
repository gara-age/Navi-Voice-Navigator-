import httpx


class ServerProbe:
    def __init__(self, base_url: str = "http://127.0.0.1:18400") -> None:
        self.base_url = base_url

    def is_server_ready(self) -> bool:
        try:
            with httpx.Client(timeout=3.0) as client:
                response = client.get(f"{self.base_url}/health")
                return response.status_code == 200
        except Exception:
            return False
