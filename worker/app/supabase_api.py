"""Thin Supabase REST client (PostgREST + Storage + RPC) using httpx.

The worker authenticates with the service-role key; RLS is bypassed by
design (see docs/SECURITY.md). Kept minimal and explicit for testability.
"""

from __future__ import annotations

from typing import Any

import httpx

from .config import Settings


class SupabaseApi:
    def __init__(self, settings: Settings, client: httpx.Client | None = None):
        self._settings = settings
        self._client = client or httpx.Client(timeout=60)
        self._headers = {
            "apikey": settings.service_role_key,
            "Authorization": f"Bearer {settings.service_role_key}",
        }

    # ---------------- PostgREST ----------------

    def select(self, table: str, query: str) -> list[dict[str, Any]]:
        res = self._client.get(
            f"{self._settings.supabase_url}/rest/v1/{table}?{query}",
            headers=self._headers,
        )
        res.raise_for_status()
        return res.json()

    def update(self, table: str, query: str, values: dict[str, Any]) -> None:
        res = self._client.patch(
            f"{self._settings.supabase_url}/rest/v1/{table}?{query}",
            headers={**self._headers, "Prefer": "return=minimal"},
            json=values,
        )
        res.raise_for_status()

    def insert(self, table: str, values: Any) -> list[dict[str, Any]]:
        res = self._client.post(
            f"{self._settings.supabase_url}/rest/v1/{table}",
            headers={**self._headers, "Prefer": "return=representation"},
            json=values,
        )
        res.raise_for_status()
        return res.json()

    def delete(self, table: str, query: str) -> None:
        res = self._client.delete(
            f"{self._settings.supabase_url}/rest/v1/{table}?{query}",
            headers={**self._headers, "Prefer": "return=minimal"},
        )
        res.raise_for_status()

    def rpc(self, function: str, params: dict[str, Any] | None = None) -> Any:
        res = self._client.post(
            f"{self._settings.supabase_url}/rest/v1/rpc/{function}",
            headers=self._headers,
            json=params or {},
        )
        res.raise_for_status()
        if res.text:
            return res.json()
        return None

    # ---------------- Storage ----------------

    def download(self, bucket: str, path: str) -> bytes:
        res = self._client.get(
            f"{self._settings.supabase_url}/storage/v1/object/{bucket}/{path}",
            headers=self._headers,
        )
        res.raise_for_status()
        return res.content

    def upload(
        self,
        bucket: str,
        path: str,
        data: bytes,
        content_type: str,
        upsert: bool = True,
    ) -> None:
        res = self._client.post(
            f"{self._settings.supabase_url}/storage/v1/object/{bucket}/{path}",
            headers={
                **self._headers,
                "Content-Type": content_type,
                "x-upsert": "true" if upsert else "false",
            },
            content=data,
        )
        res.raise_for_status()
