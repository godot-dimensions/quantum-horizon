"""Bakes the harbour gulls' calls into WaterLab/audio/ (gull/gull_flock_4d.gd plays them).

    python project/ramon/WaterLab/audio/bake_water_lab_sound.py

Synthesized, not recorded: nothing downloaded (follow_up/water_lab.md lists CC0 recordings that
could replace them, for Ramon to pick).

A HERRING GULL'S VOICE (the research in follow_up/water_lab.md): loud, nasal, a little raspy. Each
note has its fundamental around 0.6 to 1.1 kHz, the pitch rising quickly then falling, with strong
harmonics up to 5 or 6 kHz and most of the energy round 2 to 3 kHz (the nasal ring). The calls:

  gull_long.wav    the long call ("trumpeting"), given perched with the head thrown back: a long
                   falling "yeow", then a run of "kyow" notes that speed up, shorten and drop,
                   about 2.5 s in all
  gull_laugh.wav   "ha-ha-ha-ha": seven short notes, about 1.3 s
  gull_kek.wav     the alarm, "ga-ga-ga" at take-off: three short sharp notes
  gull_land.wav    no voice: the rustle of a landing's back-flaps and the feet meeting the rail

Each note: a sum of harmonics along the pitch contour, shaped by a nasal formant, roughened by a
fast amplitude flutter (the rasp) and a little breath noise through the same formant. Mono, 44.1
kHz, each file peak-normalised to -3 dBFS; the harbour sets the level by distance.
"""

import os
import wave

import numpy as np

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
RNG = np.random.default_rng(9104)


def formant_gain(f):
    """The nasal ring: a broad peak round 2.4 kHz, a smaller one round 4.2 kHz, the bottom rolled off."""
    g = 0.35 + np.exp(-((np.log(f / 2400.0)) ** 2) / 0.18) + 0.45 * np.exp(-((np.log(f / 4200.0)) ** 2) / 0.08)
    g *= (f / 500.0) ** 2 / (1.0 + (f / 500.0) ** 2)
    g /= 1.0 + (f / 7000.0) ** 4
    return g


def note(seconds, f_start, f_peak, f_end, peak_at=0.3, rasp=0.35, breath=0.12, attack=0.015, release=0.05):
    """One gull note: the pitch up from f_start to f_peak (at peak_at of the note), then down to f_end."""
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    u = t / seconds
    rise = np.clip(u / peak_at, 0.0, 1.0)
    fall = np.clip((u - peak_at) / (1.0 - peak_at), 0.0, 1.0)
    f0 = np.where(u < peak_at, f_start + (f_peak - f_start) * np.sin(rise * np.pi * 0.5), f_peak + (f_end - f_peak) * fall ** 0.8)
    # A little wobble, as a voice has.
    f0 *= 1.0 + 0.012 * np.sin(2.0 * np.pi * 7.0 * t + RNG.uniform(0, 6.28))
    phase = 2.0 * np.pi * np.cumsum(f0) / RATE
    out = np.zeros(n)
    for h in range(1, 14):
        fh = f0 * h
        amp = formant_gain(np.maximum(fh, 20.0)) / h ** 0.35
        amp = np.where(fh < RATE * 0.45, amp, 0.0)
        out += amp * np.sin(h * phase + RNG.uniform(0, 6.28))
    # The rasp: a fast flutter of the amplitude, near a third of the pitch (a subharmonic roughness).
    flutter = 1.0 - rasp * (0.5 + 0.5 * np.sin(phase / 3.0))
    out *= flutter
    # Breath noise through the same formant.
    noise = RNG.standard_normal(n)
    spec = np.fft.rfft(noise)
    freqs = np.maximum(np.fft.rfftfreq(n, 1.0 / RATE), 20.0)
    noise = np.fft.irfft(spec * formant_gain(freqs), n)
    noise /= max(np.sqrt(np.mean(noise ** 2)), 1e-9)
    out = out / max(np.sqrt(np.mean(out ** 2)), 1e-9) + breath * noise
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, (seconds - t) / release)
    env *= 0.75 + 0.25 * np.sin(np.pi * np.clip(u, 0, 1))
    return out * np.clip(env, 0.0, 1.0)


def sequence(parts):
    """[(gap before, samples, gain), ...] laid end to end."""
    total = sum(int(RATE * g) + s.size for g, s, _ in parts) + int(RATE * 0.25)
    out = np.zeros(total)
    at = 0
    for gap, s, gain in parts:
        at += int(RATE * gap)
        out[at:at + s.size] += s * gain
        at += s.size
    return out


def long_call():
    parts = [(0.03, note(0.55, 900, 1150, 620, peak_at=0.18, rasp=0.45), 0.95)]
    # The run: faster, shorter, lower toward its end.
    for k in range(9):
        u = k / 8.0
        d = 0.24 - 0.10 * u
        parts.append((0.11 - 0.05 * u, note(d, 760 - 120 * u, 1050 - 220 * u, 640 - 120 * u, peak_at=0.28, rasp=0.35 + 0.2 * u), 1.0 - 0.35 * u))
    return sequence(parts)


def laugh():
    parts = []
    for k in range(7):
        u = k / 6.0
        parts.append((0.03 if k == 0 else 0.085, note(0.12, 720, 900 - 80 * u, 700 - 60 * u, peak_at=0.35, rasp=0.5), 1.0 - 0.4 * u))
    return sequence(parts)


def kek():
    parts = []
    for k in range(3):
        parts.append((0.02 if k == 0 else 0.09, note(0.075, 1000, 1250, 1050, peak_at=0.4, rasp=0.25, breath=0.2, attack=0.004, release=0.02), 1.0 - 0.15 * k))
    return sequence(parts)


def land():
    """The back-flaps' rustle (four quick beats of airy noise), then the feet on the rail."""
    seconds = 0.75
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    noise = RNG.standard_normal(n)
    spec = np.fft.rfft(noise)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / RATE), 20.0)
    shape = (f / 300.0) ** 2 / (1.0 + (f / 300.0) ** 2) / (1.0 + (f / 2500.0) ** 2)
    air = np.fft.irfft(spec * shape, n)
    air /= np.sqrt(np.mean(air ** 2))
    beats = np.zeros(n)
    for k in range(4):
        c = 0.05 + k * 0.12
        beats += np.exp(-((t - c) / 0.035) ** 2) * (1.0 - 0.15 * k)
    out = air * beats * 0.6
    # The feet: a soft low knock and a scrape.
    at = 0.52
    knock = np.where(t > at, np.sin(2 * np.pi * 140.0 * (t - at)) * np.exp(-(t - at) / 0.025), 0.0)
    scrape = np.where(t > at, air * np.exp(-(t - at) / 0.05) * 0.25, 0.0)
    return out + knock * 0.8 + scrape


def write(name, data):
    data = data / np.max(np.abs(data)) * (10.0 ** (-3.0 / 20.0))
    pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype(np.int16)
    path = os.path.join(HERE, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    rms = 20.0 * np.log10(np.sqrt(np.mean(data ** 2)))
    print("%-12s %.2f s  rms %.1f dBFS" % (name, data.size / RATE, rms))


if __name__ == "__main__":
    write("gull_long", long_call())
    write("gull_laugh", laugh())
    write("gull_kek", kek())
    write("gull_land", land())
