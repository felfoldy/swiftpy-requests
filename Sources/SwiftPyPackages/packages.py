import pygit2 as _git
from pathlib import Path as _Path

_credentials = None
_remote_urls = []


def add_github_source(owner: str):
    _remote_urls.append(f"https://github.com/{owner}")


def set_credentials(username: str, access_token: str) -> None:
    global _credentials
    _credentials = _git.UserPass(username, access_token)


async def install(url: str, credentials: _git.UserPass | None = None) -> None:
    local_path = _local_path(url)

    if not credentials:
        credentials = _credentials

    callbacks = _git.RemoteCallbacks(credentials)

    try:
        repo = _git.Repository(local_path)

        # Fetch origin.
        origin = repo.remotes['origin']
        await origin.fetch(callbacks)

        # main <- origin main
        ref = repo.lookup_reference("refs/remotes/origin/main")
        target = ref.target
        repo.reset(target, _git.ResetMode.HARD)

    except:
        await _clone(url, local_path, callbacks)


def uninstall(url: str) -> None:
    local_path = _local_path(url)
    local_path.unlink()


async def _clone(url: str, path: str, callbacks: _git.RemoteCallbacks) -> None:
    if url.startswith("https://") or url.startswith("http://"):
        await _git.clone_repository(url, path, callbacks)
        return

    for base_url in _remote_urls:
        full_url = f"{base_url}/{url}"
        try:
            await _git.clone_repository(full_url, path, callbacks)
            return
        except Exception:
            pass

    raise ValueError(f"Could not install package: {url}")



def _local_path(url: str) -> _Path:
    last_component = url.split('/')[-1]
    if last_component.endswith(".git"):
        last_component = last_component[:-4]
    return _Path.site_packages() / last_component
