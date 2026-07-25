# Create normative RECD data based on Bagatto et al. (2002) and standard pediatric audiology

recd <- data.frame(
  freq = c(250, 500, 1000, 2000, 4000, 8000),
  adult = c(2, 3, 5, 8, 10, 6),
  months_24_60 = c(3, 4, 6, 9, 11, 8),
  months_12_24 = c(4, 6, 8, 11, 13, 10),
  months_6_12 = c(5, 7, 10, 13, 15, 12),
  months_0_6 = c(6, 8, 12, 15, 17, 14)
)

save(recd, file = "data/recd.rda")
