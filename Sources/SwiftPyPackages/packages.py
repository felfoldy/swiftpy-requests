import pygit2 as _git
from pathlib import Path as _Path

_credentials = None


def set_credentials(username: str, access_token: str) -> None:
    global _credentials
    _credentials = _git.UserPass(username, access_token)


async def install(url: str, credentials: _git.UserPass | None = None) -> None:
    locale_path = _local_path(url)

    if not credentials:
        credentials = _credentials

    callbacks = _git.RemoteCallbacks(credentials)

    try:
        repo = _git.Repository(locale_path)

        # Fetch origin.
        origin = repo.remotes['origin']
        await origin.fetch(callbacks)

        # main <- origin main
        ref = repo.lookup_reference("refs/remotes/origin/main")
        target = ref.target
        repo.reset(target, _git.ResetMode.HARD)

    except:
        await _git.clone_repository(url, locale_path, callbacks)


def uninstall(url: str) -> None:
    locale_path = _local_path(url)
    locale_path.unlink()


def _local_path(url: str) -> _Path:
    last_component = url.split('/')[-1]
    if last_component.endswith(".git"):
        last_component = last_component[:-4]
    return _Path.site_packages() / last_component
