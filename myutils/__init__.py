from pathlib import Path

def hello(name: str = "world") -> str:
    """Return a friendly greeting.

    This function is deliberately simple and has no external dependencies.
    """
    return f"Hello, {name}!"
