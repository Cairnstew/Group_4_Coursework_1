import pytest
from Dec2Hex import decimal_to_hex

def test_valid_integer():
    assert decimal_to_hex(255) == "FF"

def test_valid_integer_16():
    assert decimal_to_hex(16) == "10"

def test_zero():
    assert decimal_to_hex(0) == ""

def test_large_number():
    assert decimal_to_hex(256) == "100"
