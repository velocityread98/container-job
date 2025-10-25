import os
import json
import requests
from datetime import datetime
from typing import Any, Dict
from dotenv import load_dotenv

load_dotenv()

__all__ = ["betterstack_log"]

def betterstack_log(message: str, level: str = "ERROR", **extra: Any) -> None:
    """Send log message to BetterStack"""
    # token = "m14MowhdWHfpaZ6cEu3tU5Pp"
    # ingest = "https://s1533101.eu-nbg-2.betterstackdata.com"
    # source = "backend"
    
    token = os.getenv("BETTERSTACK_TOKEN")
    ingest = os.getenv("BETTERSTACK_INGEST_URL")
    source = os.getenv("BETTERSTACK_SOURCE")
    
    if not (token and ingest and message):  # missing config or empty message => no-op
        return
    
    payload: Dict[str, Any] = {
        "dt": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
        "level": level.upper(),
        "message": str(message),
        "source": source,
    }
    
    if extra:
        # Only include JSON-serializable values
        clean_extra: Dict[str, Any] = {}
        for k, v in extra.items():
            try:
                json.dumps(v)
                clean_extra[k] = v
            except Exception:
                continue
        if clean_extra:
            payload["extra"] = clean_extra
    
    try:
        requests.post(
            ingest.rstrip("/"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
            json=payload,
            timeout=2.0,
        )
    except Exception:
        # Swallow BetterStack send errors to avoid breaking the app
        pass
    
    # If it's an ERROR, also send a Discord notification (optional)
    if payload["level"] == "ERROR":
        webhook = os.getenv("DISCORD_WEBHOOK_URL")
        if webhook and webhook.startswith("https://discord.com/api/webhooks/"):
            discord_payload = {
                "content": f"[ERROR] {message}"[:1900],
                "username": "velocity-read-backend",
            }
            
            # Include extra context if available
            extra_ctx = payload.get("extra")
            if isinstance(extra_ctx, dict):
                snippet = json.dumps(extra_ctx)[:400]
                discord_payload["content"] += f"\nctx: {snippet}"
            
            try:
                requests.post(webhook, json=discord_payload, timeout=3.0)
            except Exception:
                pass