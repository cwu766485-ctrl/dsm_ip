"""Two's-complement helpers used by the bit-exact reference models."""


def signed_limits(width):
    if width < 2:
        raise ValueError("signed width must be at least two bits")
    return -(1 << (width - 1)), (1 << (width - 1)) - 1


def check_signed(value, width, name="value"):
    minimum, maximum = signed_limits(width)
    value = int(value)
    if not minimum <= value <= maximum:
        raise ValueError(f"{name}={value} is outside signed {width}-bit range")
    return value


def saturate_signed(value, width):
    minimum, maximum = signed_limits(width)
    return min(max(int(value), minimum), maximum)


def wrap_signed(value, width):
    modulus = 1 << width
    wrapped = int(value) & (modulus - 1)
    if wrapped >= (1 << (width - 1)):
        wrapped -= modulus
    return wrapped


def arithmetic_shift_right(value, shift):
    """Explicit arithmetic right shift for a signed integer."""
    return int(value) if shift <= 0 else int(value) >> shift
