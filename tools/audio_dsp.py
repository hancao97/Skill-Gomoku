"""Small, deterministic mastering helpers for embedded game recordings."""
import subprocess
import numpy as np

RATE = 48000


def true_peak(a):
    """Measure reconstructed peaks using 4x sinc resampling, including stereo channels."""
    result = subprocess.run(
        ['ffmpeg', '-v', 'error', '-f', 'f32le', '-ar', str(RATE), '-ac', '2',
         '-i', 'pipe:0', '-af', 'aresample=192000:filter_size=64', '-f', 'f32le', 'pipe:1'],
        input=a.astype('<f4').tobytes(), capture_output=True, check=True)
    return float(np.max(np.abs(np.frombuffer(result.stdout, '<f4'))))


def safe_peak(a, ceiling_db=-2.0):
    """Reserve reconstruction headroom without compression or waveform clipping."""
    maximum = true_peak(a)
    return a * min(1.0, 10 ** (ceiling_db / 20) / max(maximum, 1e-9))


def pcm_import(path):
    """Short impacts stay lossless in Godot, with automatic normalization disabled."""
    settings = path.with_suffix('.wav.import')
    if settings.exists():
        text = settings.read_text()
        text = text.replace('compress/mode=2', 'compress/mode=0')
        text = text.replace('compress/mode=1', 'compress/mode=0')
        settings.write_text(text)
