from math import sin, pi

samples = []
for i in range(100000):
    samples.append(sin(2*pi*i/148) * 2**7)

with open("sine_148_7bits.waveform", "w") as f:
    samples = [str(int(sample)) for sample in samples]
    f.write("\n".join(samples))
