def get(url: str):
    """Sends a GET request.

    :param url: URL for the new :class:`Request` object.
    :return: :class:`Response <Response>` object
    :rtype: requests.Response
    """

    # TODO: params=None, **kwargs
    # TODO: :param params: (optional) Dictionary, list of tuples or bytes to send in the query string for the :class:`Request`.
    # TODO: :param **kwargs: Optional arguments that ``request`` takes.
    return _GetRequest(url).task()

def _Response_json(self) -> dict:
    import json
    return json.loads(self.text)

Response.json = _Response_json
