#!/usr/bin/env python3
"""
Python behavioral model for MAC16 verification.
This script models the exact same logic as the Verilog RTL to verify correctness.
It follows the updated spec:
  - Always signed (two's complement) multiplication
  - en=1: accumulate; en 1->0: capture mac_out, clear acc, assert out_ready
  - en=0: hold mac_out; en 0->1: restart accumulation from zero
"""


def to_unsigned_32(val):
    """Mask to 32-bit unsigned."""
    return val & 0xFFFFFFFF


def to_signed_16(val):
    """Interpret 16-bit value as signed."""
    val = val & 0xFFFF
    if val >= 0x8000:
        return val - 0x10000
    return val


def multiplier_model(a, b):
    """Model of multiplier.v: signed 16x16 -> 32 bit."""
    sa = to_signed_16(a)
    sb = to_signed_16(b)
    product = sa * sb
    return to_unsigned_32(product)


def adder_model(product, acc_in):
    """Model of adder.v: signed 32+32 -> 32 bit + overflow."""
    p = product & 0xFFFFFFFF
    a = acc_in & 0xFFFFFFFF
    result = p + a
    s = to_unsigned_32(result)

    # Signed overflow detection
    p_sign = (p >> 31) & 1
    a_sign = (a >> 31) & 1
    s_sign = (s >> 31) & 1
    overflow = 1 if (p_sign == a_sign) and (s_sign != p_sign) else 0

    return s, overflow


class MAC16:
    """Cycle-accurate model of mac16.v with spec-compliant en behavior."""

    def __init__(self):
        self.acc = 0          # Internal accumulator
        self.mac_out = 0      # Output register
        self.carry = 0        # Sticky overflow
        self.out_ready = 0    # Output valid flag
        self.en_d = 0         # Delayed en for edge detection

    def reset(self):
        self.acc = 0
        self.mac_out = 0
        self.carry = 0
        self.out_ready = 0
        self.en_d = 0

    def clock(self, din_a, din_b, en):
        """Simulate one positive clock edge."""
        product = multiplier_model(din_a, din_b)
        add_sum, add_overflow = adder_model(product, self.acc)

        if en:
            # Active accumulation
            self.acc = add_sum
            self.out_ready = 0

            if not self.en_d:
                # Rising edge of en: new computation, clear carry
                self.carry = add_overflow
            elif add_overflow:
                # Sticky carry
                self.carry = 1
        elif self.en_d:
            # Falling edge of en: capture result, clear acc
            self.mac_out = self.acc
            self.acc = 0
            self.out_ready = 1
            # carry retains its value
        # else: en=0 steady -> hold everything

        self.en_d = en


def run_tests():
    mac = MAC16()
    test_num = 1
    pass_count = 0
    fail_count = 0

    def check_acc(expected, name):
        nonlocal test_num, pass_count, fail_count
        actual = mac.acc
        if actual != expected:
            print(f"FAIL [Test {test_num}] {name}: acc=0x{actual:08X} (expected 0x{expected:08X})")
            fail_count += 1
        else:
            print(f"PASS [Test {test_num}] {name}: acc=0x{actual:08X}")
            pass_count += 1
        test_num += 1

    def check_mac_out(expected, name):
        nonlocal test_num, pass_count, fail_count
        actual = mac.mac_out
        if actual != expected:
            print(f"FAIL [Test {test_num}] {name}: mac_out=0x{actual:08X} (expected 0x{expected:08X})")
            fail_count += 1
        else:
            print(f"PASS [Test {test_num}] {name}: mac_out=0x{actual:08X}, carry={mac.carry}, out_ready={mac.out_ready}")
            pass_count += 1
        test_num += 1

    def check_ready(expected, name):
        nonlocal test_num, pass_count, fail_count
        actual = mac.out_ready
        if actual != expected:
            print(f"FAIL [Test {test_num}] {name}: out_ready={actual} (expected {expected})")
            fail_count += 1
        else:
            print(f"PASS [Test {test_num}] {name}: out_ready={actual}")
            pass_count += 1
        test_num += 1

    print("=" * 60)
    print("  MAC16 Python Behavioral Model - Verification")
    print("=" * 60)

    # ===== Test Group 1: Reset =====
    print("\n--- Test Group 1: Reset ---")
    mac.reset()
    check_mac_out(0x00000000, "Reset: mac_out=0")
    check_ready(0, "Reset: out_ready=0")

    # ===== Test Group 2: Spec required test cases =====
    print("\n--- Test Group 2: Spec required test cases ---")
    mac.reset()

    # Step 1: din_A=3, din_B=5 -> acc=15
    mac.clock(3, 5, 1)
    check_acc(15, "Spec step1: acc=3*5=15")

    # Step 2: din_A=-3(0xFFFD), din_B=-5(0xFFFB) -> acc=15+15=30
    mac.clock(0xFFFD, 0xFFFB, 1)
    check_acc(30, "Spec step2: acc=15+15=30")

    # Step 3: din_A=3, din_B=-5(0xFFFB) -> acc=30-15=15
    mac.clock(3, 0xFFFB, 1)
    check_acc(15, "Spec step3: acc=30-15=15")

    # Step 4: en falls -> mac_out=15, out_ready=1
    mac.clock(0, 0, 0)
    check_mac_out(15, "Spec result: mac_out=15")
    check_ready(1, "Spec result: out_ready=1")

    # Hold while en=0
    mac.clock(0, 0, 0)
    check_mac_out(15, "Hold: mac_out=15")
    check_ready(1, "Hold: out_ready=1")

    # ===== Test Group 3: Enable restart =====
    print("\n--- Test Group 3: Enable restart ---")
    # en rises -> new accumulation from zero
    mac.clock(10, 10, 1)
    check_acc(100, "Restart: acc=10*10=100")
    check_ready(0, "Restart: out_ready=0")

    mac.clock(5, 5, 1)
    check_acc(125, "Continue: acc=100+25=125")

    mac.clock(0, 0, 0)
    check_mac_out(125, "Result: mac_out=125")
    check_ready(1, "Result: out_ready=1")

    # ===== Test Group 4: Signed neg*pos =====
    print("\n--- Test Group 4: Signed neg*pos ---")
    mac.reset()
    mac.clock(0xFF9C, 50, 1)  # -100 * 50 = -5000
    check_acc(0xFFFFEC78, "Signed: acc=(-100)*50=-5000")

    mac.clock(200, 50, 1)     # 200 * 50 = 10000; -5000+10000=5000
    check_acc(5000, "Signed: acc=-5000+10000=5000")

    mac.clock(0, 0, 0)
    check_mac_out(5000, "Signed: mac_out=5000")

    # ===== Test Group 5: Zero inputs =====
    print("\n--- Test Group 5: Zero inputs ---")
    mac.reset()
    mac.clock(0, 12345, 1)
    check_acc(0, "Zero: acc=0*12345=0")
    mac.clock(0, 0, 0)
    check_mac_out(0, "Zero: mac_out=0")

    # ===== Test Group 6: Max positive =====
    print("\n--- Test Group 6: Max positive ---")
    mac.reset()
    mac.clock(0x7FFF, 0x7FFF, 1)  # 32767*32767
    check_acc(0x3FFF0001, "Max pos: acc=32767*32767")
    mac.clock(0, 0, 0)
    check_mac_out(0x3FFF0001, "Max pos: mac_out")

    # ===== Test Group 7: Min neg * Min neg =====
    print("\n--- Test Group 7: Min neg * Min neg ---")
    mac.reset()
    mac.clock(0x8000, 0x8000, 1)  # (-32768)*(-32768)
    check_acc(0x40000000, "Min neg sq: acc=(-32768)^2")
    mac.clock(0, 0, 0)
    check_mac_out(0x40000000, "Min neg sq: mac_out")

    # ===== Test Group 8: Min * Max =====
    print("\n--- Test Group 8: Min neg * Max pos ---")
    mac.reset()
    mac.clock(0x8000, 0x7FFF, 1)  # (-32768)*32767
    check_acc(0xC0008000, "Min*Max: acc=(-32768)*32767")
    mac.clock(0, 0, 0)
    check_mac_out(0xC0008000, "Min*Max: mac_out")

    # ===== Test Group 9: Multi-cycle signed mix =====
    print("\n--- Test Group 9: Multi-cycle signed mix ---")
    mac.reset()
    mac.clock(0xFFFE, 3, 1)  # -2*3=-6
    check_acc(0xFFFFFFFA, "Mix: acc=(-2)*3=-6")
    mac.clock(4, 0xFFFB, 1)  # 4*(-5)=-20; -6+(-20)=-26
    check_acc(0xFFFFFFE6, "Mix: acc=-6+(-20)=-26")
    mac.clock(6, 7, 1)       # 6*7=42; -26+42=16
    check_acc(16, "Mix: acc=-26+42=16")
    mac.clock(0, 0, 0)
    check_mac_out(16, "Mix: mac_out=16")
    check_ready(1, "Mix: out_ready=1")

    # ===== Test Group 10: Sum of squares =====
    print("\n--- Test Group 10: Sum of squares ---")
    mac.reset()
    for i in range(1, 6):
        mac.clock(i, i, 1)
    check_acc(55, "SumSq: acc=1+4+9+16+25=55")
    mac.clock(0, 0, 0)
    check_mac_out(55, "SumSq: mac_out=55")

    # ===== Test Group 11: Overflow detection =====
    print("\n--- Test Group 11: Overflow detection ---")
    mac.reset()
    mac.clock(0x7FFF, 0x7FFF, 1)  # 0x3FFF0001
    mac.clock(0x7FFF, 0x7FFF, 1)  # 0x7FFE0002
    mac.clock(0x7FFF, 0x7FFF, 1)  # 0xBFFD0003 -> overflow!
    mac.clock(0, 0, 0)
    print(f"INFO [Test {test_num}] Overflow: mac_out=0x{mac.mac_out:08X}, carry={mac.carry}")
    if mac.carry == 1:
        print(f"PASS [Test {test_num}] Signed overflow: carry detected")
        pass_count += 1
    else:
        print(f"FAIL [Test {test_num}] Signed overflow: carry NOT detected")
        fail_count += 1
    test_num += 1

    # ===== Test Group 12: Reset during operation =====
    print("\n--- Test Group 12: Reset during operation ---")
    mac.reset()
    mac.clock(100, 100, 1)
    mac.reset()  # mid-operation reset
    check_mac_out(0, "Mid-reset: mac_out=0")
    check_ready(0, "Mid-reset: out_ready=0")

    # ===== Test Group 13: Identity =====
    print("\n--- Test Group 13: Identity ---")
    mac.reset()
    mac.clock(12345, 1, 1)
    check_acc(12345, "Identity: acc=12345*1=12345")
    mac.clock(0, 0, 0)
    check_mac_out(12345, "Identity: mac_out=12345")

    # ===== Test Group 14: Multiple rounds =====
    print("\n--- Test Group 14: Multiple rounds ---")
    mac.reset()
    mac.clock(4, 5, 1)
    mac.clock(0, 0, 0)
    check_mac_out(20, "Round1: mac_out=20")

    mac.clock(6, 7, 1)
    check_acc(42, "Round2: acc=42 (fresh)")
    mac.clock(0, 0, 0)
    check_mac_out(42, "Round2: mac_out=42")

    # ===== Summary =====
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
