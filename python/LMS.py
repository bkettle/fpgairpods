import math
import matplotlib.pyplot as plt

with open("ila_test_input.waveform", "r") as f:
    temp = f.read().split("\n")
    samples = [int(x) for x in temp if len(x)>0]

def LMS(samples):
    y_out = []
    error_list = []
    co = [0]*64
    for i in range(len(samples)):
        y = 0
        for j in range(len(co)):
            y += co[j]*samples[i-j]
        y_out.append(y)
        e = - y - samples[i]
        error_list.append(e)
        for k in range(len(co)):
            co[k] += .000000000001*e*samples[i-k]
    # plt.plot(samples)
    # plt.plot(y_out)
    plt.plot(error_list)
    plt.show()
    return co


def NLMS(samples):
    y_out = []
    error_list = []
    co = [0]*64
    max_norm = 0
    for i in range(len(samples)):
        y = 0
        for j in range(len(co)):
            y += co[j]*samples[i-j]
        y_out.append(y)
        e = - y - samples[i]
        error_list.append(e)
        norm = 0
        for s in range(len(co)):
            norm += samples[i-s]**2
        if norm > max_norm:
            max_norm = norm
        for k in range(len(co)):
            co[k] += e*samples[i-k]/(norm + .01)
    plt.plot(samples)
    plt.plot(y_out)
    plt.plot(error_list)
    plt.show()
    return max_norm

def generate_sin(length):
    samples = []
    for i in range(length):
        samples.append(math.sin((2*math.pi*i)/(length/5)))
    return samples

def generate_cos(length):
    samples = []
    for i in range(length):
        samples.append(math.cos((2*math.pi*i)/(length/5)))
    return samples

final = NLMS(samples[2000:2500])

print (final)



