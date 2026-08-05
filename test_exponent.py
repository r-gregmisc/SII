import numpy as np

def test_loudness(inputLdB, HLohcdB, HLihcdB):
    CF = np.array([250, 500, 1000, 2000, 4000, 8000])
    # Assume 1 band for simplicity
    CF = np.array([1000])
    inputL = 10**(inputLdB/10)
    
    # Active gain
    GdBmax = CF / (0.0191*CF + 1.1) - HLohcdB
    GdBmax = np.maximum(GdBmax, 0)
    EdB_pf = inputLdB
    GdB = GdBmax * (1 - 1/(1+np.exp(-0.05*(EdB_pf-(100-GdBmax)))) + 1/(1+np.exp(-0.05*(0-(100-GdBmax)))))
    index = (EdB_pf > 30)
    GdB[index] = GdB[index] - 0.003 * (EdB_pf[index]-30)**2
    GdB = np.clip(GdB, -20, GdBmax)
    G = 10**(GdB/10)
    
    # Total E
    E_pf = inputL
    E_af = G * inputL
    E = E_pf + E_af
    
    # Convert E to loudness
    L_chen = E * 1.525e-8
    L_moore = (E**0.2) * 0.5 # arbitrary C
    return L_chen[0], L_moore[0]

print("Normal 65 dB:")
c1, m1 = test_loudness(65, 0, 0)
print(c1, m1)

print("Aided 91 dB (50 dB HL):")
c2, m2 = test_loudness(91, 50, 0)
print(c2, m2)

print("Ratios (Aided / Normal):")
print("Chen Ratio:", c2/c1)
print("Moore Ratio:", m2/m1)
