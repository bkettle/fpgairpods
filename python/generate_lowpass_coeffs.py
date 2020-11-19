import scipy.signal

coeffs = scipy.signal.firwin(31, 700, fs=65000)
print(coeffs)
print()

# format for verilog
for i, c in enumerate(coeffs):
    print(f"5'd{i}:\t coeff = {'-' if c < 0 else ''}10'sd{int(abs(c) * 2**10)};")
