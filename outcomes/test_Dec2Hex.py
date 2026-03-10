import pytest
from Dec2Hex import decimal_to_hex

# Test that a standard decimal integer is correctly converted to hexadecimal
# 255 in decimal = FF in hexadecimal
def test_valid_integer():
    assert decimal_to_hex(255) == "FF"

# Test that 16 is correctly converted to hexadecimal
# 16 in decimal = 10 in hexadecimal (the first two-digit hex number)
def test_valid_integer_16():
    assert decimal_to_hex(16) == "10"

# Test that zero is handled correctly
# 0 has no hexadecimal representation in this implementation, so an empty string is expected
def test_zero():
    assert decimal_to_hex(0) == ""

# Test that a larger decimal number is correctly converted to hexadecimal
# 256 in decimal = 100 in hexadecimal
def test_large_number():
    assert decimal_to_hex(256) == "100"