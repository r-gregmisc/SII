import numpy as np

def calculate_loudness_chen2011(inputF, inputLdB, HLcf, HLohcdB0, HLihcdB0, outerearcorrection='FreeField'):
    # f2erbrate
    def f2erbrate(f): return 21.4 * np.log10(4.37 * f/1000 + 1)
    def erbrate2f(c): return 1000 * (10**(c/21.4) - 1) / 4.37
    
    flow = 50; fhigh = 15000; cambin = 0.1
    Cam = np.arange(f2erbrate(flow), f2erbrate(fhigh) + cambin, cambin)
    CF = erbrate2f(Cam)
    
    HLohcdB = np.interp(CF, HLcf, HLohcdB0)
    HLihcdB = np.interp(CF, HLcf, HLihcdB0)
    HLohcdB = np.maximum(HLohcdB, 0)
    HLihcdB = np.maximum(HLihcdB, 0)
    
    if outerearcorrection == 'FreeField':
        freefield_F = np.array([0, 20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 750, 800, 1000, 1250, 1500, 1600, 2000, 2500, 3000, 3150, 4000, 5000, 6000, 6300, 8000, 9000, 10000, 11200, 12500, 14000, 15000, 16000, 20000])
        freefield_dB = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0.1, 0.3, 0.5, 0.9, 1.4, 1.6, 1.7, 2.5, 2.7, 2.6, 2.6, 3.2, 5.2, 6.6, 12, 16.8, 15.3, 15.2, 14.2, 10.7, 7.1, 6.4, 1.8, -0.9, -1.6, 1.9, 4.9, 2, -2, 2.5, 2.5])
        inputLdB = inputLdB + np.interp(inputF, freefield_F, freefield_dB)
        
    MidEar_F = np.array([20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 750, 800, 1000, 1250, 1500, 1600, 2000, 2500, 3000, 3150, 4000, 5000, 6000, 6300, 8000, 9000, 10000, 11200, 12500, 14000, 15000, 16000, 20000])
    MidEar_dB = np.array([-33.2, -28.2, -23.2, -19.4, -16.3, -13.3, -10.2, -8.0, -6.1, -4.7, -3.5, -2.8, -2.4, -1.9, -1.8, -2.1, -2.5, -2.3, -2.6, -3.7, -5.5, -6.7, -11.4, -14.5, -11.5, -11.0, -10.5, -10.8, -12.8, -13.6, -16.5, -15.8, -15.0, -16.9, -18.8, -20.7, -21.9, -22.3, -24.1])
    
    inputLdB = inputLdB + np.interp(inputF, MidEar_F, MidEar_dB)
    inputL = 10**(inputLdB/10)
    
    tl = CF / (0.1084*CF + 2.3301)
    tu = np.full(len(CF), 15.0)
    
    E_pf = np.zeros(len(CF))
    for i in range(len(CF)):
        g = inputF/CF[i] - 1
        indexl = (g < 0)
        gl = np.abs(g[indexl])
        E_pf[i] = np.sum((1 + gl*tl[i]) * np.exp(-gl*tl[i]) * inputL[indexl])
        
        indexu = (g >= 0)
        gu = g[indexu]
        E_pf[i] += np.sum((1 + gu*tu[i]) * np.exp(-gu*tu[i]) * inputL[indexu])
        
    E_pf = np.maximum(E_pf, 10**-10)
    EdB_pf = 10*np.log10(E_pf)
    EdB_pf = np.maximum(EdB_pf, 0)
    
    GdBmax = CF / (0.0191*CF + 1.1) - HLohcdB
    GdB = GdBmax * (1 - 1/(1+np.exp(-0.05*(EdB_pf-(100-GdBmax)))) + 1/(1+np.exp(-0.05*(0-(100-GdBmax)))))
    index = (EdB_pf > 30)
    GdB[index] = GdB[index] - 0.003 * (EdB_pf[index]-30)**2
    
    GdB = np.clip(GdB, -20, GdBmax)
    G = 10**(GdB/10)
    
    pl = CF / (0.0272*CF + 5.4365)
    pu = np.full(len(CF), 27.9)
    
    E_af = np.zeros(len(CF))
    for i in range(len(CF)):
        g = inputF/CF[i] - 1
        indexl = (g < 0)
        gl = np.abs(g[indexl])
        E_af[i] = G[i] * np.sum((1 + gl*pl[i]) * np.exp(-gl*pl[i]) * inputL[indexl])
        
        indexu = (g >= 0)
        gu = g[indexu]
        E_af[i] += G[i] * np.sum((1 + gu*pu[i]) * np.exp(-gu*pu[i]) * inputL[indexu])
        
    E = E_pf + E_af
    E = np.maximum(E, 10**-10)
    EdB = 10*np.log10(E)
    
    EdB = EdB - HLihcdB * (1 - 0.5/(1+np.exp(-0.2*((EdB-52)-(HLihcdB+20)))))
    E = 10**(EdB/10)
    
    Ldn = np.sum(E) * cambin * 1.525e-8
    return Ldn

inputF = np.arange(20, 15001)
# Create a flat 30 dB/Hz spectrum density (which corresponds to roughly 65 dB SPL overall speech)
inputLdB_normal = np.full(len(inputF), 30.0)

hl_freqs = np.array([250, 500, 1000, 2000, 4000, 8000])
normal_hl = np.zeros(6)

print("Normal hearing, 30 dB/Hz input:", calculate_loudness_chen2011(inputF, inputLdB_normal, hl_freqs, normal_hl, normal_hl))

# Simulate DSL v5.0 with A-1 audiogram
# A-1 threshold: 15, 20, 30, 40, 50, 60
a1_hl = np.array([15, 20, 30, 40, 50, 60])
ohc_loss = np.minimum(0.9 * a1_hl, 57.6)
ihc_loss = np.maximum(a1_hl - ohc_loss, 0)

# DSL v5.0 gives about 18 dB gain at 1kHz. Let's add 18 dB to input
inputLdB_dsl = np.full(len(inputF), 30.0 + 18.0)
print("A-1 hearing, 48 dB/Hz input (DSL):", calculate_loudness_chen2011(inputF, inputLdB_dsl, hl_freqs, ohc_loss, ihc_loss))

# NAL-NL2 gives about 10 dB gain at 1kHz. Let's add 10 dB to input
inputLdB_nal = np.full(len(inputF), 30.0 + 10.0)
print("A-1 hearing, 40 dB/Hz input (NAL):", calculate_loudness_chen2011(inputF, inputLdB_nal, hl_freqs, ohc_loss, ihc_loss))
