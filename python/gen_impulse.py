with open("impulse_128.waveform", "w") as f:
    impulse = ['0']*16 + ['1'] + ['0']*128
    impulse_str = '\n'.join(impulse)
    f.write(impulse_str)
