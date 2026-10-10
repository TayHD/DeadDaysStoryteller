// Dead Days audio toolkit: synthesises radio SFX and applies a handheld-radio
// filter to voice lines. Compiled on the fly by the PowerShell tools.
using System;
using System.IO;

public static class DdsAudio
{
    static Random rng = new Random(1993);

    public static void WriteWav(string path, float[] s, int rate)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        using (var fs = new FileStream(path, FileMode.Create))
        using (var w = new BinaryWriter(fs))
        {
            int bytes = s.Length * 2;
            w.Write(new char[] { 'R', 'I', 'F', 'F' }); w.Write(36 + bytes);
            w.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate * 2);
            w.Write((short)2); w.Write((short)16);
            w.Write(new char[] { 'd', 'a', 't', 'a' }); w.Write(bytes);
            foreach (float v in s)
            {
                float c = Math.Max(-1f, Math.Min(1f, v));
                w.Write((short)(c * 32000));
            }
        }
    }

    // Raw 16-bit little-endian mono PCM (ElevenLabs pcm_* output) -> floats.
    public static float[] FromPcm16(byte[] pcm)
    {
        var s = new float[pcm.Length / 2];
        for (int i = 0; i < s.Length; i++) s[i] = BitConverter.ToInt16(pcm, i * 2) / 32768f;
        return s;
    }

    // One-pole filters, chained for a rough band-pass.
    static void HighPass(float[] s, int rate, double hz)
    {
        double rc = 1.0 / (2 * Math.PI * hz), dt = 1.0 / rate, a = rc / (rc + dt);
        float prevIn = 0, prevOut = 0;
        for (int i = 0; i < s.Length; i++)
        {
            float o = (float)(a * (prevOut + s[i] - prevIn));
            prevIn = s[i]; prevOut = o; s[i] = o;
        }
    }

    static void LowPass(float[] s, int rate, double hz)
    {
        double rc = 1.0 / (2 * Math.PI * hz), dt = 1.0 / rate, a = dt / (rc + dt);
        float prev = 0;
        for (int i = 0; i < s.Length; i++) { prev = (float)(prev + a * (s[i] - prev)); s[i] = prev; }
    }

    static float[] Noise(int n)
    {
        var s = new float[n];
        for (int i = 0; i < n; i++) s[i] = (float)(rng.NextDouble() * 2 - 1);
        return s;
    }

    static void Band(float[] s, int rate, double lo, double hi)
    {
        HighPass(s, rate, lo); HighPass(s, rate, lo);
        LowPass(s, rate, hi); LowPass(s, rate, hi);
    }

    static void Normalize(float[] s, float peak)
    {
        float m = 0.0001f;
        foreach (float v in s) m = Math.Max(m, Math.Abs(v));
        for (int i = 0; i < s.Length; i++) s[i] = s[i] / m * peak;
    }

    static float[] Concat(params float[][] parts)
    {
        int n = 0; foreach (var p in parts) n += p.Length;
        var o = new float[n]; int k = 0;
        foreach (var p in parts) { Array.Copy(p, 0, o, k, p.Length); k += p.Length; }
        return o;
    }

    static float[] Silence(int rate, double sec) { return new float[(int)(rate * sec)]; }

    // Key-up click: a sharp transient with a tiny ring.
    static float[] Click(int rate)
    {
        int n = (int)(rate * 0.035);
        var s = new float[n];
        for (int i = 0; i < n; i++)
        {
            double t = (double)i / rate;
            s[i] = (float)(Math.Exp(-t * 260) * (Math.Sin(2 * Math.PI * 2100 * t) * 0.6 + (rng.NextDouble() * 2 - 1) * 0.5));
        }
        return s;
    }

    // Squelch: band-limited noise with a fast attack and a decay.
    static float[] Squelch(int rate, double sec, double decay)
    {
        int n = (int)(rate * sec);
        var s = Noise(n);
        Band(s, rate, 450, 3200);
        Normalize(s, 1f);
        for (int i = 0; i < n; i++)
        {
            double t = (double)i / rate;
            double env = Math.Min(1.0, t / 0.008) * Math.Exp(-t * decay);
            s[i] = (float)(s[i] * env);
        }
        return s;
    }

    static float[] Tone(int rate, double hz, double sec, float amp)
    {
        int n = (int)(rate * sec);
        var s = new float[n];
        for (int i = 0; i < n; i++)
        {
            double t = (double)i / rate;
            double env = Math.Min(1.0, t / 0.005) * Math.Min(1.0, (sec - t) / 0.01);
            s[i] = (float)(Math.Sin(2 * Math.PI * hz * t) * amp * env);
        }
        return s;
    }

    static void Mix(float[] dst, float[] src, int at, float gain)
    {
        for (int i = 0; i < src.Length && at + i < dst.Length; i++) dst[at + i] += src[i] * gain;
    }

    // Static bed: hiss with random crackles, seamless enough to loop.
    static float[] StaticBed(int rate, double sec)
    {
        int n = (int)(rate * sec);
        var s = Noise(n);
        Band(s, rate, 600, 3000);
        Normalize(s, 0.35f);
        for (int c = 0; c < (int)(sec * 14); c++)
        {
            int at = rng.Next(n - rate / 50);
            var crackle = Click(rate);
            Mix(s, crackle, at, (float)(0.2 + rng.NextDouble() * 0.5));
        }
        // Fade the ends a touch so the loop point doesn't pop.
        int f = rate / 50;
        for (int i = 0; i < f; i++) { float g = (float)i / f; s[i] *= g; s[n - 1 - i] *= g; }
        return s;
    }

    public static void MakeSfx(string dir)
    {
        int r = 22050;
        WriteWav(Path.Combine(dir, "dds_radio_open.wav"), Concat(Click(r), Squelch(r, 0.32, 9)), r);
        WriteWav(Path.Combine(dir, "dds_radio_close.wav"), Concat(Squelch(r, 0.22, 14), Silence(r, 0.02), Click(r)), r);
        WriteWav(Path.Combine(dir, "dds_radio_static.wav"), StaticBed(r, 3.0), r);

        // Incoming call: squelch break, then two short two-tone chirps over hiss.
        var call = new float[(int)(r * 1.25)];
        Mix(call, Squelch(r, 0.25, 10), 0, 0.8f);
        var bed = StaticBed(r, 1.25); Mix(call, bed, 0, 0.35f);
        int at = (int)(r * 0.28);
        for (int k = 0; k < 2; k++)
        {
            Mix(call, Tone(r, 1250, 0.09, 0.55f), at, 1f);
            Mix(call, Tone(r, 1650, 0.09, 0.55f), at + (int)(r * 0.1), 1f);
            at += (int)(r * 0.38);
        }
        Mix(call, Click(r), call.Length - Click(r).Length - 10, 0.8f);
        WriteWav(Path.Combine(dir, "dds_radio_incoming.wav"), call, r);
    }

    // Handheld radio treatment for a voice line: narrow band, a little grit,
    // a squelch at each end and a low hiss under the speech.
    public static float[] RadioVoice(float[] voice, int rate)
    {
        var v = (float[])voice.Clone();
        Band(v, rate, 320, 3300);
        Normalize(v, 0.9f);
        for (int i = 0; i < v.Length; i++)
        {
            double x = v[i] * 1.6;
            v[i] = (float)(Math.Tanh(x) * 0.8);
        }
        var hiss = Noise(v.Length); Band(hiss, rate, 900, 3000); Normalize(hiss, 0.035f);
        for (int i = 0; i < v.Length; i++) v[i] += hiss[i];
        return Concat(Squelch(rate, 0.12, 20), v, Squelch(rate, 0.16, 16));
    }

    // In-person voice: just trim the level so lines sit under game audio.
    public static float[] PlainVoice(float[] voice)
    {
        var v = (float[])voice.Clone();
        Normalize(v, 0.85f);
        return v;
    }
}
