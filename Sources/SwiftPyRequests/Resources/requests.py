def fetch(url: str):
    return FetchRequest(url).task()
