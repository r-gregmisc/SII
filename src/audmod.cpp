// Port of AMT 1.6.0 bramslow2004
#include <Rcpp.h>
#include <cmath>
#include <algorithm>
#include <vector>

using namespace Rcpp;

namespace {

    // erbrate2f.m
    inline double erbrate2f(double erbrate) {
        double f = (pow(10.0, erbrate / 21.366) - 1.0) / 4.368;
        return f * 1000.0;
    }

    // f2erbrate.m
    inline double f2erbrate(double f) {
        f = f / 1000.0;
        return 21.366 * log10(4.368 * f + 1.0);
    }

    // f2erb.m
    inline double f2erb(double CF_Hz) {
        return 24.673 * (0.004368 * CF_Hz + 1.0);
    }

    // bramslow2004_locate.m
    // Returns 1-based index representing the element just below F_Hz
    // If F_Hz < Freq[0], returns 0 (since it's find(...)-1 in MATLAB and find returns empty, then length(Freq), wait!)
    // Wait, let's look at the MATLAB code again!
    int bramslow2004_locate(const std::vector<double>& Freq, double F_Hz) {
        if (Freq[0] > F_Hz) return -1;
        int a = -1;
        for (size_t i = 0; i < Freq.size(); ++i) {
            if (F_Hz < Freq[i]) {
                a = i + 1 - 1; // 1-based index i+1, minus 1 = i
                break;
            }
        }
        if (a == -1) {
            a = Freq.size();
        }
        return a;
    }

    // bramslow2004_erbrateinterp.m
    // Linear interpolation on ERB-rate scale
    double bramslow2004_erbrateinterp(double E, const std::vector<double>& Level, const std::vector<double>& E_Scale, double E_Beg, double E_End) {
        if (E < E_Scale[0]) return Level[0];
        if (E >= E_Scale.back()) return Level.back();
        for (size_t i = 0; i < E_Scale.size() - 1; ++i) {
            if (E >= E_Scale[i] && E < E_Scale[i+1]) {
                return Level[i] + (Level[i+1] - Level[i]) * (E - E_Scale[i]) / (E_Scale[i+1] - E_Scale[i]);
            }
        }
        return Level.back();
    }

} // end anonymous namespace

    // bramslow2004_couplcorr.m
    void bramslow2004_couplcorr(std::vector<double>& PowSpect, double fs, int N, const std::string& Coupler) {
        if (Coupler == "freefield") return;
        
        std::vector<double> Freq, Gain;
        int Points = 0;
        
        if (Coupler == "IEC303") {
            Points = 19;
            Gain = {14.4, 10.8, 8.4, 4.7, 2.6, 1.8, 1.2, 0.4, 0.9, 2.6, 6.1, 8.9, 9.7, 10.9, 10.3, 3.7, -7.6, -9.0, -5.0};
            Freq = {200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500};
        } else {
            stop("Unknown Coupler");
        }
        
        std::vector<double> CoupCorr(N / 2 + 1, 1.0);
        for (int Bin = 0; Bin <= (N / 2) - 1; ++Bin) {
            double F_Hz = (double)Bin * fs / N;
            int Index = bramslow2004_locate(Freq, F_Hz);
            double Gain_dB = 0.0;
            if (Index < 1) {
                Gain_dB = Gain[0];
            } else if (Index >= Points) {
                Gain_dB = Gain[Points - 1];
            } else {
                int idx = Index - 1; // 1-based to 0-based
                Gain_dB = Gain[idx] + (Gain[idx+1] - Gain[idx]) * (F_Hz - Freq[idx]) / (Freq[idx+1] - Freq[idx]);
            }
            CoupCorr[Bin + 1] = pow(10.0, -Gain_dB / 10.0);
        }
        
        for (int Bin = 1; Bin <= N / 2; ++Bin) {
            PowSpect[Bin - 1] *= CoupCorr[Bin];
        }
    }

    // bramslow2004_equloudn.m
    void bramslow2004_equloudn(std::vector<double>& PowSpect, double fs, int N, const std::string& TransFact) {
        std::vector<double> Freq, Gain;
        int Points = 0;
        
        if (TransFact == "ZWICKA0") {
            Points = 27;
            Gain = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5, 5.0, 6.5, 6.0, 3.5, -1.0, -4.0, -7.5, -20.0};
            Freq = {31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500};
        } else {
            stop("Unknown Transmission factor");
        }
        
        for (int Bin = 1; Bin <= N / 2; ++Bin) {
            double F_Hz = (double)Bin * fs / N;
            int Index = bramslow2004_locate(Freq, F_Hz);
            double Gain_dB = 0.0;
            if (Index < 0) {
                Gain_dB = Gain[0];
            } else if (Index >= Points - 1) {
                Gain_dB = Gain[Points - 2]; // Points-1 in MATLAB is Points-2 in 0-based
            } else {
                int idx = Index - 1; // 1-based to 0-based
                Gain_dB = Gain[idx] + (Gain[idx+1] - Gain[idx]) * (F_Hz - Freq[idx]) / (Freq[idx+1] - Freq[idx]);
            }
            PowSpect[Bin - 1] *= pow(10.0, Gain_dB / 10.0);
        }
    }


    // bramslow2004_erbenergy.m
    void bramslow2004_erbenergy(const std::vector<double>& PowSpect, int NoChan, int In_FrmSize, double In_SampF,
                                bool Widen, const std::vector<double>& AGLoss, const std::vector<double>& RET4153,
                                const std::vector<double>& AGFs_E, double E_Beg, double E_End,
                                std::vector<double>& E_SPL, std::vector<double>& FLow, std::vector<double>& FHigh) {
        double MAX_THR = 70.0;
        double ERB_INT = -0.288173;
        double ERB_SLOPE = 0.0137025;
        double ERB_THR = 30.708;
        double C1 = 24.673;
        double C2 = 4.368;
        double C3 = 2302.6 / (C1 * C2);
        double MIN_SPL = 20.0;
        double MAX_SPL = 130.0;

        std::vector<double> E_Energy(NoChan, 1e-10);
        E_SPL.assign(NoChan, 0.0);
        FLow.assign(NoChan, 0.0);
        FHigh.assign(NoChan, 0.0);

        double E = E_Beg;
        double E_Step = 0.0;

        for (int E_Index = 1; E_Index <= NoChan; ++E_Index) {
            E = E + E_Step;
            E_Step = (E_End - E_Beg) / (NoChan - 1.0);

            double HTL = 0.0;
            if (Widen) {
                HTL = bramslow2004_erbrateinterp(E, AGLoss, AGFs_E, E_Beg, E_End);
            } else {
                HTL = bramslow2004_erbrateinterp(E, RET4153, AGFs_E, E_Beg, E_End);
            }

            double F_kHz = erbrate2f(E) / 1000.0;
            HTL = std::min(HTL, MAX_THR);
            HTL = std::max(ERB_THR, HTL);

            double ERB_Hz = (1000.0 * ((C2 * F_kHz + 1.0) / (C2 + 1.0)) * (ERB_INT + ERB_SLOPE * HTL));

            double Temp1 = C2 * ERB_Hz / 1000.0;
            double Temp2 = pow(10.0, 2.0 * E / C3);
            double Temp3 = (Temp1 + 2.0) * (Temp1 + 2.0) - 4.0 * (Temp1 + 1.0 - Temp2);
            F_kHz = (sqrt(Temp3) - (Temp1 + 2.0)) / (2.0 * C2);
            double F_Hz = F_kHz * 1000.0;
            FLow[E_Index - 1] = F_Hz;

            int BinL = ceil(FLow[E_Index - 1] / (In_SampF / In_FrmSize));
            if (BinL < 0) BinL = 0;

            F_Hz = F_Hz + ERB_Hz;
            FHigh[E_Index - 1] = F_Hz;
            int BinU = floor(FHigh[E_Index - 1] / (In_SampF / In_FrmSize));
            if (BinU > In_FrmSize / 2) {
                BinU = In_FrmSize / 2;
            }

            for (int Bin = BinL; Bin <= BinU; ++Bin) {
                if (Bin >= 1 && Bin <= In_FrmSize / 2) {
                    E_Energy[E_Index - 1] += PowSpect[Bin - 1];
                }
            }
        }

        for (int E_Index = 1; E_Index <= NoChan; ++E_Index) {
            E_SPL[E_Index - 1] = 10.0 * log10(E_Energy[E_Index - 1]);
            E_SPL[E_Index - 1] = std::max(E_SPL[E_Index - 1], MIN_SPL);
            E_SPL[E_Index - 1] = std::min(E_SPL[E_Index - 1], MAX_SPL);
        }
    }


    // bramslow2004_roexfilt.m
    void bramslow2004_roexfilt(const std::vector<double>& PowSpect, const std::vector<double>& E_SPL, int In_FrmSize, double In_SampF,
                               int NoChan, bool Widen, const std::vector<double>& AGFs_E, const std::vector<double>& AGLoss,
                               const std::vector<double>& RET4153, double E_Beg, double E_End, const std::vector<double>& E_Bin,
                               std::vector<double>& E_Vector, std::vector<double>& HTLL) {
        double C2 = 4.368;
        bool PU_DEP_HL = true;
        bool PL_DEP_HL = true;
        bool PL_MOD2 = true;
        double MAX_THR = 100.0;
        double PU_THR = 36.8;
        double GMAX = 10.0;
        double PMIN = 3.0;
        double PL_INT2 = 30.16;
        double PL_SLO2 = -0.38;
        double PL_THR2 = 20.0;

        E_Vector.assign(NoChan, 1e-10);
        HTLL.assign(NoChan, 0.0);

        std::vector<double> f0_kHz(NoChan), f0_Hz(NoChan), pl_51(NoChan), pu_51(NoChan), HTLU(NoChan);
        std::vector<int> BinL(NoChan), BinU(NoChan);

        double E = E_Beg;
        double E_Step = 0.0;
        
        for (int Filt_Index = 1; Filt_Index <= NoChan; ++Filt_Index) {
            E = E + E_Step;
            E_Step = (E_End - E_Beg) / (NoChan - 1.0);

            f0_kHz[Filt_Index - 1] = erbrate2f(E) / 1000.0;
            f0_Hz[Filt_Index - 1] = f0_kHz[Filt_Index - 1] * 1000.0;

            if (PU_DEP_HL) {
                double Erb_Hz = f2erb(f0_Hz[Filt_Index - 1]);
                pl_51[Filt_Index - 1] = 4.0 * f0_Hz[Filt_Index - 1] / Erb_Hz;
                pu_51[Filt_Index - 1] = pl_51[Filt_Index - 1];
            }

            if (Widen) {
                HTLL[Filt_Index - 1] = bramslow2004_erbrateinterp(E, AGLoss, AGFs_E, E_Beg, E_End);
            } else {
                HTLL[Filt_Index - 1] = bramslow2004_erbrateinterp(E, RET4153, AGFs_E, E_Beg, E_End);
            }

            HTLL[Filt_Index - 1] = std::min(HTLL[Filt_Index - 1], MAX_THR);
            HTLU[Filt_Index - 1] = std::max(HTLL[Filt_Index - 1], PU_THR);

            double f_Hz = (1.0 - GMAX) * f0_Hz[Filt_Index - 1];
            BinL[Filt_Index - 1] = ceil(f_Hz / (In_SampF / In_FrmSize));
            if (BinL[Filt_Index - 1] < 1) BinL[Filt_Index - 1] = 1;

            f_Hz = (1.0 + GMAX) * f0_Hz[Filt_Index - 1];
            BinU[Filt_Index - 1] = floor(f_Hz / (In_SampF / In_FrmSize));
            BinU[Filt_Index - 1] = std::min(BinU[Filt_Index - 1], In_FrmSize / 2);
        }

        E = E_Beg;
        E_Step = 0.0;
        for (int Filt_Index = 1; Filt_Index <= NoChan; ++Filt_Index) {
            E = E + E_Step;
            E_Step = (E_End - E_Beg) / (NoChan - 1.0);
            
            int Prev_ESPL_Index = 10000;
            double pl = 0.0, pu = 0.0;

            for (int Bin = BinL[Filt_Index - 1]; Bin <= BinU[Filt_Index - 1]; ++Bin) {
                double f_Hz = (double)Bin * In_SampF / In_FrmSize;

                double raw_idx = std::max(1.0, (E_Bin[Bin - 1] - E_Beg) / E_Step);
                int ESPL_Index = std::round(raw_idx);
                ESPL_Index = std::min(ESPL_Index, NoChan);
                if (ESPL_Index == 0) ESPL_Index = 1;

                if (ESPL_Index != Prev_ESPL_Index) {
                    if (PL_DEP_HL) {
                        if (PL_MOD2) {
                            pl = (((C2 + 1.0) * f0_kHz[Filt_Index - 1]) / (C2 * f0_kHz[Filt_Index - 1] + 1.0)) * 
                                 (PL_INT2 + PL_SLO2 * (std::max(std::min(0.0, E_SPL[ESPL_Index - 1] - 71.0), HTLL[Filt_Index - 1] - PL_THR2) + PL_THR2));
                        }
                    }

                    if (!PU_DEP_HL) {
                        // Unused branch in this config
                    } else {
                        pu = pu_51[Filt_Index - 1];
                    }

                    pl = std::max(pl, PMIN);
                    pu = std::max(pu, PMIN);
                }

                Prev_ESPL_Index = ESPL_Index;

                double g = (f_Hz - f0_Hz[Filt_Index - 1]) / f0_Hz[Filt_Index - 1];

                if (g < 0) {
                    E_Vector[Filt_Index - 1] += PowSpect[Bin - 1] * (1.0 - pl * g) * exp(pl * g);
                } else {
                    E_Vector[Filt_Index - 1] += PowSpect[Bin - 1] * (1.0 + pu * g) * exp(-pu * g);
                }
            }
        }
    }

    // bramslow2004_specloudn.m
    void bramslow2004_specloudn(std::vector<double>& E_Vector, const std::vector<double>& E_0, const std::vector<double>& E_TQ,
                                const std::vector<double>& E_UCL, const std::vector<double>& HTLL, int NoChan, double E_Beg, double E_End,
                                int Binaural, double& TotLoudn) {
        TotLoudn = 0.0;
        double LOUD_EXP = 0.23;
        double MIN_UCLDIV = 0.01;
        double MONTHR = 1.0;
        double BINTHR = 0.5;
        double BINLOUD = 1.0;
        double MONLOUD = 0.5;
        double ERB_INT = -0.288173;
        double ERB_SLOPE = 0.0137025;
        double ERB_THR = 30.708;
        double LOUD_MULT = 0.068;
        double LOUD_ADJ = 1.00;
        double MAX_LOUD = 320.0;

        double ThrCorr = (Binaural == 1) ? BINTHR : MONTHR;
        double LoudCorr = (Binaural == 1) ? BINLOUD : MONLOUD;

        double E_Bin = E_Beg;
        double E_Step = 0.0;
        for (int Chan = 1; Chan <= NoChan; ++Chan) {
            E_Bin = E_Bin + E_Step;
            E_Step = (E_End - E_Beg) / (NoChan - 1.0);

            double f_kHz = erbrate2f(E_Bin) / 1000.0;
            double s = 1.0;
            if (f_kHz < 0.32) {
                s = 0.65;
            } else {
                s = -2.0 - 2.2 * log10(f_kHz / 0.32);
                s = pow(10.0, s / 10.0);
            }

            double UCL_Div = 1.0 - pow(E_Vector[Chan - 1] / E_UCL[Chan - 1], 1.0 / LOUD_EXP);
            UCL_Div = std::max(UCL_Div, MIN_UCLDIV);

            double NormFact = (ERB_INT + ERB_SLOPE * ERB_THR) / (ERB_INT + ERB_SLOPE * std::max(HTLL[Chan - 1], ERB_THR));

            E_Vector[Chan - 1] = LoudCorr * LOUD_ADJ * LOUD_MULT * pow(ThrCorr * E_TQ[Chan - 1] / (s * E_0[Chan - 1]), LOUD_EXP) *
                                 (pow((1.0 - s) + (s * E_Vector[Chan - 1]) / (ThrCorr * E_TQ[Chan - 1]), LOUD_EXP) - 1.0);

            E_Vector[Chan - 1] *= NormFact;
            E_Vector[Chan - 1] /= UCL_Div;

            E_Vector[Chan - 1] = std::max(0.0, E_Vector[Chan - 1]);
            E_Vector[Chan - 1] = std::min(MAX_LOUD, E_Vector[Chan - 1]);

            TotLoudn += E_Vector[Chan - 1];
        }
    }



// [[Rcpp::export]]
Rcpp::List audmod_reference_cpp(double fs, int N, Rcpp::NumericVector AGLoss_HL, Rcpp::NumericVector AG_UCL_HL,
                                int NoChan = 30, double E_Beg = 3.0, double E_End = 32.0, std::string TransFact = "ZWICKA0") {
    std::vector<double> AGLoss = Rcpp::as<std::vector<double>>(AGLoss_HL);
    std::vector<double> AG_UCL = Rcpp::as<std::vector<double>>(AG_UCL_HL);
    std::vector<double> RET4153 = {45.0, 27.0, 13.5, 9.0, 7.5, 7.5, 9.0, 11.5, 12.0, 16.0, 15.5, 12.5, 10.0};
    std::vector<double> AGFs_E(13);
    std::vector<double> AG_f = {125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500};
    for (size_t i = 0; i < 13; ++i) {
        AGLoss[i] += RET4153[i];
        AG_UCL[i] += RET4153[i];
        AGFs_E[i] = f2erbrate(AG_f[i]);
    }
    
    std::vector<double> E_Bin(N / 2);
    for (int j = 1; j <= N / 2; ++j) {
        E_Bin[j - 1] = f2erbrate((double)j * fs / N);
    }
    
    std::vector<double> EC(NoChan), fc(NoChan);
    double E = E_Beg;
    double E_Step = (E_End - E_Beg) / (NoChan - 1.0);
    for (int k = 0; k < NoChan; ++k) {
        EC[k] = E;
        fc[k] = erbrate2f(E);
        E += E_Step;
    }
    
    std::vector<double> E_0(NoChan, 0.0), E_TQ(NoChan, 0.0), E_UCL_out(NoChan, 0.0);
    
    // E_0 and E_TQ
    for (int k = 0; k < NoChan; ++k) {
        double f_Hz = fc[k];
        int Bin = std::round(f_Hz * N / fs);
        if (Bin < 1) Bin = 1;
        if (Bin > N / 2) Bin = N / 2;
        
        std::vector<double> PowSpect_0(N / 2, 0.0);
        PowSpect_0[Bin - 1] = 1.0;
        bramslow2004_couplcorr(PowSpect_0, fs, N, "freefield");
        bramslow2004_equloudn(PowSpect_0, fs, N, TransFact);
        std::vector<double> E_SPL_0, FLow, FHigh;
        bramslow2004_erbenergy(PowSpect_0, NoChan, N, fs, false, AGLoss, RET4153, AGFs_E, E_Beg, E_End, E_SPL_0, FLow, FHigh);
        std::vector<double> E_Vec_0, HTLL_0;
        bramslow2004_roexfilt(PowSpect_0, E_SPL_0, N, fs, NoChan, false, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_Bin, E_Vec_0, HTLL_0);
        
        double sum0 = 0.0;
        for (double val : E_Vec_0) sum0 += val;
        E_0[k] = sum0;
        
        double HTLL = bramslow2004_erbrateinterp(EC[k], AGLoss, AGFs_E, E_Beg, E_End);
        std::vector<double> PowSpect_TQ(N / 2, 0.0);
        PowSpect_TQ[Bin - 1] = pow(10.0, HTLL / 10.0);
        bramslow2004_couplcorr(PowSpect_TQ, fs, N, "IEC303");
        bramslow2004_equloudn(PowSpect_TQ, fs, N, TransFact);
        std::vector<double> E_SPL_TQ;
        bramslow2004_erbenergy(PowSpect_TQ, NoChan, N, fs, false, AGLoss, RET4153, AGFs_E, E_Beg, E_End, E_SPL_TQ, FLow, FHigh);
        std::vector<double> E_Vec_TQ, HTLL_TQ;
        bramslow2004_roexfilt(PowSpect_TQ, E_SPL_TQ, N, fs, NoChan, false, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_Bin, E_Vec_TQ, HTLL_TQ);
        
        double sumTQ = 0.0;
        for (double val : E_Vec_TQ) sumTQ += val;
        E_TQ[k] = sumTQ;
    }
    
    // E_UCL
    std::vector<double> PowSpect_UCL(N / 2, 0.0);
    for (int k = 0; k < NoChan; ++k) {
        double f_Hz = fc[k];
        int Bin = std::round(f_Hz * N / fs);
        if (Bin < 1) Bin = 1;
        if (Bin > N / 2) Bin = N / 2;
        double UCL_dB = bramslow2004_erbrateinterp(EC[k], AG_UCL, AGFs_E, E_Beg, E_End);
        PowSpect_UCL[Bin - 1] = pow(10.0, UCL_dB / 10.0);
    }
    bramslow2004_couplcorr(PowSpect_UCL, fs, N, "IEC303");
    bramslow2004_equloudn(PowSpect_UCL, fs, N, TransFact);
    std::vector<double> E_SPL_UCL(NoChan, 20.0);
    std::vector<double> HTLL_UCL;
    bramslow2004_roexfilt(PowSpect_UCL, E_SPL_UCL, N, fs, NoChan, false, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_Bin, E_UCL_out, HTLL_UCL);
    
    return Rcpp::List::create(
        Rcpp::Named("E_0") = E_0,
        Rcpp::Named("E_TQ") = E_TQ,
        Rcpp::Named("E_UCL") = E_UCL_out,
        Rcpp::Named("fc") = fc,
        Rcpp::Named("EC") = EC,
        Rcpp::Named("AGLoss") = AGLoss,
        Rcpp::Named("AG_UCL") = AG_UCL
    );
}

// [[Rcpp::export]]
Rcpp::List audmod_loudness_cpp(Rcpp::NumericVector PowSpect_in, double fs, int N, Rcpp::List ref,
                               std::string Coupler = "freefield", std::string TransFact = "ZWICKA0", int Binaural = 0) {
    if (PowSpect_in.size() != N / 2) stop("PowSpect must have length N/2");
    std::vector<double> PowSpect(N / 2);
    for (int i = 0; i < N / 2; ++i) {
        if (!std::isfinite(PowSpect_in[i]) || PowSpect_in[i] < 0) stop("PowSpect contains invalid values");
        PowSpect[i] = PowSpect_in[i];
    }
    
    std::vector<double> E_0 = Rcpp::as<std::vector<double>>(ref["E_0"]);
    std::vector<double> E_TQ = Rcpp::as<std::vector<double>>(ref["E_TQ"]);
    std::vector<double> E_UCL = Rcpp::as<std::vector<double>>(ref["E_UCL"]);
    std::vector<double> AGLoss = Rcpp::as<std::vector<double>>(ref["AGLoss"]);
    int NoChan = E_0.size();
    
    std::vector<double> RET4153 = {45.0, 27.0, 13.5, 9.0, 7.5, 7.5, 9.0, 11.5, 12.0, 16.0, 15.5, 12.5, 10.0};
    std::vector<double> AG_f = {125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500};
    std::vector<double> AGFs_E(13);
    for (size_t i = 0; i < 13; ++i) AGFs_E[i] = f2erbrate(AG_f[i]);
    
    std::vector<double> EC_vec = Rcpp::as<std::vector<double>>(ref["EC"]);
    double E_Beg = EC_vec[0];
    double E_End = EC_vec[NoChan - 1];
    
    std::vector<double> E_Bin(N / 2);
    for (int j = 1; j <= N / 2; ++j) {
        E_Bin[j - 1] = f2erbrate((double)j * fs / N);
    }
    
    bramslow2004_couplcorr(PowSpect, fs, N, Coupler);
    bramslow2004_equloudn(PowSpect, fs, N, TransFact);
    std::vector<double> E_SPL, FLow, FHigh;
    bramslow2004_erbenergy(PowSpect, NoChan, N, fs, true, AGLoss, RET4153, AGFs_E, E_Beg, E_End, E_SPL, FLow, FHigh);
    std::vector<double> E_Vector, HTLL;
    bramslow2004_roexfilt(PowSpect, E_SPL, N, fs, NoChan, true, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_Bin, E_Vector, HTLL);
    
    double TotLoudn = 0.0;
    std::vector<double> excitation = E_Vector;
    bramslow2004_specloudn(E_Vector, E_0, E_TQ, E_UCL, HTLL, NoChan, E_Beg, E_End, Binaural, TotLoudn);
    
    return Rcpp::List::create(
        Rcpp::Named("E_SPL") = E_SPL,
        Rcpp::Named("E_Vector") = excitation,
        Rcpp::Named("HTLL") = HTLL,
        Rcpp::Named("N_prime") = E_Vector,
        Rcpp::Named("Ldn") = TotLoudn,
        Rcpp::Named("fc") = ref["fc"]
    );
}
