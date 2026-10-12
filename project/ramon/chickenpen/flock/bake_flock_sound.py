"""Bakes the murmuration's three sound loops into chickenpen/audio/sfx/.

    python project/ramon/chickenpen/flock/bake_flock_sound.py

A murmuration close by is thousands of wings: a broad rush of air, and under 20 m or so
the fluttering of the nearest birds shows through it. When a hawk sends the roll through
the flock the rush brightens and swells. So three loops, mixed live by flock_sound_4d.gd
from what the birds are doing:

  flock_rush.wav     the air: noise shaped around 200 Hz - 3 kHz, breathing slowly
  flock_flutter.wav  the nearest wings: 90 birds each beating at 10-14 Hz, every beat a
                     short burst of bright noise
  flock_gust.wav     the roll: brighter, broader noise with a faster swell

Every loop is periodic by construction, so it repeats without a seam: noise shaped in the
frequency domain is circular, and every modulator and wingbeat rate is a whole number of
cycles over the loop's length. Each file is normalised to -20 dBFS RMS, so the faders in
flock_sound_4d.gd mean the same thing for all three. Stereo, decorrelated left and right,
so the mass sounds wide rather than coming out of one point.
"""

import os
import wave

import numpy as np

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "audio", "sfx"))
RNG = np.random.default_rng(5213)


def shaped_noise(seconds, shape):
    """Periodic noise of [seconds] whose magnitude spectrum is shape(frequencies)."""
    n = int(RATE * seconds)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    magnitude = shape(np.maximum(freqs, 1.0))
    magnitude[0] = 0.0
    phase = RNG.uniform(0.0, 2.0 * np.pi, freqs.size)
    out = np.fft.irfft(magnitude * np.exp(1j * phase), n)
    return out / np.sqrt(np.mean(out ** 2))


def band(lo, hi, peak, tilt):
    """A soft band-pass: rises from lo, flat-ish to peak, falls with [tilt] above hi."""
    def shape(f):
        rise = (f / lo) ** 2 / (1.0 + (f / lo) ** 2)
        fall = 1.0 / (1.0 + (f / hi) ** tilt)
        bump = 1.0 + 0.6 * np.exp(-((np.log(f / peak)) ** 2) / 0.5)
        return rise * fall * bump
    return shape


def breathing(seconds, cycles, depth):
    """A slow swell, periodic over the loop: whole numbers of cycles only."""
    t = np.arange(int(RATE * seconds)) / RATE
    m = np.zeros_like(t)
    for c, weight in cycles:
        m += weight * np.sin(2.0 * np.pi * c * t / seconds + RNG.uniform(0.0, 2.0 * np.pi))
    m /= max(np.max(np.abs(m)), 1e-9)
    return 1.0 + depth * m


def rush(seconds):
    channels = []
    for _ in range(2):
        noise = shaped_noise(seconds, band(180.0, 2600.0, 650.0, 2.5))
        channels.append(noise * breathing(seconds, [(2, 1.0), (3, 0.6), (5, 0.35)], 0.28))
    return np.stack(channels, axis=1)


def flutter(seconds, birds=90):
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    channels = []
    for _ in range(2):
        carrier = shaped_noise(seconds, band(900.0, 5200.0, 2200.0, 3.0))
        envelope = np.zeros(n)
        for _b in range(birds):
            # A whole number of beats over the loop, so the bird lines up with itself.
            beats = max(1, round(RNG.uniform(10.0, 14.0) * seconds))
            rate = beats / seconds
            phase = RNG.uniform(0.0, 1.0)
            u = (t * rate + phase) % 1.0
            # The downstroke: a sharp rise and a quick fall, a quarter of the cycle long.
            stroke = np.where(u < 0.25, np.sin(np.pi * u / 0.25) ** 2, 0.0)
            # Some birds glide for part of the loop: a slow on/off, also periodic.
            glide = 0.5 + 0.5 * np.sin(2.0 * np.pi * RNG.integers(1, 4) * t / seconds + RNG.uniform(0, 2 * np.pi))
            envelope += RNG.uniform(0.4, 1.0) * stroke * np.clip(glide * 1.6 - 0.3, 0.0, 1.0)
        envelope /= np.sqrt(np.mean(envelope ** 2))
        channels.append(carrier * envelope)
    return np.stack(channels, axis=1)


def gust(seconds):
    channels = []
    for _ in range(2):
        noise = shaped_noise(seconds, band(300.0, 6500.0, 1500.0, 2.0))
        channels.append(noise * breathing(seconds, [(6, 1.0), (9, 0.7), (13, 0.4)], 0.45))
    return np.stack(channels, axis=1)


def write(name, data):
    data = data / np.sqrt(np.mean(data ** 2)) * (10.0 ** (-20.0 / 20.0))
    peak = np.max(np.abs(data))
    if peak > 0.89:
        data *= 0.89 / peak
    path = os.path.join(OUT, name)
    pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    rms = 20.0 * np.log10(np.sqrt(np.mean(data ** 2)))
    print("%-18s %.1f s  rms %.1f dBFS  peak %.1f dBFS" % (name, data.shape[0] / RATE, rms, 20.0 * np.log10(np.max(np.abs(data)))))


if __name__ == "__main__":
    write("flock_rush.wav", rush(8.0))
    write("flock_flutter.wav", flutter(4.0))
    write("flock_gust.wav", gust(6.0))
