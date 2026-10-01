"""Build short game foley from CC0 recordings and original noise layers.

Only standard Python and ffmpeg are required. Source credits accompany the game.
"""
from pathlib import Path
from array import array
import math
import random
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 44100


def recording(name):
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(ROOT / "source" / (name + ".mp3")),
         "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        check=True, capture_output=True)
    samples = array("f")
    samples.frombytes(result.stdout)
    return list(samples)


def write(name, samples, peak=0.75, room=False):
    if room:
        dry = list(samples)
        for delay, gain in [(0.029, 0.085), (0.053, 0.05), (0.087, 0.025)]:
            offset = int(delay * RATE)
            for i in range(offset, len(samples)):
                samples[i] += dry[i - offset] * gain
    maximum = max(abs(x) for x in samples) or 1.0
    pcm = array("h", (int(max(-1, min(1, x / maximum * peak)) * 32767) for x in samples))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as output:
        output.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())


def resample(samples, speed):
    result = []
    for i in range(int(len(samples) / speed)):
        pos = i * speed
        j = int(pos)
        k = min(j + 1, len(samples) - 1)
        result.append(samples[j] * (1 - pos + j) + samples[k] * (pos - j))
    return result


def loop_excerpt(samples, seconds, start=0.5):
    result = samples[int(start * RATE):int((start + seconds) * RATE)]
    # A short equal-power overlap avoids a click at the loop seam.
    overlap = min(int(0.08 * RATE), len(result) // 4)
    for i in range(overlap):
        t = i / overlap
        result[i] = result[i] * math.sin(t * math.pi / 2) + result[-overlap + i] * math.cos(t * math.pi / 2)
    return result[:-overlap]


def noise_foley(duration, seed, kind):
    rng = random.Random(seed)
    low = 0.0
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        u = t / duration
        white = rng.uniform(-1, 1)
        low += (white - low) * (0.09 if kind == "wing" else 0.22)
        high = white - low
        if kind == "swing":
            value = (low * 0.8 + high * 0.12) * math.sin(math.pi * u) ** 2 * (1 + 0.2 * math.sin(t * 70))
        elif kind == "leaf":
            envelope = math.sin(math.pi * u) ** 2 * (0.5 + 0.5 * math.sin(t * 54) ** 2)
            value = (low * 0.3 + high * 0.25) * envelope
        elif kind == "sticky":
            value = (low * 0.5 + high * 0.08) * math.sin(math.pi * u) ** 2 * (0.5 + 0.5 * math.sin(t * 37))
        elif kind == "wing":
            value = (low * 0.4 + high * 0.035) * (0.6 + 0.4 * math.sin(t * math.tau * 43))
            value += 0.04 * math.sin(t * math.tau * 86) * (1 + 0.15 * math.sin(t * math.tau * 3))
        elif kind == "water":
            value = low * math.exp(-u * 7) * 0.4
            value += math.sin(math.tau * (800 * t - 600 * t * t)) * math.exp(-u * 12) * 0.2
        elif kind == "switch":
            value = high * math.exp(-u * 32) + math.sin(t * math.tau * 420) * math.exp(-u * 22) * 0.2
        elif kind == "paper":
            flutter = 0.25 + 0.75 * math.sin(t * 97 + math.sin(t * 41)) ** 6
            value = (high * 0.27 + low * 0.35) * math.sin(math.pi * u) ** 1.5 * flutter
        else:
            value = low * math.exp(-u * 9)
        samples.append(value)
    fade = min(180, len(samples) // 2)
    for i in range(fade):
        samples[i] *= i / fade
        samples[-1 - i] *= i / fade
    return samples


def build_paper(clap):
    for variant in range(1, 4):
        rustle = noise_foley(0.22 + variant * 0.012, 110 + variant, "paper")
        swish = noise_foley(len(rustle) / RATE, 120 + variant, "swing")
        write(f"paper_swing_{variant}", [a + b * 0.35 for a, b in zip(rustle, swish)], 0.27, room=True)
        crumple = noise_foley(0.26, 130 + variant, "paper")
        slap = resample(clap, 0.86 + variant * 0.035)
        low = 0.0
        impact = []
        for i, paper in enumerate(crumple):
            low += ((slap[i] if i < len(slap) else 0) - low) * 0.08
            t = i / RATE
            thud = math.sin(t * math.tau * (170 + variant * 12)) * math.exp(-t * 45) * 0.075
            impact.append(low * 0.8 + paper * 0.42 + thud)
        write(f"paper_hit_{variant}", impact, 0.48, room=True)


def main():
    clap = recording("clap")
    peak = max(range(len(clap)), key=lambda i: abs(clap[i]))
    clap = clap[max(0, peak - int(RATE * 0.012)):peak + int(RATE * 0.25)]
    build_paper(clap)
    if "--paper-only" in sys.argv:
        print("Built six original paper rustle and dull tap variants")
        return
    sparks = recording("sparks")
    # Pick separated sharp transients from the actual high-voltage recording.
    spark_peaks = []
    candidates = sorted(range(0, len(sparks), 180), key=lambda i: abs(sparks[i]), reverse=True)
    for index in candidates:
        if all(abs(index - p) > RATE * 0.6 for p in spark_peaks):
            spark_peaks.append(index)
        if len(spark_peaks) == 3:
            break
    for variant in range(1, 4):
        speed = [0.97, 1.02, 1.06][variant - 1]
        write(f"hand_hit_{variant}", resample(clap, speed), 0.76, room=True)
        swing = noise_foley(0.19 + variant * 0.015, variant, "swing")
        write(f"hand_miss_{variant}", list(swing), 0.26)
        write(f"swing_{variant}", list(swing), 0.32, room=True)
        # Plastic mesh contact has a softer, shorter body than bare palms.
        slap = resample(clap, 1.24 + variant * 0.03)
        write(f"swatter_hit_{variant}", slap, 0.52, room=True)
        index = spark_peaks[variant - 1]
        zap = sparks[max(0, index - int(RATE * 0.004)):index + int(RATE * 0.16)]
        write(f"zap_{variant}", zap, 0.72, room=True)
        write(f"flytrap_{variant}", noise_foley(0.29, 20 + variant, "leaf"), 0.23, room=True)
        write(f"sundew_{variant}", noise_foley(0.34, 30 + variant, "sticky"), 0.18)
        write(f"nursery_{variant}", noise_foley(0.19, 40 + variant, "water"), 0.16)
        write(f"dragonfly_{variant}", noise_foley(0.22, 50 + variant, "wing"), 0.22)
        write(f"purchase_{variant}", noise_foley(0.09, 60 + variant, "switch"), 0.45, room=True)
    write("mosquito_loop", loop_excerpt(recording("mosquito"), 4, 2), 0.5)
    write("dragonfly_loop", loop_excerpt(noise_foley(3, 82, "wing"), 2.5, 0), 0.25)
    if (ROOT / "source" / "fan.mp3").exists():
        fan = loop_excerpt(recording("fan"), 4, 10)
    else:
        fan = loop_excerpt(noise_foley(4.5, 90, "wing"), 4, 0)
    write("fan_loop", fan, 0.48)
    for variant in range(1, 4):
        intake = list(fan[:int(0.48 * RATE)])
        for i in range(len(intake)):
            intake[i] *= math.sin(math.pi * i / len(intake)) ** 1.2
        write(f"trap_{variant}", resample(intake, 0.94 + variant * 0.03), 0.46, room=True)
    files = list(ROOT.glob("*.wav"))
    print(f"Built {len(files)} mono 44.1 kHz effects and seamless room loops")


if __name__ == "__main__":
    main()
