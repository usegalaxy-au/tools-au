"""General utility functions."""

import re


def sortable_version(x):
    """Represent a galaxy tool version as a sortable tuple.

    e.g. 2.1.3+galaxy1.

    Has to account for all kinds of weird edge-cases like:

    - 2.3.4
    - 2.1.3+galaxy1+galaxy3
    - 234
    """
    def pad_v(v):
        """Pad a version number with zeros."""
        try:
            padded = f'{int(v):03}'
        except ValueError:
            padded = str(v)
        return padded

    if type(x) == float:
        return tuple(str(x))
    if '+' in x:
        v_num, suffix = x.split('+', 1)
    else:
        v_num = x
        suffix = None
    v_num = re.sub(r'[^\w\d\.]|\_', '.', v_num)  # Replace non-numeric with '.'
    version = [
        pad_v(v)
        for v in v_num.split('.')
    ]
    if suffix:
        version += [suffix]
    return tuple(version)
