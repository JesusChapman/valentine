# Stand By audio ring

The ring uses a native transparent `MTKView`, not a SwiftUI animation of nested
paths. `AudioRingParticles.metal` generates a regular sheet of particles, moves
it through a continuous four-dimensional fractal noise field, then projects it
onto a soft spherical shell. Projected overlaps accumulate into a floating-point
density texture. A Gaussian bloom and exposure pass produce the luminous folds.
The app's artwork background remains visible through the result.

## References and implementation

- https://github.com/Roonil/NCS_Spectrum_GLava
- https://github.com/Roonil/WayVes
- https://roonil.github.io/shaders/ncs/overview/

The visual baseline uses continuous four-dimensional vector value noise and a
wide particle sheet, with a second, weaker frequency for fine folds. The former
GLava-style spectral-contrast transfer is replaced by independent rhythmic and
vocal-band envelopes, following the requested size/voice mapping.

The subsequent gradient-Perlin experiment was visually rejected and is no longer
used by the shader. Its narrower sheet, different projection and audio gain were
changed together, so the regression cannot be attributed to Perlin noise alone.
`AudioRingPerlin.h` retains that unused MIT-licensed implementation and notice.

The membrane now uses a broader spatial field (1.65), a weaker detail octave,
and restrained XYZ displacement before projection. Depth has a 1.65 multiplier so
front/back sheets project into the interior, overlapping instead of remaining a
nearly planar circumference. The field advects vertically to carry folds through
the sphere. This depth calibration is deliberate, not GLava's original XYZ ratio.

The particle fade is evaluated on the source sheet, not displaced XYZ distance:
the latter discarded deep folds just as they entered the interior. Spherical
projection bounds the result. Radius uses 0.12 bass gain, 0.07 full-band intensity
gain and 0.055 onset gain, unchanged by vocal-phrasing tuning. Fold displacement
uses `0.085 + 0.70*v + 0.25*v*v`, with `v` bounded to 0–0.82. This retains quiet
folds and emphasizes stronger syllables without the former exaggerated 1.45 gain.
There is no percussion onset injection. Fine detail follows the vocal envelope.
The low-latency FFT sampling and GPU optimizations remain unchanged.

This is an approximation, not a pixel-identical GLava port. Noise, FFT calibration,
particle accumulation, bloom and tint differ. The user's supplied recording shows
the GLava browser demo, not the rejected Valentine render; it is a target reference,
not evidence of the appearance or frame rate of the app itself.

## Audio and lifecycle

- FFT data comes from the app's decoded audio, sampled at AVPlayer's current time.
- The first second of decoded spectrum is published immediately; later batches
  arrive while analysis continues. Track-generation checks reject stale batches.
- The FFT has no temporal smoothing: only the renderer applies attack/release.
  Windows are sampled at their centers on the playback clock.
- Log-spectrum values are recovered as linear amplitudes with slow peak-gain
  recovery. Low-band maxima, full-band RMS and a short onset envelope drive size.
  Folds use weighted RMS of bands 6–17 (roughly 210–3800 Hz), tapered at the edges.
  They use linear amplitudes before global normalization, with an independent
  slow reference (0.8 s rise, 5 s fall) and bounded soft knee. This avoids cancelling
  a louder syllable by immediately increasing its normalization denominator.
  This estimates vocal-band intensity; it does not isolate the singer. Guitars,
  keyboards and other instruments in that band will also deform the membrane.
- Rhythm attacks are 4–15 ms and releases 55–110 ms. Vocal-band folds have a
  22 ms attack and 100 ms release to open and retract between syllables.
- Envelopes use elapsed time, not a fixed per-frame smoothing factor.
- Deformation retains headroom during dense passages rather than saturating at 1.
  Noise advection runs steadily; vocal-band energy directly shapes the membrane.
- Pausing freezes the current shape. Changing tracks clears the envelopes.
- Reduce Motion displays a static shell. Leaving Stand By detaches the renderer.
- The renderer targets 60 FPS, caps the drawable at 1024 pixels and the grid at
  448 × 448 particles, and allows at most one pending GPU command buffer to avoid
  queuing stale audio frames. Audio is sampled after acquiring the drawable.
- A 128 × 128 compute lattice evaluates the continuous noise field once per frame.
  Particle vertices linearly sample that field instead of independently repeating
  the noise calculation up to 200,704 times. Density and bloom stay full resolution.
- The ring inherits the artwork hue and uses the system accent without artwork.
  No new background gradient is introduced when artwork is missing.

## Regression checks

Run from the repository root with Xcode and its Metal toolchain available:

```sh
xcrun -sdk macosx metal -c Valentine/Views/Player/AudioRingParticles.metal -o /tmp/valentine-ring.air
xcrun -sdk macosx metallib /tmp/valentine-ring.air -o /tmp/valentine-ring.metallib
xcrun swiftc -O -swift-version 5 -parse-as-library -default-isolation MainActor \
  Valentine/Views/Player/AudioRingRenderer.swift \
  Valentine/Views/Player/AudioRingDynamics.swift Tests/AudioRingChecks.swift \
  -o /tmp/valentine-ring-check
/tmp/valentine-ring-check /tmp/valentine-ring.metallib /tmp
```

Checks cover envelope attack/decay, frame-rate independence, invalid input,
transparent corners, nonempty GPU output and distinct animation frames. Four
PNG snapshots are written to the supplied output directory for visual inspection.
An additional check holds bass and animation phase constant while changing the
mid/high spectrum: interior opacity must increase, preventing a regression to
radius-only animation. This numerical check complements visual sequence review;
it does not prove pixel-identical shapes or subjective similarity to GLava.
GPU timings include a 180-frame sequence with warm-frame median/p95 statistics.
They are offscreen measurements, not a guarantee of whole-app frame rate.

End-to-end rhythm regression (no GPU required):

```sh
xcrun swiftc -O -parse-as-library Valentine/Services/SpectrumAnalyzer.swift \
  Valentine/Views/Player/AudioRingDynamics.swift Tests/AudioRingRhythmChecks.swift \
  -o /tmp/valentine-ring-rhythm-check
/tmp/valentine-ring-rhythm-check
```

This generates opposite-phase stereo kicks and high-frequency pulses at 120,
180 and 240 BPM, at two amplitudes. It checks onset response within 50 ms,
separation between beats and no response during silence. This measures the
analysis/render-control chain, not physical speaker or AirPlay output latency.

Vocal-only alternating levels additionally verify repeated opening within 50 ms
and retraction within 150 ms, without a bass anchor to hide normalization errors.

Manual checks: switch tracks rapidly, seek, pause/resume, resize Stand By, toggle
the ring setting, test Reduce Motion, and play a track without artwork.

`Tests/AudioRingRecordedAudio.swift` adds an offline review with real audio. Compile
it with `SpectrumAnalyzer.swift`, `AudioRingDynamics.swift` and
`AudioRingRenderer.swift`, using the same Swift flags as the GPU check. Arguments:
`input.wav ring.metallib output.mp4 /absolute/path/to/ffmpeg`. It renders at 60 fps
using the app's FFT and window-center interpolation and muxes the input audio for
visual comparison. This is not a live presentation-rate or speaker-latency test.
