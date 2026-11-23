"""Mirror a CYAN GitHub release to the Gitee CYAN repository.

Runs in the GitHub Actions release job.  It downloads the released tool
packages, converts any archive above Gitee's 100 MiB attachment limit to
.tar.xz, and publishes the set to the matching Gitee release.
"""

from __future__ import annotations

import hashlib
import io
import os
import sys
import tarfile
import tempfile
import time
import zipfile
from pathlib import Path

import requests

GITHUB_REPO = "Gipsy-The-Sheller/CYAN"
GITEE_REPO = os.environ.get("GITEE_REPO", "ZJXMolls/CYAN")
API = "https://gitee.com/api/v5"
TOKEN = os.environ.get("GITEE_TOKEN", "").strip()
LIMIT = 100 * 1024 * 1024
MAX_UPLOAD = int(os.environ.get("GITEE_MAX_BYTES", "0") or 0)
ONLY = {x.strip() for x in os.environ.get("GITEE_ONLY", "").split(",") if x.strip()}


def fail(message: str) -> None:
    print("ERROR:", message, file=sys.stderr)
    raise SystemExit(1)


def gitee(method: str, path: str, **kwargs):
    headers = kwargs.pop("headers", {})
    headers["Authorization"] = "token %s" % TOKEN
    for attempt in range(3):
        response = requests.request(
            method, API + path, headers=headers, timeout=600, **kwargs)
        if response.status_code < 500:
            break
        time.sleep(5 * (attempt + 1))
    if response.status_code >= 400:
        fail("%s %s -> %s %s" % (
            method, path, response.status_code, response.text[:400]))
    return response


def ensure_release(tag: str, body: str) -> int:
    response = requests.get(
        API + "/repos/%s/releases/tags/%s" % (GITEE_REPO, tag),
        headers={"Authorization": "token %s" % TOKEN}, timeout=60)
    data = response.json() if response.status_code == 200 else None
    if isinstance(data, dict) and data.get("id"):
        return int(data["id"])
    created = gitee("POST", "/repos/%s/releases" % GITEE_REPO, json={
        "tag_name": tag,
        "target_commitish": os.environ.get("GITEE_TARGET", "master"),
        "name": tag,
        "body": body or "Mirror of the GitHub release.",
        "prerelease": False,
    })
    return int(created.json()["id"])


def existing(release_id: int) -> set[str]:
    response = gitee(
        "GET", "/repos/%s/releases/%d/attach_files" % (GITEE_REPO, release_id),
        params={"per_page": 100})
    return {row["name"] for row in response.json()}


def upload(release_id: int, path: Path) -> None:
    """Upload with fresh file handles and retries for large attachments."""
    for attempt in range(1, 5):
        try:
            with path.open("rb") as handle:
                gitee(
                    "POST",
                    "/repos/%s/releases/%d/attach_files"
                    % (GITEE_REPO, release_id),
                    files={"file": (path.name, handle)},
                )
            print("uploaded", path.name, path.stat().st_size, flush=True)
            return
        except requests.exceptions.RequestException as exc:
            print("upload retry %d for %s: %s"
                  % (attempt, path.name, exc), flush=True)
            time.sleep(15 * attempt)
    raise SystemExit("upload failed: %s" % path.name)


def repack_zx(source: Path, target: Path) -> None:
    if zipfile.is_zipfile(source):
        with zipfile.ZipFile(source) as src, tarfile.open(
                target, "w:xz", preset=9) as dst:
            for info in src.infolist():
                if info.is_dir():
                    continue
                data = src.read(info)
                member = tarfile.TarInfo(info.filename)
                member.size = len(data)
                member.mtime = int(time.time())
                member.mode = 0o755
                dst.addfile(member, io.BytesIO(data))
        return
    with tarfile.open(source, "r:*") as src, tarfile.open(
            target, "w:xz", preset=9) as dst:
        for member in src:
            handle = src.extractfile(member) if member.isfile() else None
            dst.addfile(member, handle)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> None:
    if not TOKEN:
        fail("GITEE_TOKEN is not configured")
    tag = os.environ.get("GITEE_TAG") or os.environ.get("GITHUB_REF_NAME", "")
    if not tag:
        fail("no tag in GITEE_TAG/GITHUB_REF_NAME")
    release = requests.get(
        "https://api.github.com/repos/%s/releases/tags/%s"
        % (GITHUB_REPO, tag), timeout=60,
        headers={"Accept": "application/vnd.github+json"})
    if release.status_code != 200:
        fail("GitHub release %s not found" % tag)
    payload = release.json()
    release_id = ensure_release(tag, payload.get("body", ""))
    present = existing(release_id)

    work = Path(tempfile.mkdtemp(prefix="cyan_gitee_"))
    published = []
    skipped_existing = False
    for asset in payload.get("assets", []):
        name = asset["name"]
        if name.endswith(".sha256") or name == "SHA256SUMS":
            continue
        if ONLY and name not in ONLY:
            continue
        if name.endswith(".zip"):
            target_name = name[:-4] + ".tar.xz"
        elif name.endswith(".tar.gz") and "-src." not in name:
            target_name = name[:-7] + ".tar.xz"
        else:
            target_name = name
        if target_name in present:
            print("exists, skip download", target_name, flush=True)
            skipped_existing = True
            continue
        local = work / name
        print("download", name, asset["size"], flush=True)
        with requests.get(asset["browser_download_url"], stream=True,
                          timeout=600) as response:
            response.raise_for_status()
            with local.open("wb") as handle:
                for chunk in response.iter_content(1024 * 1024):
                    handle.write(chunk)
        if local.stat().st_size > LIMIT:
            if name.endswith(".zip"):
                target_name = name[:-4] + ".tar.xz"
            elif name.endswith(".tar.gz"):
                target_name = name[:-7] + ".tar.xz"
            else:
                target_name = name + ".xz"
            converted = work / target_name
            repack_zx(local, converted)
            local.unlink()
            local = converted
        if MAX_UPLOAD and local.stat().st_size > MAX_UPLOAD:
            data = local.read_bytes()
            part_size = MAX_UPLOAD
            parts = [data[i:i + part_size]
                     for i in range(0, len(data), part_size)]
            for index, chunk in enumerate(parts):
                part = work / ("%s.part-%s" % (target_name, chr(97 + index)))
                part.write_bytes(chunk)
                if part.name in present:
                    print("exists, skip", part.name, flush=True)
                else:
                    upload(release_id, part)
                published.append(part)
            print("split into", len(parts), "parts", flush=True)
            continue
        if target_name in present:
            print("exists, skip", target_name, flush=True)
        else:
            upload(release_id, local)
        published.append(local)

    if ONLY or skipped_existing:
        print("partial run; leaving SHA256SUMS unchanged", flush=True)
        return
    sums = work / "SHA256SUMS"
    sums.write_text(
        "".join("%s *%s\n" % (digest(path), path.name) for path in published),
        encoding="utf-8")
    if "SHA256SUMS" in present:
        rows = gitee(
            "GET",
            "/repos/%s/releases/%d/attach_files" % (GITEE_REPO, release_id),
            params={"per_page": 100}).json()
        for row in rows:
            if row["name"] == "SHA256SUMS":
                gitee(
                    "DELETE",
                    "/repos/%s/releases/%d/attach_files/%s"
                    % (GITEE_REPO, release_id, row["id"]))
    upload(release_id, sums)
    print("done", flush=True)


if __name__ == "__main__":
    main()
