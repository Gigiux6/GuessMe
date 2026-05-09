import math
import wave
import struct
import os

def generate_tone(filename, frequency, duration, volume=0.5):
    sample_rate = 44100
    num_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            value = int(volume * math.sin(2.0 * math.pi * frequency * t) * 32767.0)
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

def generate_noise(filename, duration, volume=0.3):
    import random
    sample_rate = 44100
    num_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            # fade out
            env = 1.0 - (i / num_samples)
            value = int(volume * env * random.uniform(-1, 1) * 32767.0)
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

os.makedirs('assets/audio', exist_ok=True)
generate_tone('assets/audio/ding.wav', 1200, 0.2)
generate_noise('assets/audio/whoosh.wav', 0.4)
print("Audio files generated.")
