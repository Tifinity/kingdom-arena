// npm install --prefix /tmp/arena-sfx jsfxr@1.4.1
// JSFXR_DIR=/tmp/arena-sfx/node_modules/jsfxr node tools/export_roster_skill_audio.cjs
const { readFileSync, writeFileSync } = require('node:fs');
const { join, resolve } = require('node:path');
const { Params, SoundEffect } = require(process.env.JSFXR_DIR ? resolve(process.env.JSFXR_DIR) : 'jsfxr');

const directory = join(__dirname, '../assets/audio/skills');
const { shared, layered } = JSON.parse(readFileSync(join(directory, 'sources.json'), 'utf8'));
const samples = milliseconds => Math.round(milliseconds * shared.sample_rate / 1000);
const stems = new Map();

// The Jsfxr noise oscillator reads Math.random. Seed it per stem for repeatable exports.
function stem(name) {
  if (!stems.has(name)) {
    const random = Math.random;
    let seed = Array.from(name).reduce((hash, char) => (hash * 31 + char.charCodeAt(0)) >>> 0, 1);
    Math.random = () => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed / 0x100000000;
    };
    try {
      const params = Object.assign(new Params(), shared, layered.stems[name]);
      stems.set(name, new SoundEffect(params).getRawBuffer().normalized);
    } finally {
      Math.random = random;
    }
  }
  return stems.get(name);
}

for (const [name, layers] of Object.entries(layered.clips)) {
  if (!name.startsWith('roster_')) continue;
  const mix = new Float64Array(Math.max(...layers.map(layer => samples(layer.offset_ms) + samples(layer.length_ms))));
  for (const layer of layers) {
    const offset = samples(layer.offset_ms);
    const data = Array.from(stem(layer.stem).slice(0, samples(layer.length_ms)));
    for (let i = 0; i < data.length; i++) {
      data[i] *= Math.min(1, i / samples(layered.fade_in_ms), (data.length - 1 - i) / samples(layered.fade_out_ms));
    }
    const gain = layer.peak / Math.max(...data.map(Math.abs));
    data.forEach((sample, i) => { mix[offset + i] += sample * gain; });
  }
  const peak = Math.max(...mix.map(Math.abs));
  if (!(peak > 0 && peak < 1)) throw new Error(`${name}: invalid peak ${peak}`);
  const wav = Buffer.alloc(44 + 2 * mix.length);
  wav.write('RIFF', 0);
  wav.writeUInt32LE(wav.length - 8, 4);
  wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(shared.sample_rate, 24);
  wav.writeUInt32LE(shared.sample_rate * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36);
  wav.writeUInt32LE(2 * mix.length, 40);
  mix.forEach((sample, i) => wav.writeInt16LE(Math.round(sample * 32767), 44 + 2 * i));
  writeFileSync(join(directory, name + '.wav'), wav);
  console.log(`${name}: ${(1000 * mix.length / shared.sample_rate).toFixed(0)} ms, ${(20 * Math.log10(peak)).toFixed(1)} dBFS`);
}
