__doc__ = "The exceptions a request raises when it fails."

# The interpreter drops class docstrings, so the documentation help() shows is
# assigned to __doc__ directly.


class RequestException(Exception):
    __doc__ = "The base exception raised by every requests failure."


class ConnectionError(RequestException):
    __doc__ = "The host could not be reached."


class Timeout(RequestException):
    __doc__ = "No data arrived within the allowed time."


class HTTPError(RequestException):
    __doc__ = "The server answered with an error status."
