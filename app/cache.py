"""
In-memory TTL cache for read-only MT5 data. Per-key TTL; thread-safe get/set.
"""
import threading
import time
from typing import Any, Hashable, Optional

# TTL in seconds by timeframe string (for fetch_data_pos smart cache)
TIMEFRAME_TTL_SECONDS = {
    "M1": 60,
    "M5": 120,
    "M15": 300,
    "M30": 300,
    "H1": 600,
    "H4": 900,
    "D1": 1800,
    "W1": 3600,
    "MN1": 3600,
}

_store: dict = {}
_lock = threading.Lock()


def get(key: Hashable) -> Optional[Any]:
    """Return cached value if key exists and not expired, else None."""
    with _lock:
        entry = _store.get(key)
        if entry is None:
            return None
        expiry, value = entry
        if time.monotonic() >= expiry:
            del _store[key]
            return None
        return value


def set(key: Hashable, value: Any, ttl_seconds: float) -> None:
    """Store value with given TTL (seconds)."""
    with _lock:
        _store[key] = (time.monotonic() + ttl_seconds, value)


def ttl_for_timeframe(timeframe: str) -> int:
    """
    Return cache TTL in seconds for a given timeframe string (e.g. M1, D1).
    Used for fetch_data_pos. Default 60s if unknown.
    """
    return TIMEFRAME_TTL_SECONDS.get(timeframe.upper(), 60)
