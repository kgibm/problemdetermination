# See https://www.ibm.com/developerworks/community/blogs/kevgrig/entry/graphing_arbitrary_data_from_the_command_line_using_r?lang=en
# Sample data in /sampledata/ihs/mpmstats
# Prereq: > install.packages(c("xts", "xtsExtra", "zoo", "txtplot"), repos=c("http://cran.us.r-project.org","http://R-Forge.R-project.org"))
# Convert error_log to CSV: OUTPUT=error_log.csv; echo Time,rdy,bsy,rd,wr,ka,log,dns,cls > ${OUTPUT}; grep "mpmstats: rdy " error_log | sed -n "s/\[[^ ]\+ \([^ ]\+\) \([0-9]\+\) \([^ ]\+\) \([0-9]\+\)\] \(.*\)/\1:\2:\4:\3 \5/p" | tr ' ' ',' | cut -d "," -f 1,5,7,9,11,13,15,17,19 >> ${OUTPUT};
# Run: $ cat error_log.csv | R --silent --no-save -f mpmstats.r 2>/dev/null

require(xts, warn.conflicts=FALSE)
require(xtsExtra, warn.conflicts=FALSE)
require(zoo, warn.conflicts=FALSE)
require(txtplot, warn.conflicts=FALSE)

pngfile = "output.png"
pngwidth = 600
asciiwidth = 120

mpmtime = function(x, format) { as.POSIXct(paste(as.Date(substr(as.character(x),1,11), format="%b:%d:%Y"), substr(as.character(x),13,20), sep=" "), format=format, tz="UTC") }
data = as.xts(read.zoo(file="stdin", format = "%Y-%m-%d %H:%M:%S", header=TRUE, sep=",", FUN = mpmtime))
x = sapply(index(data), function(time) {as.numeric(strftime(time, format = "%H%M"))})
txtplot(x, data[,2], width=asciiwidth, xlab="Time", ylab="mpmstats bsy")
png(pngfile, width=pngwidth)
plot.xts(data, main="mpmstats", minor.ticks=FALSE, yax.loc="left", auto.grid=TRUE, ylim="fixed", nc=2)
