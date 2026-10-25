"""Synthesises every sound in assets/audio (effects, engine hum, music). Deterministic.

    python tools/make_audio.py

Needs numpy. The music is in the Ethiopian pentatonic mode Ambassel (D Eb G A Bb) over a slow
pad, a plucked krar-style melody and a light pulse, and loops seamlessly.
"""
import os
import wave

import numpy as np

SR = 44100
MUSIC_SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
rng = np.random.default_rng(7)


def save(name, data, sr=SR):
    data = np.asarray(data, dtype=np.float64)
    peak = np.abs(data).max()
    if peak > 0.92:
        data = data * (0.9 / peak)
    stereo = data.ndim == 2
    pcm = (np.clip(data, -1.0, 1.0) * 32767).astype('<i2')
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    print('wrote', name, '%.2fs' % (len(data) / sr), '%d KB' % (os.path.getsize(path) // 1024))


def tt(duration, sr=SR):
    return np.arange(int(duration * sr)) / sr


def sweep(f0, f1, duration, sr=SR):
    t = tt(duration, sr)
    freq = f0 * (f1 / f0) ** (t / duration)
    return np.sin(2 * np.pi * np.cumsum(freq) / sr)


def noise(duration, sr=SR):
    return rng.standard_normal(int(duration * sr))


def lowpass(x, cutoff, sr=SR):
    tau = sr / (2 * np.pi * cutoff)
    kernel = np.exp(-np.arange(int(tau * 6) + 1) / tau)
    kernel /= kernel.sum()
    return np.convolve(x, kernel)[:len(x)]


def highpass(x, cutoff, sr=SR):
    return x - lowpass(x, cutoff, sr)


def decay(duration, k, sr=SR):
    return np.exp(-k * tt(duration, sr))


def fade(x, ms=6, sr=SR):
    n = int(sr * ms / 1000)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def bell(freq, duration, amp=1.0, sr=SR):
    t = tt(duration, sr)
    body = (np.sin(2 * np.pi * freq * t) * np.exp(-3.0 * t)
            + 0.5 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-6.0 * t)
            + 0.25 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-9.0 * t))
    return amp * body


def place(buffer, sound, start, sr=SR):
    i = int(start * sr)
    end = min(len(buffer), i + len(sound))
    if i < len(buffer):
        buffer[i:end] += sound[:end - i]


def note_hz(name):
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    letter, rest = name[0], name[1:]
    semitone = names[letter]
    while rest and rest[0] in 'b#':
        semitone += -1 if rest[0] == 'b' else 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semitone - 9 + 12 * (octave - 4)) / 12.0)


# --- effects ----------------------------------------------------------------------------------

def laser():
    d = 0.24
    t = tt(d)
    tone = sweep(2000, 260, d) + 0.35 * np.sign(sweep(1000, 130, d))
    click = highpass(noise(d), 3000) * np.exp(-90 * t) * 0.6
    return fade(0.55 * tone * decay(d, 11) + click)


def laser_hit():
    d = 0.32
    t = tt(d)
    thump = sweep(160, 48, d) * np.exp(-14 * t)
    burst = lowpass(noise(d), 5000) * np.exp(-18 * t) * 0.7
    spark = np.sin(2 * np.pi * 2300 * t) * np.exp(-26 * t) * 0.3
    return fade(0.8 * (thump + burst) + spark)


def discover():
    d = 1.7
    buf = np.zeros(int(d * SR))
    scale = ['C5', 'D5', 'E5', 'G5', 'A5', 'C6']
    for i, n in enumerate(scale):
        place(buf, bell(note_hz(n), 1.1, 0.34), 0.09 * i)
    for n in ('C5', 'E5', 'G5', 'C6'):
        place(buf, bell(note_hz(n), 1.2, 0.26), 0.62)
    return fade(buf * 0.9, 12)


def hit():
    d = 0.5
    t = tt(d)
    thud = sweep(110, 38, d) * np.exp(-9 * t)
    crunch = lowpass(noise(d), 2400) * np.exp(-12 * t)
    clank = np.sin(2 * np.pi * 480 * t) * np.exp(-30 * t) * 0.25
    return fade(0.9 * (thud + 0.8 * crunch) + clank)


def explosion():
    d = 0.7
    t = tt(d)
    boom = sweep(90, 28, d) * np.exp(-6 * t)
    wash = lowpass(noise(d), 1800) * np.exp(-6.5 * t)
    debris = highpass(noise(d), 2500) * np.exp(-22 * t) * 0.35
    return fade(0.9 * (boom + 0.9 * wash) + debris, 8)


def heart_lost():
    d = 0.8
    buf = np.zeros(int(d * SR))
    for start, freq in ((0.0, 392.0), (0.22, 311.13)):
        t = tt(0.55)
        saw = 2 * ((freq * t) % 1.0) - 1
        place(buf, lowpass(saw, 1400) * np.exp(-5 * t) * 0.5, start)
    return fade(buf)


def launch():
    d = 1.5
    t = tt(d)
    envelope = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    whoosh = lowpass(noise(d), 600) * 0.0
    sweep_noise = noise(d)
    # a rising then falling band of noise
    parts = []
    for lo, hi in ((300, 1200), (1200, 4000)):
        parts.append(lowpass(sweep_noise, hi) - lowpass(sweep_noise, lo))
    tone = sweep(180, 900, d) * 0.12
    return fade((0.9 * (parts[0] + 0.6 * parts[1]) * 0.55 + tone) * envelope + whoosh, 30)


def arrive():
    d = 1.2
    buf = np.zeros(int(d * SR))
    place(buf, bell(note_hz('G5'), 1.0, 0.4), 0.0)
    place(buf, bell(note_hz('D6'), 1.0, 0.34), 0.16)
    return fade(buf, 10)


def ui_hover():
    d = 0.06
    return fade(np.sin(2 * np.pi * 1300 * tt(d)) * decay(d, 40) * 0.35, 3)


def ui_click():
    d = 0.16
    t = tt(d)
    blip = np.sin(2 * np.pi * 760 * t) * (t < 0.06) + np.sin(2 * np.pi * 1140 * t) * (t >= 0.06)
    return fade(blip * decay(d, 16) * 0.5, 3)


def game_over():
    d = 2.6
    buf = np.zeros(int(d * SR))
    for i, n in enumerate(['E4', 'D4', 'B3', 'A3']):
        place(buf, bell(note_hz(n), 1.4, 0.45), 0.42 * i)
    return fade(buf, 14)


def ammo_pickup():
    d = 0.7
    buf = np.zeros(int(d * SR))
    for i, n in enumerate(['E5', 'A5', 'E6']):
        place(buf, bell(note_hz(n), 0.5, 0.45), 0.07 * i)
    t = tt(d)
    clack = highpass(noise(d), 2500) * np.exp(-60 * t) * 0.25
    return fade(buf * 0.9 + clack, 8)


def fuel_pickup():
    d = 0.8
    t = tt(d)
    glug = sweep(180, 520, 0.5) * np.exp(-4 * tt(0.5))
    sparkle = np.zeros(int(d * SR))
    for i, n in enumerate(['G5', 'C6', 'G6']):
        place(sparkle, bell(note_hz(n), 0.45, 0.3), 0.1 + 0.08 * i)
    buf = np.zeros(int(d * SR))
    place(buf, glug * 0.6, 0.0)
    return fade(buf + sparkle, 8)


def empty_click():
    d = 0.14
    t = tt(d)
    tick = np.sin(2 * np.pi * 220 * t) * np.exp(-60 * t) + highpass(noise(d), 1800) * np.exp(-110 * t) * 0.6
    return fade(0.7 * tick, 2)


def level_up():
    d = 1.3
    buf = np.zeros(int(d * SR))
    for i, n in enumerate(['D5', 'G5', 'A5', 'D6']):
        place(buf, bell(note_hz(n), 0.9, 0.4), 0.11 * i)
    place(buf, sweep(220, 880, 0.5) * np.exp(-3 * tt(0.5)) * 0.25, 0.0)
    return fade(buf, 10)


def low_warning():
    d = 0.5
    buf = np.zeros(int(d * SR))
    for start in (0.0, 0.22):
        t = tt(0.18)
        place(buf, np.sin(2 * np.pi * 660 * t) * np.exp(-14 * t) * 0.5, start)
    return fade(buf, 4)


def engine_loop():
    d = 1.0
    t = tt(d)
    hum = (0.5 * np.sin(2 * np.pi * 55 * t) + 0.3 * np.sin(2 * np.pi * 110 * t) + 0.15 * np.sin(2 * np.pi * 165 * t)
           + 0.06 * np.sin(2 * np.pi * 330 * t))
    return 0.55 * hum * (0.8 + 0.2 * np.sin(2 * np.pi * 6 * t))


# --- music -------------------------------------------------------------------------------------

def pluck(freq, duration, amp, sr):
    t = tt(duration, sr)
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    body = sum(a * np.sin(2 * np.pi * freq * k * t * vibrato) for k, a in ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)))
    return amp * body * np.exp(-4.2 * t) * np.minimum(1, t * 400)


def pad(freqs, duration, amp, sr):
    t = tt(duration, sr)
    env = np.minimum(1, t / 0.9) * np.minimum(1, (duration - t) / 1.1)
    out = np.zeros(len(t))
    for f in freqs:
        out += np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.005 * t) + 0.2 * np.sin(2 * np.pi * f * 0.5 * t)
    return amp * out / len(freqs) * env


def reverb(x, sr, seed, seconds=1.8):
    r = np.random.default_rng(seed)
    n = int(seconds * sr)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / (sr * seconds / 6.9))
    ir[0] = 0
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x)]
    return wet / (np.abs(wet).max() + 1e-9)


def music():
    sr = MUSIC_SR
    bpm = 92.0
    beat = 60.0 / bpm
    bars = 16
    length = bars * 4 * beat
    tail = 2.4
    buf_l = np.zeros(int((length + tail) * sr))
    buf_r = np.zeros_like(buf_l)

    chords = [
        (['D3', 'A3', 'D4', 'G4'], 'D2'),
        (['Eb3', 'G3', 'Bb3', 'D4'], 'Eb2'),
        (['G2', 'D3', 'G3', 'Bb3'], 'G2'),
        (['A2', 'A3', 'D4', 'G4'], 'A2'),
    ]
    # (beat, note, length in beats); two-bar phrases in Ambassel (D Eb G A Bb)
    phrase_a = [(0, 'D5', 1), (1, 'Eb5', .5), (1.5, 'D5', .5), (2, 'A4', 1.5), (4, 'Bb4', .5), (4.5, 'A4', .5),
                (5, 'G4', 1), (6, 'A4', .5), (6.5, 'Bb4', .5), (7, 'A4', 1)]
    phrase_b = [(0, 'G5', 1), (1, 'A5', .5), (1.5, 'G5', .5), (2, 'D5', 1), (3, 'Eb5', 1), (4, 'D5', 1.5),
                (6, 'Bb4', .5), (6.5, 'A4', .5), (7, 'G4', 1)]
    phrases = [phrase_a, phrase_a, phrase_b, phrase_a]

    for bar in range(bars):
        chord_notes, bass = chords[bar % 4]
        start = bar * 4 * beat
        notes = [note_hz(n) for n in chord_notes]
        p = pad(notes, 4 * beat + 1.2, 0.17, sr)
        place(buf_l, p, start, sr)
        place(buf_r, p * 0.92, start + 0.012, sr)
        for b in (0, 2):
            place(buf_l, pluck(note_hz(bass), 1.4, 0.34, sr) * 0.7, start + b * beat, sr)
            place(buf_r, pluck(note_hz(bass), 1.4, 0.34, sr) * 0.7, start + b * beat, sr)
        # soft pulse and shaker
        for b in (0, 2):
            thump = sweep(105, 46, 0.2, sr) * np.exp(-14 * tt(0.2, sr)) * 0.22
            place(buf_l, thump, start + b * beat, sr)
            place(buf_r, thump, start + b * beat, sr)
        for e in range(8):
            shake = highpass(rng.standard_normal(int(0.06 * sr)), 5000, sr) * np.exp(-60 * tt(0.06, sr)) * (0.05 if e % 2 else 0.025)
            place(buf_l, shake, start + e * beat / 2, sr)
            place(buf_r, shake, start + e * beat / 2 + 0.004, sr)

    for cycle in range(4):
        phrase = phrases[cycle]
        octave_up = 2.0 if cycle == 2 else 1.0
        for half in range(2):
            base = (cycle * 4 + half * 2) * 4 * beat
            for pos, name, ln in phrase:
                if cycle == 3 and half == 1 and pos >= 4:
                    continue
                hz = note_hz(name) * (octave_up if half == 0 else 1.0)
                tone = pluck(hz, 1.6 * max(ln, 0.6), 0.3, sr)
                place(buf_l, tone, base + pos * beat, sr)
                place(buf_r, tone * 0.85, base + pos * beat + 0.015, sr)

    wet_l = reverb(buf_l, sr, 1)
    wet_r = reverb(buf_r, sr, 2)
    left = buf_l / np.abs(buf_l).max() * 0.7 + wet_l * 0.3
    right = buf_r / np.abs(buf_r).max() * 0.7 + wet_r * 0.3
    n = int(length * sr)
    # Fold the tail onto the start so the loop has no seam.
    for side in (left, right):
        extra = side[n:]
        side[:len(extra)] += extra
    left, right = left[:n], right[:n]
    peak = max(np.abs(left).max(), np.abs(right).max())
    return np.stack([left, right], axis=1) / peak * 0.85


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [
        ('laser', laser), ('laser_hit', laser_hit), ('discover', discover), ('hit', hit),
        ('explosion', explosion), ('heart_lost', heart_lost), ('launch', launch), ('arrive', arrive),
        ('game_over', game_over), ('engine', engine_loop), ('ammo_pickup', ammo_pickup),
        ('fuel_pickup', fuel_pickup), ('empty_click', empty_click), ('level_up', level_up), ('low_warning', low_warning),
    ]:
        save(name + '.wav', fn())
    save('music.wav', music(), MUSIC_SR)


if __name__ == '__main__':
    main()
