#!/usr/bin/env python3
"""Generates the placeholder sound effects in audio/sfx/. Deterministic: the same output on each run.

Run: python3 tools/gen_sfx.py
"""
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "audio" / "sfx"
rng = np.random.default_rng(33)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def decay(t: np.ndarray, tau: float, attack: float = 0.002) -> np.ndarray:
    return np.minimum(t / attack, 1.0) * np.exp(-t / tau)


def noise(t: np.ndarray) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, t.size)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        out[i] = acc
    return out


def sweep(t: np.ndarray, f0: float, f1: float) -> np.ndarray:
    freq = np.linspace(f0, f1, t.size)
    return np.sin(2.0 * np.pi * np.cumsum(freq) / RATE)


def save(name: str, x: np.ndarray, peak: float = 0.9) -> None:
    x = x / max(np.max(np.abs(x)), 1e-9) * peak
    fade = min(200, x.size)
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())


def gunshot() -> np.ndarray:
    t = t_axis(0.35)
    crack = noise(t) * decay(t, 0.02, 0.0005)
    boom = lowpass(noise(t), 600.0) * decay(t, 0.09)
    thump = sweep(t, 180.0, 50.0) * decay(t, 0.06)
    return crack * 0.7 + boom * 1.6 + thump * 0.8


def dry_click() -> np.ndarray:
    t = t_axis(0.08)
    return (noise(t) * decay(t, 0.006, 0.0003) + np.sin(2 * np.pi * 1800 * t) * decay(t, 0.01)) * 0.8


def reload() -> np.ndarray:
    t = t_axis(0.9)
    out = np.zeros(t.size)
    for start, freq in ((0.0, 900.0), (0.35, 600.0), (0.75, 1400.0)):
        i = int(start * RATE)
        n = min(int(0.08 * RATE), t.size - i)
        tt = np.arange(n) / RATE
        click = noise(tt) * decay(tt, 0.012, 0.0003) + np.sin(2 * np.pi * freq * tt) * decay(tt, 0.02)
        out[i:i + n] += click
    return out


def hit() -> np.ndarray:
    t = t_axis(0.09)
    return (np.sin(2 * np.pi * 1200 * t) + 0.5 * np.sin(2 * np.pi * 2400 * t)) * decay(t, 0.02, 0.0005)


def kill() -> np.ndarray:
    t = t_axis(0.3)
    first = (np.sin(2 * np.pi * 700 * t) + 0.5 * np.sin(2 * np.pi * 1400 * t)) * decay(t, 0.05, 0.0005)
    shifted = np.concatenate([np.zeros(int(0.09 * RATE)), first])[: t.size]
    return first + shifted * 0.9 + sweep(t, 300.0, 100.0) * decay(t, 0.08) * 0.6


def groan(base: float, length: float, wobble: float) -> np.ndarray:
    t = t_axis(length)
    env = np.sin(np.pi * t / length) ** 1.5
    pitch = base * (1.0 - 0.25 * t / length) * (1.0 + 0.04 * np.sin(2 * np.pi * wobble * t))
    phase = 2.0 * np.pi * np.cumsum(pitch) / RATE
    voice = sum(np.sin(k * phase) / k for k in range(1, 7))
    return lowpass(voice + 0.4 * noise(t), 900.0) * env


def zombie_attack() -> np.ndarray:
    t = t_axis(0.35)
    whoosh = lowpass(noise(t), 1500.0) * np.sin(np.pi * np.minimum(t / 0.2, 1.0) / 1.0) * np.exp(-t / 0.15)
    thud = sweep(t, 140.0, 50.0) * decay(t, 0.05) * np.where(t > 0.15, 1.0, 0.0)
    return whoosh * 0.6 + np.concatenate([np.zeros(int(0.15 * RATE)), thud[: t.size - int(0.15 * RATE)]]) * 1.2


def zombie_death() -> np.ndarray:
    t = t_axis(0.9)
    voice = groan(150.0, 0.9, 7.0)
    thud_t = t_axis(0.3)
    thud = sweep(thud_t, 90.0, 35.0) * decay(thud_t, 0.1)
    out = voice * 0.8
    start = int(0.6 * RATE)
    out[start:] += thud[: out.size - start] * 1.2
    return out


def player_hurt() -> np.ndarray:
    t = t_axis(0.3)
    grunt = np.sin(2 * np.pi * np.cumsum(np.linspace(260.0, 150.0, t.size)) / RATE) * decay(t, 0.1, 0.004)
    return lowpass(grunt + 0.5 * noise(t) * decay(t, 0.03), 1800.0) + sweep(t, 100.0, 50.0) * decay(t, 0.05) * 0.8


def sting(freqs: list[float], step: float, tail: float) -> np.ndarray:
    total = step * (len(freqs) - 1) + tail
    t = t_axis(total)
    out = np.zeros(t.size)
    for i, f in enumerate(freqs):
        s = int(i * step * RATE)
        tt = t[: t.size - s]
        out[s:] += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)) * decay(tt, tail * 0.4, 0.005)
    return out


SOUNDS = {
    "gunshot": gunshot(),
    "dry_click": dry_click(),
    "reload": reload(),
    "hit": hit(),
    "kill": kill(),
    "zombie_groan_1": groan(95.0, 1.1, 5.0),
    "zombie_groan_2": groan(120.0, 0.8, 6.5),
    "zombie_groan_3": groan(80.0, 1.4, 4.0),
    "zombie_attack": zombie_attack(),
    "zombie_death": zombie_death(),
    "player_hurt": player_hurt(),
    "round_start": sting([220.0, 277.2, 329.6, 440.0], 0.12, 0.9),
    "break_start": sting([440.0, 329.6, 277.2, 220.0], 0.14, 0.9),
}

for name, samples in SOUNDS.items():
    save(name, samples)
