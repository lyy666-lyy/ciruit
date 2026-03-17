#!/usr/bin/env python3
"""
Python behavioral model for MAC16 verification.
This script models the exact same logic as the Verilog RTL to verify correctness.
It runs the same test cases as tb_mac16.v.
"""

import ctypes

def to_unsigned_32(val):
    """Mask to 32-bit unsigned."""
    return val & 0xFFFFFFFF

def to_signed_16(val):
    """Interpret 16-bit value as signed."""
    val = val & 0xFFFF
    if val >= 0x8000:
        return val - 0x10000
    return val

def to_signed_32(val):
    """Interpret 32-bit value as signed."""
    val = val & 0xFFFFFFFF
    if val >= 0x80000000:
        return val - 0x100000000
    return val

def multiplier(a, b, mode):
    """Model of multiplier.v"""
    a16 = a & 0xFFFF
    b16 = b & 0xFFFF
    if mode == 0:
        # Unsigned
        product = a16 * b16
    else:
        # Signed
        sa = to_signed_16(a16)
        sb = to_signed_16(b16)
        product = sa * sb
    return to_unsigned_32(product)

def adder(product, acc_in, mode):
    """Model of adder.v - returns (sum, carry)"""
    p = product & 0xFFFFFFFF
    a = acc_in & 0xFFFFFFFF
    result = p + a
    s = to_unsigned_32(result)

    if mode == 0:
        # Unsigned carry
        carry = 1 if result > 0xFFFFFFFF else 0
    else:
        # Signed overflow
        p_sign = (p >> 31) & 1
        a_sign = (a >> 31) & 1
        s_sign = (s >> 31) & 1
        carry = 1 if (p_sign == a_sign) and (s_sign != p_sign) else 0

    return s, carry

class MAC16:
    """Cycle-accurate model of mac16.v"""
    def __init__(self):
        self.acc = 0
        self.carry = 0
        self.out_ready = 0

    def reset(self):
        self.acc = 0
        self.carry = 0
        self.out_ready = 0

    def clock(self, a, b, mode, en):
        """Simulate one positive clock edge."""
        if en:
            product = multiplier(a, b, mode)
            s, c = adder(product, self.acc, mode)
            self.acc = s
            self.carry = c
            self.out_ready = 1
        else:
            self.out_ready = 0

    @property
    def out_31(self):
        return self.acc


def run_tests():
    mac = MAC16()
    test_num = 1
    pass_count = 0
    fail_count = 0

    def check(expected_out, expected_ready, name):
        nonlocal test_num, pass_count, fail_count
        actual_out = mac.out_31
        actual_ready = mac.out_ready
        if actual_out != expected_out or actual_ready != expected_ready:
            print(f"FAIL [Test {test_num}] {name}: out_31=0x{actual_out:08X} (expected 0x{expected_out:08X}), "
                  f"out_ready={actual_ready} (expected {expected_ready})")
            fail_count += 1
        else:
            print(f"PASS [Test {test_num}] {name}: out_31=0x{actual_out:08X}, carry={mac.carry}, out_ready={actual_ready}")
            pass_count += 1
        test_num += 1

    print("=" * 60)
    print("  MAC16 Python Behavioral Model - Verification")
    print("=" * 60)

    # Test 1: Reset
    print("\n--- Test Group 1: Reset ---")
    mac.reset()
    check(0x00000000, 0, "Reset clears output")

    # Test 2: Unsigned 3*5 = 15
    print("\n--- Test Group 2: Unsigned MAC Basic ---")
    mac.reset()
    mac.clock(3, 5, 0, 1)
    check(15, 1, "Unsigned 3*5=15")

    # Test 3: Unsigned accumulation 3*5 + 7*8 = 71
    print("\n--- Test Group 3: Unsigned Accumulation ---")
    mac.reset()
    mac.clock(3, 5, 0, 1)
    mac.clock(7, 8, 0, 1)
    check(71, 1, "Unsigned 3*5+7*8=71")

    # Test 4: Signed pos*pos 100*200 = 20000
    print("\n--- Test Group 4: Signed pos*pos ---")
    mac.reset()
    mac.clock(100, 200, 1, 1)
    check(20000, 1, "Signed 100*200=20000")

    # Test 5: Signed neg*pos (-3)*5 = -15
    print("\n--- Test Group 5: Signed neg*pos ---")
    mac.reset()
    mac.clock(0xFFFD, 5, 1, 1)  # -3 * 5
    check(0xFFFFFFF1, 1, "Signed (-3)*5=-15")

    # Test 6: Signed neg*neg (-3)*(-5) = 15
    print("\n--- Test Group 6: Signed neg*neg ---")
    mac.reset()
    mac.clock(0xFFFD, 0xFFFB, 1, 1)  # -3 * -5
    check(15, 1, "Signed (-3)*(-5)=15")

    # Test 7: Signed pos*neg 5*(-3) = -15
    print("\n--- Test Group 7: Signed pos*neg ---")
    mac.reset()
    mac.clock(5, 0xFFFD, 1, 1)  # 5 * -3
    check(0xFFFFFFF1, 1, "Signed 5*(-3)=-15")

    # Test 8: Zero inputs
    print("\n--- Test Group 8: Zero inputs ---")
    mac.reset()
    mac.clock(0, 12345, 0, 1)
    check(0, 1, "Unsigned 0*12345=0")

    # Test 9: Max unsigned 65535*65535
    print("\n--- Test Group 9: Max unsigned ---")
    mac.reset()
    mac.clock(0xFFFF, 0xFFFF, 0, 1)
    check(0xFFFE0001, 1, "Unsigned 65535*65535")

    # Test 10: Max signed positive 32767*32767
    print("\n--- Test Group 10: Max signed positive ---")
    mac.reset()
    mac.clock(0x7FFF, 0x7FFF, 1, 1)
    check(0x3FFF0001, 1, "Signed 32767*32767")

    # Test 11: Min signed * min signed (-32768)*(-32768)
    print("\n--- Test Group 11: Min signed * min signed ---")
    mac.reset()
    mac.clock(0x8000, 0x8000, 1, 1)
    check(0x40000000, 1, "Signed (-32768)*(-32768)")

    # Test 12: Min signed * max signed (-32768)*32767
    print("\n--- Test Group 12: Min signed * max signed ---")
    mac.reset()
    mac.clock(0x8000, 0x7FFF, 1, 1)
    check(0xC0008000, 1, "Signed (-32768)*32767")

    # Test 13: Enable control
    print("\n--- Test Group 13: Enable control ---")
    mac.reset()
    mac.clock(10, 10, 0, 1)  # en=1: 10*10=100
    check(100, 1, "en=1: 10*10=100")
    mac.clock(20, 20, 0, 0)  # en=0: should not update
    check(100, 0, "en=0: stays 100")
    mac.clock(5, 5, 0, 1)   # en=1: 100+25=125
    check(125, 1, "en=1: 100+5*5=125")

    # Test 14: Multi-cycle unsigned accumulation: sum of squares 1..5 = 55
    print("\n--- Test Group 14: Multi-cycle unsigned accumulation ---")
    mac.reset()
    for i in range(1, 6):
        mac.clock(i, i, 0, 1)
    check(55, 1, "Sum of squares 1..5=55")

    # Test 15: Multi-cycle signed accumulation
    print("\n--- Test Group 15: Multi-cycle signed accumulation ---")
    mac.reset()
    mac.clock(0xFFFE, 3, 1, 1)    # -2 * 3 = -6
    mac.clock(4, 0xFFFB, 1, 1)    # 4 * (-5) = -20
    mac.clock(6, 7, 1, 1)         # 6 * 7 = 42
    # -6 + (-20) + 42 = 16
    check(16, 1, "Signed mixed acc=16")

    # Test 16: Unsigned overflow
    print("\n--- Test Group 16: Unsigned overflow ---")
    mac.reset()
    mac.clock(0xFFFF, 0xFFFF, 0, 1)  # 0xFFFE0001
    mac.clock(0xFFFF, 0xFFFF, 0, 1)  # + 0xFFFE0001 = 0x1FFFC0002
    print(f"INFO [Test {test_num}] Unsigned overflow: out_31=0x{mac.out_31:08X}, carry={mac.carry}, out_ready={mac.out_ready}")
    if mac.carry == 1:
        print(f"PASS [Test {test_num}] Unsigned carry detected")
        pass_count += 1
    else:
        print(f"FAIL [Test {test_num}] Unsigned carry NOT detected")
        fail_count += 1
    test_num += 1

    # Test 17: Reset during operation
    print("\n--- Test Group 17: Reset during operation ---")
    mac.clock(100, 100, 0, 1)
    mac.reset()  # Reset mid-operation
    check(0x00000000, 0, "Reset clears mid-op")

    # Test 18: Signed neg->pos
    print("\n--- Test Group 18: Signed acc neg->pos ---")
    mac.reset()
    mac.clock(0xFF9C, 50, 1, 1)  # -100 * 50 = -5000
    check(0xFFFFEC78, 1, "Signed -100*50=-5000")
    mac.clock(200, 50, 1, 1)    # 200 * 50 = 10000; -5000+10000=5000
    check(5000, 1, "Signed -5000+200*50=5000")

    # Test 19: Identity multiplication
    print("\n--- Test Group 19: Identity multiplication ---")
    mac.reset()
    mac.clock(12345, 1, 0, 1)
    check(12345, 1, "Unsigned 12345*1=12345")

    # Test 20: 1*1
    print("\n--- Test Group 20: 1*1 ---")
    mac.reset()
    mac.clock(1, 1, 0, 1)
    check(1, 1, "Unsigned 1*1=1")

    # Summary
    print("\n" + "=" * 60)
    print(f"  MAC16 Python Verification - Summary")
    print(f"  Total: {pass_count + fail_count} | Passed: {pass_count} | Failed: {fail_count}")
    print("=" * 60)
    if fail_count == 0:
        print("  *** ALL TESTS PASSED ***")
    else:
        print("  *** SOME TESTS FAILED ***")
    print("=" * 60)
    return fail_count == 0


if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)
