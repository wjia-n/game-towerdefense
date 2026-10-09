import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Tower Defense — all sounds synthesized in code as
/// WAV bytes. No asset files. Chunky physical toy sounds: wooden thunks,
/// brass clanks, bow twangs, cannon booms.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class TDAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  TDAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _knock({double base = 170}) {
    // Wooden thunk: low thump + short click.
    final n = (_rate * 0.14).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.005) *
          (0.9 * sin(2 * pi * base * t) * exp(-t * 30) +
              0.5 * sin(2 * pi * base * 2 * t) * exp(-t * 55) +
              0.25 * (_rand.nextDouble() * 2 - 1) * exp(-t * 120));
    }
    return out;
  }

  List<double> _boom() {
    // Cannon boom: deep sine drop + noise burst.
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = 90 - 55 * (i / n);
      out[i] = _env(i, n, attack: 0.004) *
          (0.95 * sin(2 * pi * f * t) * exp(-t * 9) +
              0.4 * (_rand.nextDouble() * 2 - 1) * exp(-t * 22));
    }
    return out;
  }

  List<double> _twang() {
    // Bowstring twang: bright pluck, fast decay.
    final n = (_rate * 0.18).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.7 * sin(2 * pi * 520 * t) * exp(-t * 40) +
              0.4 * sin(2 * pi * 880 * t) * exp(-t * 60) +
              0.2 * sin(2 * pi * 240 * t));
    }
    return out;
  }

  List<double> _coin() {
    // Gold coin: two bright pings.
    final n = (_rate * 0.22).round();
    final out = List<double>.filled(n, 0);
    final a = _tone(1318.5, 0.1);
    final b = _tone(1760.0, 0.16);
    for (int i = 0; i < a.length && i < n; i++) {
      out[i] += a[i] * 0.6;
    }
    for (int i = 0; i < b.length && i + a.length ~/ 2 < n; i++) {
      out[i + a.length ~/ 2] += b[i] * 0.6;
    }
    return out;
  }

  List<double> _horn() {
    // Wave horn: low brass call.
    final n = (_rate * 0.7).round();
    final out = List<double>.filled(n, 0);
    final a = _tone(196.0, 0.32, harmonics: 0.45);
    final b = _tone(261.63, 0.4, harmonics: 0.45);
    for (int i = 0; i < a.length && i < n; i++) {
      out[i] += a[i] * 0.7;
    }
    for (int i = 0; i < b.length && i + a.length - 600 < n; i++) {
      out[i + a.length - 600] += b[i] * 0.7;
    }
    return out;
  }

  List<double> _shimmer() {
    // Frost shimmer: descending glassy sparkle.
    final n = (_rate * 0.3).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = 2400 - 1200 * (i / n);
      out[i] = _env(i, n, attack: 0.01) *
          (0.4 * sin(2 * pi * f * t) + 0.2 * sin(2 * pi * f * 1.5 * t));
    }
    return out;
  }

  List<double> _zap() {
    // Tesla crackle.
    final n = (_rate * 0.2).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003) *
          (0.5 * (_rand.nextDouble() * 2 - 1) * exp(-t * 50) *
                  sin(2 * pi * 1400 * t) +
              0.35 * sin(2 * pi * (700 + 500 * (i / n)) * t) * exp(-t * 30));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Warm C – G – Am – F folk pad, 16s loop.
        final seq = [
          [261.63, 329.63, 392.0], // C
          [196.0, 246.94, 293.66], // G
          [220.0, 261.63, 329.63], // Am
          [174.61, 220.0, 261.63], // F
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Marching drum-ish pulse under a brave horn-ish melody, 16s loop.
        final n = (_rate * 16).round();
        final out = List<double>.filled(n, 0);
        // Low pulse every half second.
        for (int k = 0; k < 32; k++) {
          final start = (n * k / 32).round();
          final thump = _knock(base: 90);
          for (int i = 0; i < thump.length && start + i < n; i++) {
            out[start + i] += thump[i] * 0.35;
          }
        }
        // Heroic melody line.
        final melody = [
          329.63, 329.63, 392.0, 440.0, 440.0, 392.0, 329.63, 293.66,
          261.63, 261.63, 293.66, 329.63, 329.63, 293.66, 261.63, 0.0,
        ];
        for (int k = 0; k < melody.length; k++) {
          if (melody[k] <= 0) continue;
          final start = (n * k / melody.length).round();
          final tone = _tone(melody[k], 0.7, harmonics: 0.35);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.28;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> place() => _play(_clip('place', () => _knock(base: 190)));
  Future<void> upgrade() =>
      _play(_clip('upgrade', () => _tone(330, 0.18, freqEnd: 660)));
  Future<void> sell() =>
      _play(_clip('sell', () => _tone(660, 0.14, freqEnd: 330)));
  Future<void> shoot() => _play(_clip('shoot', _twang));
  Future<void> cannon() => _play(_clip('cannon', _boom));
  Future<void> frost() => _play(_clip('frost', _shimmer));
  Future<void> zap() => _play(_clip('zap', _zap));
  Future<void> gold() => _play(_clip('gold', _coin));
  Future<void> waveHorn() => _play(_clip('horn', _horn));
  Future<void> breach() => _play(_clip('breach', () => _boom()));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
