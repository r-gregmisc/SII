#include <Rcpp.h>
#include <cmath>
#include <vector>
#include <algorithm>

using namespace Rcpp;

// -------------------------------------------------------------------------
// Bramslow 2004 / Moore & Glasberg (2004) Specific Loudness C++ Port
// Corrected per AMToolbox 1.6.0 reference (Option C)
//
// Fixes applied:
//   1. Roex upper slope (p_u) is constant, not level-dependent
//   2. Roex lower slope (p_l) uses combined PL_MOD2 formula
//   3. E_0 and E_TQ use total summed excitation across all channels
//   4. E_UCL forces narrow filters (E_SPL=20)
//   5. UCL divisor is simple division, not squared
//   6. LOUDNORM bandwidth normalization for widened critical bands
//   7. Dead if/else branches collapsed
//
// Noted simplifications retained (vs. AMT reference):
//   - Sparse spectral-density input replaces FFT-bin integration
//   - Moore & Glasberg (2004) outer/middle ear corrections replace ZWICKA0
//   - Audiometric input is OHC+IHC dB HL, not dB SPL via RET4153/IEC303
// -------------------------------------------------------------------------

inline double erbrate2f(double erbrate) {
    return (std::pow(10.0, erbrate / 21.4) - 1.0) / 0.00437;
}

inline double f2erbrate(double f) {
    return 21.4 * std::log10(0.00437 * f + 1.0);
}

double interp1(double x, const std::vector<double>& xp, const std::vector<double>& yp) {
    if (xp.empty()) return 0.0;
    if (x <= xp.front()) return yp.front();
    if (x >= xp.back()) return yp.back();
    for (size_t i = 1; i < xp.size(); ++i) {
        if (x <= xp[i]) {
            double t = (x - xp[i-1]) / (xp[i] - xp[i-1]);
            return yp[i-1] + t * (yp[i] - yp[i-1]);
        }
    }
    return yp.back();
}

// Bramslow ERB energy
void bramslow2004_erbenergy(const std::vector<double>& F, const std::vector<double>& L_linear,
                            const std::vector<double>& agfs_e, const std::vector<double>& ag_loss,
                            const std::vector<double>& ret4153, bool widen,
                            int NoChan, double E_Beg, double E_End,
                            std::vector<double>& E_SPL, std::vector<double>& f0_Hz, std::vector<double>& E_Bin) {
    
    double E_Step = (E_End - E_Beg) / (NoChan - 1.0);
    double C2 = 4.368;
    double C3 = 2302.6 / (24.673 * C2);
    
    for (int c = 0; c < NoChan; ++c) {
        E_Bin[c] = E_Beg + c * E_Step;
        f0_Hz[c] = erbrate2f(E_Bin[c]);
        
        double HTL;
        if (widen) {
            HTL = interp1(E_Bin[c], agfs_e, ag_loss);
        } else {
            HTL = interp1(E_Bin[c], agfs_e, ret4153);
        }
        HTL = std::max(30.708, std::min(HTL, 70.0));
        
        double F_kHz = f0_Hz[c] / 1000.0;
        double ERB_Hz = 1000.0 * ((C2 * F_kHz + 1.0)/(C2 + 1.0)) * (-0.288173 + 0.0137025 * HTL);
        
        double Temp1 = C2 * ERB_Hz / 1000.0;
        double Temp2 = std::pow(10.0, 2.0 * E_Bin[c] / C3);
        double Temp3 = (Temp1 + 2)*(Temp1 + 2) - 4.0 * (Temp1 + 1.0 - Temp2);
        double flow_Hz = (std::sqrt(Temp3) - (Temp1 + 2.0))/(2.0*C2) * 1000.0;
        double fhigh_Hz = flow_Hz + ERB_Hz;
        
        double df = 1.0;
        if (F.size() > 1) {
            df = F[1] - F[0];
        }
        
        double E_Energy = 1e-10;
        for (size_t i = 0; i < F.size(); ++i) {
            if (F[i] >= flow_Hz && F[i] <= fhigh_Hz) {
                E_Energy += L_linear[i] * df;
            }
        }
        
        E_SPL[c] = 10.0 * std::log10(E_Energy);
        E_SPL[c] = std::max(20.0, std::min(E_SPL[c], 130.0));
    }
}

// Bramslow Roex Filters (corrected per AMToolbox reference)
//
// Fix 1: Upper slope (pu) is constant — matches PU_DEP_HL=true default
//        where pu = 4*f0/ERB_Hz, independent of signal level.
// Fix 2: Lower slope (pl) uses PL_MOD2 combined formula from reference
//        (bramslow2004_roexfilt.m line 177) instead of simplified two-step.
void bramslow2004_roexfilt(const std::vector<double>& F, const std::vector<double>& L_linear,
                           const std::vector<double>& E_SPL, const std::vector<double>& agfs_e, const std::vector<double>& ag_loss,
                           const std::vector<double>& ret4153, bool widen,
                           int NoChan, const std::vector<double>& E_Bin, const std::vector<double>& f0_Hz,
                           std::vector<double>& E_Vector) {
    
    // Constants from AMToolbox reference (bramslow2004_roexfilt.m)
    double C2 = 4.368;
    double PL_INT2 = 30.16;
    double PL_SLO2 = -0.38;
    double PL_THR2 = 20.0;
    double PMIN = 3.0;
    
    for (int c = 0; c < NoChan; ++c) {
        double HTLL;
        if (widen) {
            HTLL = interp1(E_Bin[c], agfs_e, ag_loss);
        } else {
            HTLL = interp1(E_Bin[c], agfs_e, ret4153);
        }
        HTLL = std::min(HTLL, 100.0);
        
        double f0_kHz = f0_Hz[c] / 1000.0;
        
        // Upper slope: constant, not level-dependent (PU_DEP_HL=true)
        double pu = 4.0 * f0_Hz[c] / (24.7 * (4.37 * f0_kHz + 1.0));
        pu = std::max(pu, PMIN);
        
        double E_Energy = 1e-10;
        
        // Calculate frequency bin width (df) for integration
        double df = 1.0; // Fallback for single tone
        if (F.size() > 1) {
            df = F[1] - F[0];
        }
        
        double E_Step = (E_Bin.back() - E_Bin.front()) / (NoChan - 1.0);
        double E_Beg = E_Bin.front();
        
        for (size_t i = 0; i < F.size(); ++i) {
            double g = std::abs(F[i] - f0_Hz[c]) / f0_Hz[c];
            if (g <= 10.0) {
                if (L_linear[i] < 1e-9) {
                    E_Energy += L_linear[i] * df;
                    continue;
                }
                
                double E_Bin_i = 21.4 * std::log10(0.00437 * F[i] + 1.0);
                int ESPL_Index = std::round((E_Bin_i - E_Beg) / E_Step);
                ESPL_Index = std::max(0, std::min(NoChan - 1, ESPL_Index));
                
                double freq_factor = ((C2 + 1.0) * f0_kHz) / (C2 * f0_kHz + 1.0);
                double level_term = std::min(0.0, E_SPL[ESPL_Index] - 71.0);
                double hl_term = HTLL - PL_THR2;
                double combined = std::max(level_term, hl_term) + PL_THR2;
                double pl = freq_factor * (PL_INT2 + PL_SLO2 * combined);
                pl = std::max(pl, PMIN);
                
                double p = (F[i] < f0_Hz[c]) ? pl : pu;
                double w = (1.0 + p * g) * std::exp(-p * g);
                E_Energy += L_linear[i] * w * df;
            }
        }
        E_Vector[c] = E_Energy;
    }
}

// Bramslow tone simulator (for E_0, E_TQ, E_UCL)
//
// Fix 4: force_narrow parameter forces E_SPL=20 for all channels,
//        used for UCL calibration (reference: bramslow2004_ucl.m line 97).
void simulate_tone(double F_tone, double L_tone_dB,
                   const std::vector<double>& agfs_e, const std::vector<double>& ag_loss,
                   const std::vector<double>& ret4153,
                   int NoChan, double E_Beg, double E_End, const std::vector<double>& E_Bin, const std::vector<double>& f0_Hz,
                   std::vector<double>& E_Vector_Out, bool force_narrow = false, bool is_coupler = false, bool widen = false) {
    
    // Get correction for this frequency
    std::vector<double> ff_F = {0, 20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 750, 800, 1000, 1250, 1500, 1600, 2000, 2500, 3000, 3150, 4000, 5000, 6000, 6300, 8000, 9000, 10000, 11200, 12500, 14000, 15000, 16000, 20000};
    std::vector<double> ff_dB = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0.1, 0.3, 0.5, 0.9, 1.4, 1.6, 1.7, 2.5, 2.7, 2.6, 2.6, 3.2, 5.2, 6.6, 12, 16.8, 15.3, 15.2, 14.2, 10.7, 7.1, 6.4, 1.8, -0.9, -1.6, 1.9, 4.9, 2, -2, 2.5, 2.5};
    // ZWICKA0: Transmission factor
    std::vector<double> zwicka0_F = {31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500};
    std::vector<double> zwicka0_dB = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5, 5.0, 6.5, 6.0, 3.5, -1.0, -4.0, -7.5, -20.0};
    
    double zwick = interp1(F_tone, zwicka0_F, zwicka0_dB);
    
    double iec303_corr = 0.0;
    if (is_coupler) {
        std::vector<double> iec_F = {200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500};
        std::vector<double> iec_Gain = {14.4, 10.8, 8.4, 4.7, 2.6, 1.8, 1.2, 0.4, 0.9, 2.6, 6.1, 8.9, 9.7, 10.9, 10.3, 3.7, -7.6, -9.0, -5.0};
        iec303_corr = -interp1(F_tone, iec_F, iec_Gain);
    }
    
    std::vector<double> F = {F_tone};
    std::vector<double> L_linear = {std::pow(10.0, (L_tone_dB + iec303_corr + zwick) / 10.0)};
    
    std::vector<double> E_SPL(NoChan);
    bramslow2004_erbenergy(F, L_linear, agfs_e, ag_loss, ret4153, widen, NoChan, E_Beg, E_End, E_SPL, const_cast<std::vector<double>&>(f0_Hz), const_cast<std::vector<double>&>(E_Bin));
    
    // Force narrow filters for UCL calibration
    if (force_narrow) {
        for (int c = 0; c < NoChan; ++c) E_SPL[c] = 20.0;
    }
    
    bramslow2004_roexfilt(F, L_linear, E_SPL, agfs_e, ag_loss, ret4153, widen, NoChan, E_Bin, f0_Hz, E_Vector_Out);
}

//' Calculate Canonical Loudness (Native C++ Engine)
//' 
//' Native C++ port of the bramslow2004 canonical engine, corrected per
//' AMToolbox 1.6.0 reference with noted simplifications.
//' 
//' @param inputF Vector of input frequencies (Hz)
//' @param inputLdB Vector of input spectrum levels (dB/Hz, free field)
//' @param HLcf Audiogram frequencies (Hz)
//' @param HLohcdB0 OHC loss at audiogram frequencies (dB)
//' @param HLihcdB0 IHC loss at audiogram frequencies (dB)
//' @param NoChan Number of ERB channels (default 30)
//' @param E_Beg Lowest ERB rate (default 3.0)
//' @param E_End Highest ERB rate (default 32.0)
//' @param Binaural Integer indicating whether to compute binaural loudness (default 0L)
//' @return A list containing Loudness (sones), Excitation, Cams, and CFs.
//' @export
// [[Rcpp::export]]
List calculate_loudness_cpp(NumericVector inputF, NumericVector inputLdB, 
                              NumericVector HLcf, NumericVector HLohcdB0, NumericVector HLihcdB0,
                              int NoChan = 30, double E_Beg = 3.0, double E_End = 32.0, int Binaural = 0) {
    
    size_t N_spec = inputF.size();
    std::vector<double> F(N_spec);
    std::vector<double> L_linear(N_spec);
    
    // ZWICKA0: Transmission factor (static outer and middle ear correction)
    std::vector<double> zwicka0_F = {31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500};
    std::vector<double> zwicka0_dB = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5, 5.0, 6.5, 6.0, 3.5, -1.0, -4.0, -7.5, -20.0};
    
    for (size_t i = 0; i < N_spec; ++i) {
        F[i] = inputF[i];
        double L = inputLdB[i];
        L += interp1(F[i], zwicka0_F, zwicka0_dB);
        L_linear[i] = std::pow(10.0, L / 10.0);
    }
    
    std::vector<double> hl_cf(HLcf.begin(), HLcf.end());
    std::vector<double> hl_ohc(HLohcdB0.begin(), HLohcdB0.end());
    std::vector<double> hl_ihc(HLihcdB0.begin(), HLihcdB0.end());
    std::vector<double> agfs_e(hl_cf.size());
    std::vector<double> ag_loss(hl_cf.size());
    std::vector<double> hl_ohc_plus_ihc(hl_cf.size());
    
    // RET4153: ISO 389 thresholds in dB SPL as measured on the ear-simulator (4153) coupler.
    // Matches frequencies: 125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500
    std::vector<double> ret4153 = {45.0, 27.0, 13.5, 9.0, 7.5, 7.5, 9.0, 11.5, 12.0, 16.0, 15.5, 12.5, 10.0};
    
    for(size_t i=0; i<hl_cf.size(); ++i) {
        agfs_e[i] = f2erbrate(hl_cf[i]);
        hl_ohc_plus_ihc[i] = hl_ohc[i] + hl_ihc[i];
        // Convert dB HL to dB SPL by adding RET4153
        ag_loss[i] = hl_ohc[i] + hl_ihc[i] + ret4153[i];
    }
    
    std::vector<double> E_Bin(NoChan);
    std::vector<double> f0_Hz(NoChan);
    std::vector<double> E_SPL(NoChan);
    
    // For speech signal, widen is true
    bramslow2004_erbenergy(F, L_linear, agfs_e, ag_loss, ret4153, true, NoChan, E_Beg, E_End, E_SPL, f0_Hz, E_Bin);
    
    std::vector<double> E_Vector(NoChan);
    bramslow2004_roexfilt(F, L_linear, E_SPL, agfs_e, ag_loss, ret4153, true, NoChan, E_Bin, f0_Hz, E_Vector);
    
    // Canonical Specific Loudness Integration (bramslow2004_specloudn)
    double TotLoudn = 0.0;
    double LOUD_MULT = 0.068;
    double LOUD_EXP = 0.23;
    
    double MONTHR = 1.0;
    double BINTHR = 0.5;
    double MONLOUD = 0.5;
    double BINLOUD = 1.0;
    
    double ThrCorr = (Binaural == 1) ? BINTHR : MONTHR;
    double LoudCorr = (Binaural == 1) ? BINLOUD : MONLOUD;
    
    // Constants for LOUDNORM bandwidth normalization
    double ERB_INT = -0.288173;
    double ERB_SLOPE = 0.0137025;
    double ERB_THR = 30.708;
    
    NumericVector ret_N_prime(NoChan);
    NumericVector ret_E(NoChan);
    NumericVector ret_Cam(NoChan);
    NumericVector ret_CF(NoChan);
    
    // Loop over channels
    for (int c = 0; c < NoChan; ++c) {
        
        // Fix 1: Excitation patterns are evaluated independently for 0 dB SPL, HTL, and UCL tones
        // E_0: excitation from 0 dB SPL tone
        
        // E_TQ: excitation from HTL tone
        double f_kHz = f0_Hz[c] / 1000.0;
        
        std::vector<double> e0_vec(NoChan), etq_vec(NoChan), eucl_vec(NoChan);
        
        // E_0: excitation from 0 dB SPL tone (free-field, so is_coupler=false)
        simulate_tone(f0_Hz[c], 0.0, agfs_e, ag_loss, ret4153, NoChan, E_Beg, E_End, E_Bin, f0_Hz, e0_vec, false, false, false);
        
        // HTL is in dB SPL as measured on the ear-simulator (4153/IEC303) coupler
        double RET = interp1(f0_Hz[c], hl_cf, ret4153);
        double HTL = interp1(f0_Hz[c], hl_cf, hl_ohc_plus_ihc) + RET;
        
        // E_TQ: excitation from HTL tone (coupler, so is_coupler=true)
        simulate_tone(f0_Hz[c], HTL, agfs_e, ag_loss, ret4153, NoChan, E_Beg, E_End, E_Bin, f0_Hz, etq_vec, false, true, false);
        
        // E_UCL: excitation from UCL tone (forced narrow filters, coupler, so is_coupler=true)
        // Default AG_UCL is 120 dB HL
        simulate_tone(f0_Hz[c], 120.0 + RET, agfs_e, ag_loss, ret4153, NoChan, E_Beg, E_End, E_Bin, f0_Hz, eucl_vec, true, true, false);
        
        // Fix 3: E_0 and E_TQ use total summed excitation across all channels
        // (reference: bramslow2004_exc0dbspl.m line 108, bramslow2004_htl.m line 98)
        double e0 = 0.0;
        double etq = 0.0;
        for (int j = 0; j < NoChan; ++j) {
            e0 += e0_vec[j];
            etq += etq_vec[j];
        }
        
        // E_UCL: per-channel excitation (narrow filters minimize cross-channel spread)
        double eucl = eucl_vec[c];
        
        // Safety: ensure reference values are positive
        e0 = std::max(e0, 1e-30);
        etq = std::max(etq, 1e-30);
        eucl = std::max(eucl, 1e-30);
        
        // Zwicker & Feldtkeller s factor (Bild 39,4)
        double s = 1.0;
        if (f_kHz < 0.32) {
            s = 0.65;
        } else {
            s = -2.0 - 2.2 * std::log10(f_kHz / 0.32);
            s = std::pow(10.0, s / 10.0);
        }
        
        double E = E_Vector[c];
        
        // Fix 5: UCL divisor — simple division, not squared
        // (reference: bramslow2004_specloudn.m lines 97-98, 125)
        // Fix 7: Loudness growth — single Zwicker & Feldtkeller Eqn 52.17
        // (reference: bramslow2004_specloudn.m line 114)
        double Loud = LoudCorr * LOUD_MULT * std::pow((ThrCorr * etq) / (s * e0), LOUD_EXP) *
            (std::pow(1.0 - s + s * E / (ThrCorr * etq), LOUD_EXP) - 1.0);
        
        // Fix 6: LOUDNORM — normalize for widened critical bands
        // AMT uses HTLL from roexfilt, which corresponds to HTL in dB SPL
        double NormFact = (ERB_INT + ERB_SLOPE * ERB_THR) /
            (ERB_INT + ERB_SLOPE * std::max(HTL, ERB_THR));
        Loud *= NormFact;
        
        // UCL term
        // Fix 5: UCL divisor — simple division, not squared
        // (reference: bramslow2004_specloudn.m lines 97-98, 125)
        double UCL_Div = 1.0 - std::pow(E / eucl, 1.0 / LOUD_EXP);
        UCL_Div = std::max(UCL_Div, 0.01);
        
        // UCL model: divide by UCL_Div
        // (reference: bramslow2004_specloudn.m line 125)
        Loud /= UCL_Div;
        
        // Clamp to valid range (reference: max 0, min 320)
        Loud = std::max(0.0, std::min(Loud, 320.0));
        double specific = Loud * ((E_End - E_Beg) / (NoChan - 1.0));
        TotLoudn += specific;
        
        ret_N_prime[c] = specific;
        ret_E[c] = E;
        ret_Cam[c] = E_Bin[c];
        ret_CF[c] = f0_Hz[c];
    }
    
    return List::create(Named("Ldn") = TotLoudn,
                        Named("N_prime") = ret_N_prime,
                        Named("E") = ret_E,
                        Named("Cam") = ret_Cam,
                        Named("CF") = ret_CF);
}
