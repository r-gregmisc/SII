pkgname <- "SII"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
base::assign(".ExTimings", "SII-Ex.timings", pos = 'CheckExEnv')
base::cat("name\tuser\tsystem\telapsed\n", file=base::get(".ExTimings", pos = 'CheckExEnv'))
base::assign(".format_ptime",
function(x) {
  if(!is.na(x[4L])) x[1L] <- x[1L] + x[4L]
  if(!is.na(x[5L])) x[2L] <- x[2L] + x[5L]
  options(OutDec = '.')
  format(x[1L:3L], digits = 7L)
},
pos = 'CheckExEnv')

### * </HEADER>
library('SII')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("SII-package")
### * SII-package

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: SII-package
### Title: Calculate ANSI S3.5-1997 Speech Intelligibility Index
### Aliases: SII-package SII
### Keywords: package

### ** Examples

## Example C.1 from ANSI S3.5-1997 Annex C
sii.C1 <- sii(
              speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
              noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
              threshold= c( 0.0,  0.0,  0.0,  0.0,  0.0,  0.0),
              method="octave"
	      )
sii.C1                        # rounded to 2 digits by default
print(sii.C1$sii, digits=20)  # full precision
summary(sii.C1)               # full details
plot(sii.C1)                  # plot
## The value given in the Standard is $0.504$.



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("SII-package", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("calculate_loudness")
### * calculate_loudness

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: calculate_loudness
### Title: Calculate Loudness (Sones)
### Aliases: calculate_loudness

### ** Examples

sii.res <- sii(speech=c(50, 40, 40, 30, 20, 0), threshold=rep(0,6), method="octave")
calculate_loudness(sii.res)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("calculate_loudness", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("critical")
### * critical

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: critical
### Title: Constants Tables for ANSI S3.5-1997 Speech Intelligibility Index
###   (SII)
### Aliases: critical equal onethird octave overall.spl
### Keywords: datasets

### ** Examples

data(critical)
critical # show entire table

data(equal)
names(equal)
equal$fi # extract just the frequency band centers

data(onethird)
barplot(onethird$Ii) # plot band importance function (weights)

data(octave)
round(octave, digits=2) # just 2 digits

data(overall.spl)
overall.spl



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("critical", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("launch_app")
### * launch_app

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: launch_app
### Title: Launch the SII Interactive Dashboard
### Aliases: launch_app
### Keywords: misc

### ** Examples

## Not run: 
##D   # Launch the interactive SII dashboard in your web browser
##D   launch_app()
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("launch_app", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("sic.critical")
### * sic.critical

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: sic.critical
### Title: Alternative ANSI S3.5-1997 SII Transfer Function Weights
### Aliases: sic.critical sic.onethird sic.octave
### Keywords: datasets

### ** Examples

## Load the alternative weights for the critical band method
data(sic.critical)

## display the weights
round(sic.critical,3)

## draw a comparison plot
ngroup <- ncol(sic.critical)
matplot(x=sic.critical[,1], y=sic.critical[,-1],
        type="o",
        xlab="Frequency, Hz",
        ylab="Weight",
        log="x",
        lty=1:ngroup,
        col=rainbow(ngroup)
)
legend(
       "topright",
       legend=names(sic.critical)[-1],
       pch=as.character(1:ngroup),
       lty=1:ngroup,
       col=rainbow(ngroup)
       )

data(threeoctave)
data(octave)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("sic.critical", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("sii")
### * sii

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: sii
### Title: Compute ANSI S3.5-1997 Speech Intelligibility Index (SII)
### Aliases: sii print.SII plot.SII summary.SII
### Keywords: math

### ** Examples


## Example C.1 from ANSI S3.5-1997 Annex C
sii.C1 <- sii(
              speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
              noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
              threshold= c( 0.0,  0.0,  0.0,  0.0,  0.0,  0.0),
              method="octave"
	      )
sii.C1                        # rounded to 2 digits by default
print(sii.C1$sii, digits=20)  # full precision
summary(sii.C1)               # full details
plot(sii.C1)                  # plot
plot(sii.C1, clinical=TRUE)   # clinical SPLogram plot
## The value given in the Standard is $0.504$.


	      
## Same calculation, but manually specify the frequencies
## and importance function, and use default for threshold

sii.C1 <- sii(
              speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
              noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
              method="octave",
              freq=c(250, 500, 1000, 2000, 4000, 8000),
	      importance=c(0.0617, 0.1671, 0.2373, 0.2648, 0.2142, 0.0549)
	      )
sii.C1	     

## Now perform the calculation using frequency weights for the Connected
## Speech Test (CST)
sii.CST <- sii(
               speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
               noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
               method="octave",
	       importance="CST"
	      )
round(sii.CST$table[,-c(5:7,13)],2)
sii.CST$sii

## Example C.2 from ANSI S3.5-1997 Annex C

sii.C2 <- sii(
              speech   = rep(54.0, 18),
              noise    = c(40.0, 30.0, 20.0, rep(0, 18-3) ),
              threshold= rep(0.0,  18),
              method="one-third"
              )
sii.C2$table[1:3,1:8]
sii.C2

## Interpolation example, for 8 frequencies using NU6 importance
## weight, default values for noise.
sii.left <- sii(
                speech="raised",
                threshold=c(25,25,30,35,45,45,55,60),
                freq=c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000),
                method="critical",
                importance="NU6",
                interpolate=TRUE
                )
sii.left





base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("sii", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
