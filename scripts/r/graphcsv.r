# graphcsv.r: Graph an arbitrary set of time series data with first column of time and other columns integer values
# Use envars as input (see below)
#
# Input of the form:
#  Time,Col1,Col2,Col3...
#  2014-01-01 01:02:03,Col1Value,Col2Value,Col3Value...
#  2014-01-02 01:02:03,Col1Value,Col2Value,Col3Value...
#  2014-01-02 01:02:04,Col1Value,Col2Value,Col3Value...
#
# cat input.csv | R --silent --no-save -f timeplot.r
#
# NOTE: plot.xts requires at least 3 data points.
# WARNING: Newer versions of xtsExtra do not work. See http://stackoverflow.com/a/28590900/1293660

requiredLibraries = c("xts", "xtsExtra", "zoo", "txtplot")
installedLibraries = requiredLibraries[!(requiredLibraries %in% installed.packages()[,"Package"])]
if(length(installedLibraries)) install.packages(requiredLibraries, repos=c("http://cran.us.r-project.org","http://R-Forge.R-project.org"), quiet=FALSE)
library(zoo, warn.conflicts=FALSE)
library(xts, warn.conflicts=FALSE)
library(xtsExtra, warn.conflicts=FALSE)
library(txtplot, warn.conflicts=FALSE)
options(scipen=999)

title = if (nchar(Sys.getenv("INPUT_TITLE")) == 0) "TITLE" else Sys.getenv("INPUT_TITLE")
pngfile = if (nchar(Sys.getenv("INPUT_PNGFILE")) == 0) paste(title, ".png", sep="") else Sys.getenv("INPUT_PNGFILE")
pngwidth = as.integer(if (nchar(Sys.getenv("INPUT_PNGWIDTH")) == 0) "800" else Sys.getenv("INPUT_PNGWIDTH"))
pngheight = as.integer(if (nchar(Sys.getenv("INPUT_PNGHEIGHT")) == 0) "600" else Sys.getenv("INPUT_PNGHEIGHT"))
cols = as.integer(if (nchar(Sys.getenv("INPUT_COLS")) == 0) "1" else Sys.getenv("INPUT_COLS"))
timezone = if (nchar(Sys.getenv("TZ")) == 0) "UTC" else Sys.getenv("TZ")
Sys.setenv(TZ=timezone)
asciiwidth = as.integer(if (nchar(Sys.getenv("INPUT_ASCIIWIDTH")) == 0) "120" else Sys.getenv("INPUT_ASCIIWIDTH"))
asciicolumn = as.integer(if (nchar(Sys.getenv("INPUT_ASCIICOLUMN")) == 0) "0" else Sys.getenv("INPUT_ASCIICOLUMN"))
fontsize = as.numeric(if (nchar(Sys.getenv("INPUT_FONTSIZE")) == 0) "1.3" else Sys.getenv("INPUT_FONTSIZE"))
usexts = as.numeric(if (nchar(Sys.getenv("INPUT_USEXTS")) == 0) "1" else Sys.getenv("INPUT_USEXTS"))
zooylab = if (nchar(Sys.getenv("INPUT_ZOOYLAB")) == 0) "" else Sys.getenv("INPUT_ZOOYLAB")

data = as.xts(read.zoo(file="stdin", format = "%Y-%m-%d %H:%M:%S", header=TRUE, sep=",", tz=timezone))
if(asciicolumn>0) {
  x = sapply(index(data), function(time) {as.numeric(strftime(time, format = "%H%M"))})
  txtplot(x, data[,asciicolumn], width=asciiwidth, xlab=paste("Time (", timezone, ")", sep=""), ylab=dimnames(data)[[2]][asciicolumn])
}
png(pngfile, width=pngwidth, height=pngheight)
if(usexts) {
  plot.xts(
    data,
    main=paste(title, " (Timezone ", timezone, ")", sep=""),
    minor.ticks=FALSE,
    major.ticks=FALSE,
    yax.loc="left",
    auto.grid=TRUE,
    nc=cols,
    cex.lab=fontsize,
    cex.axis=fontsize,
    cex.main=fontsize,
    cex.sub=fontsize
  )
} else {
  zoodata = as.zoo(data)
  tsRainbow = rainbow(ncol(zoodata))
  plot.zoo(
    zoodata,
    xlab="Time",
    ylab=zooylab,
    main=paste(title, " (Timezone ", timezone, ")", sep=""),
    col=tsRainbow,
    screens=1
  )
  legend("topleft", legend=colnames(zoodata), lty = 1, col = tsRainbow)
}
