# grep -v -E "^[a-zA-Z_]+:" smaps.txt | awk '{print $1}' | sed 's/\-/,/g' | R --silent --no-save -f smaps.r 2>/dev/null
requiredLibraries = c("int64")
installedLibraries = requiredLibraries[!(requiredLibraries %in% installed.packages()[,"Package"])]
if(length(installedLibraries)) install.packages(c("int64"), repos=c("http://cran.us.r-project.org","http://R-Forge.R-project.org"), quiet=TRUE)
library(int64)
options( scipen = 20 )
x = read.csv("stdin", header = FALSE, sep = ",", col.names = c("Start", "End"), colClasses = c("character", "character"))
x[,1] = sapply(x[,1], function(a) { as.int64(paste0("0x", a)) })
#x[order(x[,2], decreasing=TRUE), ]
x
