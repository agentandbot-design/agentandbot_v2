#!/usr/bin/env python3
"""website_connector.py — bir website'nin tüm sayfalarını mem'e indeksler.

Sitemap.xml varsa ondan, yoksa link crawl'dan URL listesi çıkarır.
Sayfa metnini HTML'den ayıklar (basit tag temizleme), 8KB chunk.

Kullanim:
  python3 website_connector.py --site https://e-any.online --max 200
  python3 website_connector.py --site https://agentandbot.com --project agentandbot
"""
import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
from urllib.parse import urljoin, urlparse

MEM_URL = os.environ.get("MEM_URL", "https://mem.agentandbot.com")
MEM_TOKEN = os.environ.get("MEM_TOKEN", "")
STATE_DIR = os.path.join(os.path.dirname(__file__), "state")
CHUNK = 8000

UA = {"User-Agent": "Mozilla/5.0 (compatible; AgentAndBotIndexer/1.0)"}


def state_path(site: str) -> str:
    key = hashlib.sha256(site.encode()).hexdigest()[:16]
    return os.path.join(STATE_DIR, f"site_{key}.json")


def fetch(url: str, timeout=20) -> tuple[str, int]:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="ignore"), r.status


def urls_from_sitemap(site: str) -> list[str]:
    try:
        xml, _ = fetch(urljoin(site, "sitemap.xml"))
        return re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", xml)
    except Exception:
        return []


def extract_links(html: str, base: str) -> list[str]:
    out = []
    for href in re.findall(r'href=["\']([^"\'#]+)["\']', html):
        url = urljoin(base, href)
        if url.startswith("http") and urlparse(url).netloc == urlparse(base).netloc:
            out.append(url.split("?")[0])
    return out


def html_to_text(html: str) -> str:
    # script/style kaldır
    html = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    # title yakala
    m = re.search(r"<title[^>]*>(.*?)</title>", html, re.S | re.I)
    title = m.group(1).strip() if m else ""
    # tag'leri temizle
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"\s+", " ", text).strip()
    return title, text


def mem_ingest(content, title, project, source="doc"):
    body = json.dumps({"content": content, "title": title, "source": source, "project": project}).encode()
    req = urllib.request.Request(
        f"{MEM_URL}/api/memory", data=body,
        headers={"Authorization": f"Bearer {MEM_TOKEN}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def crawl(site: str, max_pages: int) -> list[str]:
    seen, queue = {site.rstrip("/")}, [site.rstrip("/")]
    while queue and len(seen) < max_pages:
        url = queue.pop(0)
        try:
            html, _ = fetch(url)
        except Exception:
            continue
        for link in extract_links(html, url):
            if link not in seen:
                seen.add(link)
                queue.append(link)
                if len(seen) >= max_pages:
                    break
    return sorted(seen)


def sync(site: str, project: str, max_pages: int, dry_run=False):
    if not MEM_TOKEN:
        print("MEM_TOKEN gerekli"); sys.exit(1)

    sp = state_path(site)
    state = json.load(open(sp)) if os.path.exists(sp) else {"pages": {}}

    urls = urls_from_sitemap(site)
    if urls:
        print(f"sitemap: {len(urls)} URL")
    else:
        print("sitemap yok — link crawl")
        urls = crawl(site, max_pages)
        print(f"crawl: {len(urls)} URL")

    urls = urls[:max_pages]
    ok, skip, err = 0, 0, 0

    for url in urls:
        h = hashlib.sha256(url.encode()).hexdigest()[:12]
        prev = state["pages"].get(url)
        try:
            html, status = fetch(url)
        except Exception as e:
            err += 1
            continue

        digest = hashlib.sha256(html.encode()).hexdigest()[:16]
        if prev and prev["digest"] == digest:
            skip += 1
            continue

        title, text = html_to_text(html)
        if len(text) < 50:  # boş/js sayfa
            skip += 1
            state["pages"][url] = {"digest": digest}
            continue

        parts = [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)] or [""]
        for idx, part in enumerate(parts, 1):
            page_title = title or url
            chunk_title = page_title if len(parts) == 1 else f"{page_title} ({idx}/{len(parts)})"
            content = f"URL: {url}\n{part}"
            if dry_run:
                print(f"[dry] {chunk_title} — {len(part)} char")
            else:
                try:
                    mem_ingest(content, chunk_title, project)
                except Exception as e:
                    err += 1
                    print(f"  hata {url}: {e}")

        ok += 1
        state["pages"][url] = {"digest": digest}

    if not dry_run:
        os.makedirs(STATE_DIR, exist_ok=True)
        json.dump(state, open(sp, "w"), indent=2)

    print(f"\nSite sync: {ok} sayfa, {skip} atlandı, {err} hata ({site})")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--site", required=True)
    p.add_argument("--project", default="website")
    p.add_argument("--max", type=int, default=200)
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    sync(a.site, a.project, a.max, a.dry_run)
