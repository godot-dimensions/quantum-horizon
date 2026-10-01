"""Bakes the Lookout's one-shot sounds into chickenpen/audio/sfx/lookout_*.wav.

    python project/ramon/chickenpen/lookout/bake_lookout_sound.py

Everything is synthesised, so nothing here needs a licence and every sound can be tuned
by changing a number. What each one is modelled on:

  shutter     a mechanical SLR: the mirror's clack up, the curtains, the clack down
  winder      a motor drive advancing one frame
  reload      the motor rewinding a roll, and a new one latched in
  empty       the release pressed with nothing to fire: a dead click
  rung        a boot on a steel rung: a struck bar's inharmonic partials over a thud
  hatch       the cab door: a short creak and a wooden knock
  focus       one detent of the focus ring
  af / af_miss  the focus-confirm double beep, and a low "no"
  page / new_page  a page turned; a new page, a soft two-note chime
  radio_on / radio_off  the walkie-talkie's squelch, opening and closing
  burner      a propane burner's roar, a seamless loop (the balloon holds it)
  whistle     a two-note human whistle
  owl         three hoots, the last with a tremolo, low for an owl: it is not from here
  heron       a grey heron's harsh "fraank"
  wings       a big bird's wingbeats lifting off
  wind        wind round the cab and the basket: a seamless loop, gusting slowly

One-shots are peak-normalised to -1 dBFS; lookout_sound_4d.gd sets each one's level.
Mono, 44.1 kHz, 16-bit.
"""

import os
import wave

import numpy as np

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "audio", "sfx"))
RNG = np.random.default_rng(1041)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def noise(seconds):
    return RNG.standard_normal(int(RATE * seconds))


def bandpass(x, lo, hi):
    """A brick-wall band-pass in the frequency domain, softened at its edges."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(x.size, 1.0 / RATE)
    rise = 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4)
    fall = 1.0 / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(spec * rise * fall, x.size)


def env(t, attack, decay):
    """A quick rise and an exponential fall."""
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-5))


def place(total, piece, at):
    """[piece] added into [total] starting at [at] seconds."""
    i = int(at * RATE)
    j = min(total.size, i + piece.size)
    total[i:j] += piece[: j - i]
    return total


def clack(strength, body_hz=(1800.0, 3300.0, 5200.0), decay=0.018):
    t = t_axis(0.09)
    out = bandpass(noise(0.09), 400.0, 9000.0) * env(t, 0.0005, decay * 0.4) * 0.6
    for k, hz in enumerate(body_hz):
        out += np.sin(2 * np.pi * hz * t + RNG.uniform(0, 6.28)) * env(t, 0.0003, decay / (1 + k * 0.4)) * (0.8 / (1 + k))
    return out * strength


def shutter():
    total = np.zeros(int(RATE * 0.22))
    place(total, clack(1.0), 0.0)
    t = t_axis(0.03)
    place(total, bandpass(noise(0.03), 2000.0, 8000.0) * env(t, 0.004, 0.01) * 0.35, 0.012)
    place(total, clack(0.75, (1500.0, 2900.0, 4700.0), 0.022), 0.055)
    return total


def motor(seconds, hz_from, hz_to, grit=0.4):
    t = t_axis(seconds)
    hz = np.linspace(hz_from, hz_to, t.size)
    phase = 2 * np.pi * np.cumsum(hz) / RATE
    tone = sum(np.sin(phase * k) / k for k in range(1, 7))
    gears = bandpass(noise(seconds), 1500.0, 6000.0) * (0.5 + 0.5 * np.sin(phase * 0.25)) * grit
    edge = np.clip(t / 0.02, 0, 1) * np.clip((seconds - t) / 0.03, 0, 1)
    return (tone * 0.5 + gears) * edge


def winder():
    total = np.zeros(int(RATE * 0.36))
    place(total, motor(0.26, 210.0, 190.0), 0.0)
    place(total, clack(0.5, (2400.0, 4100.0), 0.012), 0.27)
    return total


def reload():
    total = np.zeros(int(RATE * 1.25))
    place(total, motor(0.9, 160.0, 420.0, 0.55), 0.0)
    place(total, clack(0.7, (900.0, 2100.0, 3800.0), 0.03), 0.95)
    place(total, clack(0.45, (2600.0, 4400.0), 0.012), 1.08)
    return total


def empty():
    return clack(0.6, (700.0, 1400.0), 0.02)


def rung():
    t = t_axis(0.45)
    base = 1150.0 * RNG.uniform(0.96, 1.04)
    out = np.zeros_like(t)
    for ratio, amp, dec in ((1.0, 1.0, 0.12), (2.76, 0.6, 0.07), (5.40, 0.35, 0.04), (8.93, 0.2, 0.025)):
        out += np.sin(2 * np.pi * base * ratio * t) * env(t, 0.0005, dec) * amp
    thud = bandpass(noise(0.45), 50.0, 260.0) * env(t, 0.002, 0.05) * 2.2
    return out * 0.5 + thud


def hatch():
    t = t_axis(0.42)
    hz = 150.0 + 70.0 * np.sin(np.pi * t / 0.42) + RNG.standard_normal(t.size).cumsum() * 0.05
    phase = 2 * np.pi * np.cumsum(hz) / RATE
    saw = 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    creak = bandpass(saw * (0.6 + 0.4 * RNG.random(t.size)), 300.0, 2600.0) * np.sin(np.pi * t / 0.42) ** 2
    total = np.zeros(int(RATE * 0.7))
    place(total, creak * 0.5, 0.0)
    kt = t_axis(0.2)
    knock = bandpass(noise(0.2), 80.0, 900.0) * env(kt, 0.001, 0.035) * 2.0 + np.sin(2 * np.pi * 180.0 * kt) * env(kt, 0.001, 0.05)
    place(total, knock, 0.44)
    return total


def focus():
    t = t_axis(0.012)
    return bandpass(noise(0.012), 3000.0, 7000.0) * env(t, 0.0003, 0.0018)


def beep(hz, seconds):
    t = t_axis(seconds)
    edge = np.clip(t / 0.003, 0, 1) * np.clip((seconds - t) / 0.004, 0, 1)
    return np.sin(2 * np.pi * hz * t) * edge


def af():
    total = np.zeros(int(RATE * 0.13))
    place(total, beep(2730.0, 0.04), 0.0)
    place(total, beep(2730.0, 0.04), 0.07)
    return total


def af_miss():
    return beep(620.0, 0.12) * 0.7 + beep(590.0, 0.12) * 0.3


def page():
    seconds = 0.45
    t = t_axis(seconds)
    swish = bandpass(noise(seconds), 1800.0, 9000.0)
    shape = np.exp(-((t - 0.12) / 0.06) ** 2) + 0.6 * np.exp(-((t - 0.26) / 0.05) ** 2)
    return swish * shape * (0.7 + 0.3 * RNG.random(t.size))


def bell(hz, seconds):
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for ratio, amp, dec in ((1.0, 1.0, 0.7), (2.0, 0.4, 0.4), (2.98, 0.25, 0.25), (4.1, 0.12, 0.15)):
        out += np.sin(2 * np.pi * hz * ratio * t) * env(t, 0.004, dec) * amp
    return out


def new_page():
    total = np.zeros(int(RATE * 1.6))
    place(total, bell(659.25, 1.3), 0.0)
    place(total, bell(987.77, 1.2) * 0.85, 0.16)
    return total


def squelch(opening):
    seconds = 0.2 if opening else 0.14
    t = t_axis(seconds)
    hiss = bandpass(noise(seconds), 500.0, 3500.0)
    shape = env(t, 0.003, 0.06) if opening else np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.05)
    total = np.zeros(int(RATE * (seconds + 0.05)))
    place(total, clack(0.5, (1200.0, 2500.0), 0.008), 0.0)
    place(total, hiss * shape * 0.8, 0.01)
    return total


def burner():
    seconds = 2.0
    n = int(RATE * seconds)
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    f = np.maximum(f, 1.0)
    rumble = 1.0 / (1.0 + (f / 300.0) ** 2) * (f / 40.0) ** 2 / (1.0 + (f / 40.0) ** 2)
    hiss = 0.35 * np.exp(-((np.log(f / 3500.0)) ** 2) / 0.4)
    mag = rumble + hiss
    mag[0] = 0.0
    out = np.fft.irfft(mag * np.exp(1j * RNG.uniform(0, 6.28, f.size)), n)
    return out  # periodic over its length: loops without a seam


def whistle():
    seconds = 0.95
    t = t_axis(seconds)
    hz = np.where(t < 0.4, 2100.0 + 700.0 * np.sin(np.pi * 0.5 * t / 0.4), 2800.0 - 900.0 * (np.maximum(t - 0.4, 0.0) / 0.55) ** 0.7)
    gap = np.clip(np.abs(t - 0.42) / 0.03, 0.0, 1.0)
    phase = 2 * np.pi * np.cumsum(hz) / RATE
    tone = np.sin(phase) * (1.0 + 0.02 * np.sin(2 * np.pi * 6.0 * t))
    breath = bandpass(noise(seconds), 1500.0, 4000.0) * 0.08
    edge = np.clip(t / 0.04, 0, 1) * np.clip((seconds - t) / 0.08, 0, 1)
    return (tone + breath) * edge * gap


def hoot(seconds, hz, tremolo=0.0):
    t = t_axis(seconds)
    glide = hz * (1.0 + 0.06 * np.sin(np.pi * t / seconds) - 0.05 * (t / seconds))
    phase = 2 * np.pi * np.cumsum(glide) / RATE
    tone = np.sin(phase) + 0.18 * np.sin(phase * 2.0) + 0.05 * np.sin(phase * 3.0)
    if tremolo > 0.0:
        tone *= 1.0 - 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * tremolo * t)) * np.clip((t - 0.1) / 0.1, 0, 1)
    breath = bandpass(noise(seconds), hz * 0.8, hz * 2.5) * 0.12
    shape = np.clip(t / 0.06, 0, 1) * np.clip((seconds - t) / 0.12, 0, 1)
    return (tone + breath) * shape


def owl():
    total = np.zeros(int(RATE * 2.7))
    place(total, hoot(0.55, 380.0), 0.0)
    place(total, hoot(0.16, 400.0) * 0.6, 1.25)
    place(total, hoot(0.85, 385.0, 28.0) * 0.9, 1.5)
    return total


def heron():
    seconds = 0.62
    t = t_axis(seconds)
    hz = 270.0 * (1.0 + 0.12 * np.sin(np.pi * t / seconds)) * (1.0 + 0.03 * RNG.standard_normal(t.size).cumsum() / np.sqrt(t.size))
    phase = 2 * np.pi * np.cumsum(hz) / RATE
    saw = sum(np.sin(phase * k) / k for k in range(1, 18))
    rough = saw * (0.7 + 0.6 * RNG.random(t.size)) + bandpass(noise(seconds), 600.0, 3000.0) * 0.8
    voiced = bandpass(rough, 500.0, 2400.0) + 0.6 * bandpass(rough, 1500.0, 2200.0)
    shape = np.clip(t / 0.015, 0, 1) * np.exp(-np.maximum(t - 0.12, 0.0) / 0.25)
    total = np.zeros(int(RATE * 0.9))
    place(total, voiced * shape, 0.0)
    return total


def wings():
    total = np.zeros(int(RATE * 2.0))
    for k in range(5):
        t = t_axis(0.3)
        beat = bandpass(noise(0.3), 60.0, 900.0) * np.sin(np.pi * np.clip(t / 0.3, 0, 1)) ** 3 * (1.0 - 0.12 * k)
        place(total, beat, 0.05 + k * 0.36)
    return total


def wind():
    """Periodic: noise shaped in the frequency domain is circular, and the gusts are whole
    cycles over the loop, so it repeats without a seam."""
    seconds = 8.0
    n = int(RATE * seconds)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / RATE), 1.0)
    low = 1.0 / (1.0 + (f / 260.0) ** 2) * (f / 30.0) ** 2 / (1.0 + (f / 30.0) ** 2)
    whistle = 0.25 * np.exp(-((np.log(f / 820.0)) ** 2) / 0.08)
    mag = low + whistle
    mag[0] = 0.0
    body = np.fft.irfft(mag * np.exp(1j * RNG.uniform(0, 6.28, f.size)), n)
    t = np.arange(n) / RATE
    gust = 0.62 + 0.25 * np.sin(2 * np.pi * 1 * t / seconds + 0.4) + 0.13 * np.sin(2 * np.pi * 3 * t / seconds + 1.9)
    return body * gust


def save(name, x, peak=True):
    x = np.asarray(x, dtype=np.float64)
    if peak:
        x = x / max(np.max(np.abs(x)), 1e-9) * 0.89
    else:
        x = x / max(np.sqrt(np.mean(x ** 2)), 1e-9) * 0.1
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("%-26s %5.2f s" % (name, x.size / RATE))


def main():
    os.makedirs(OUT, exist_ok=True)
    save("lookout_shutter.wav", shutter())
    save("lookout_winder.wav", winder())
    save("lookout_reload.wav", reload())
    save("lookout_empty.wav", empty())
    save("lookout_rung.wav", rung())
    save("lookout_hatch.wav", hatch())
    save("lookout_focus.wav", focus())
    save("lookout_af.wav", af())
    save("lookout_af_miss.wav", af_miss())
    save("lookout_page.wav", page())
    save("lookout_new_page.wav", new_page())
    save("lookout_radio_on.wav", squelch(True))
    save("lookout_radio_off.wav", squelch(False))
    save("lookout_burner.wav", burner(), peak=False)
    save("lookout_whistle.wav", whistle())
    save("lookout_owl.wav", owl())
    save("lookout_heron.wav", heron())
    save("lookout_wings.wav", wings())
    save("lookout_wind.wav", wind(), peak=False)


if __name__ == "__main__":
    main()
