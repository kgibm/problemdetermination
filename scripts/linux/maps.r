options( scipen = 20 )
x = read.csv("../../sampledata/linux/maps4274.txt.csv", header = TRUE, sep = ",", colClasses = c("character", "numeric"))
x[,2] = sapply(x[,2], function(a) { a/1048576 })
x[order(x[,2], decreasing=TRUE), ]
