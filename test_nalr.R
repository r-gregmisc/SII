devtools::load_all(".")
my_aided_sii <- sii(speech = "normal", 
                    freq = c(250, 500, 1000, 2000, 4000, 8000),
                    threshold = c(20, 25, 40, 50, 60, 70), 
                    method = "one-third octave",
                    interpolate = TRUE,
                    prescription = "NAL-R") 

df <- data.frame(
  Freq = my_aided_sii$freq,
  Thresh = my_aided_sii$threshold,
  Unaided_Speech = my_aided_sii$unaided_speech,
  Gain = my_aided_sii$gain,
  Aided_Speech = my_aided_sii$speech
)
print(df)
