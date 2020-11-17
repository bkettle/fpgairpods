from math import sin, pi

samples = []
for i in range(100000):
    samples.append(sin(2*pi*i/200) * 2**10)

with open("sine_200_10bits.waveform", "w") as f:
    samples = [str(int(sample)) for sample in samples]
    f.write("\n".join(samples))