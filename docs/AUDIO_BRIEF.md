# Audio brief

The current audio director is wiring only. It records track and event requests and remains silent when no asset is assigned. Future audio files can be added without changing progression rules.

## Sound character

The opening should feel empty, close and physical. Avoid heroic space music, busy arpeggios and constant high-frequency sparkle. Leave room for the movement of individual grains. As the body gains structure, add harmonic weight and a wider stereo field. Save the largest dynamic and spectral change for ignition.

## Passive tracks

### Void breath

- Cue ID: `music.void`
- Use: new game through the first loose material
- Form: a seamless 45 to 70 second loop
- Sound: very low air, distant filtered movement and one slow tonal centre
- Rhythm: no beat and no obvious bar line
- Mix target: quiet enough that single-grain events remain clear

### First matter

- Cue ID: `music.first_matter`
- Use: stable loose mass through first compaction readiness
- Form: a seamless 60 to 90 second loop with separate low, tonal and texture stems
- Sound: sparse pulses derived from the Core tone, with long gaps
- Transition: crossfade from `music.void` over 2 to 4 seconds

### Gravitational seed

- Cue ID: `music.gravitational_seed`
- Use: after the first permanent layer
- Sound: add a slow repeating motion and a wider field without becoming a conventional song
- Transition: the first compaction event supplies the downbeat, then the loop fades in

## Event cues

- `event.release_grain`: a soft granular flick, 100 to 250 ms, with several pitch and texture variants.
- `event.first_settle`: a muted contact with a short low tail. It should not sound metallic.
- `event.objective_complete`: a restrained two-note rise, about 0.8 seconds. It must survive frequent early use.
- `event.core_assimilate`: a centred low pulse followed by a filtered harmonic opening, about 1 second.
- `event.talent_unlock`: a clean ring with a small harmonic bloom, about 1.5 seconds.
- `event.first_compaction`: one body-scale sub impact, a controlled inward rush and a 2 to 3 second settling tail.
- `event.stellar_ignition`: a future 4 to 5 second transition with a short pre-ignition drop, a bright expansion and a lasting change into the stellar music set.

## Delivery format

Provide 48 kHz, 24-bit WAV masters. Loops need exact loop points and two complete rendered cycles for checking. Supply stems where noted. Keep event tails in the files. Use the cue ID as the filename prefix and add variant numbers such as `event.release_grain.01.wav`.

Record intended integrated loudness and peak values with each delivery. The game will still apply runtime mixing, but consistent masters make the dev dials useful.
