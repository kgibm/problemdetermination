#!/usr/bin/python

import sys
import getopt
import os
import os.path
import re

##
## Declares the wcvException class for the scripts
##
class wcvException(Exception):
  def __init__(self, value):
    self.value = value
  def __str__(self):
    return repr(self.value)

class wcvParamException(wcvException):
  def __init__(self, value):
    self.value = value
  def __str__(self):
    return repr(self.value)

class wcvTypeException(wcvException):
  def __init__(self, value):
    self.value = value
  def __str__(self):
    return repr(self.value)
##
## Returns the date as YYYYmmdd
##
def wcvGetDate(sep=""):
        return str(time.strftime("%Y"+ sep + "%m" + sep +"%d"))
##
## Returns the time as hhmmss
##        
def wcvGetTime(sep=""):        
        return str(time.strftime("%H" + sep + "%M" + sep + "%S"))
##
## Checks is Debugging is set
##
def wcvSetDebugSwitch():
        if os.environ.keys().count('WCV_DEBUG') != 1:
               print "DEBUG: Debugging is disabled"
               return 0
        else:
                print "DEBUG: Debugging is enabled"
                return 1
##
## Returns the templateFile name specified in the command line options
##
def wcvSetFile (opts):
        if WCV_DEBUG:
                print "In function wcvSetFile opts:", opts
                
        for option, value in opts:
                if option ==  "--file":
                        return value

        return ""
##
## Returns the ip address specified in the command line options
##
def wcvSetIp (opts):
        if WCV_DEBUG:
                print "In function wcvSetIp opts:", opts
                
        for option, value in opts:
                if option ==  "--ip":
                        return value

        return ".*"
##
## Returns the process id specified in the command line options
##
def wcvSetPid (opts):
        if WCV_DEBUG:
                print "In function wcvSetPid opts:", opts
                
        for option, value in opts:
                if option ==  "--pid":
                        return value

        return ".*"
##
## Returns the request id specified in the command line options
##
def wcvSetReqId (opts):
        if WCV_DEBUG:
                print "In function wcvSetReqId opts:", opts
                
        for option, value in opts:
                if option ==  "--reqid":
                        return value

        return ".*"
##
## Check if help option is requested
##
def wcvCheckHelp (opts):
        if WCV_DEBUG:
                print "In function wcvCheckHelp opts:", opts
                
        for option, value in opts:
                if option in ("-?", "--help"):
                        return 1

        return 0
##
## build the regex pattern for a parent line to search for
##
def getParentRegExPattern(wcvPid=".*", wcvIp=".*", wcvReqId=".*"):
  if WCV_DEBUG:
    print "In function getParentRegExPattern wcvPid:", wcvPid
    print "In function getParentRegExPattern wcvIp:", wcvIp
    print "In function getParentRegExPattern wcvReqId:", wcvReqId
 
  regExPattern = ".*\ PMRM0003I:\ \ parent:ver=1,ip=" + wcvIp + ",time=.*,pid=" + wcvPid + ",reqid=" + wcvReqId + ".*"
  return regExPattern
##
## build the regex pattern for a current line to search for
##
def getBaseCurrentRegExPattern():
  if WCV_DEBUG:
    print "In function getBaseCurrentRegExPattern ...."
 
  regExPattern = ".*\ PMRM0003I:\ \ parent:ver=1,ip=.*current:ver=1.*"
  return regExPattern
##
## Prints a formatted line
##
def printFormattedLine(wcvLevel, wcvIp, wcvPid, wcvReqId, wcvElapsed, wcvType, wcvDetail):
  if WCV_DEBUG:
    print "In function printFormattedLine wcvLevel:", wcvLevel
    print "In function printFormattedLine wcvPid:", wcvPid
    print "In function printFormattedLine wcvIp:", wcvIp
    print "In function printFormattedLine wcvReqId:", wcvReqId
    print "In function printFormattedLine wcvElapsed:", wcvElapsed
    print "In function printFormattedLine wcvType:", wcvType
    print "In function printFormattedLine wcvDetail:", wcvDetail

  print "|{0:>{col0}}|{1:>{col1}}|{2:>{col2}}|{3:>{col3}}|{4:>{col4}}|{5:<{col5}}|{6:<{col6}}|".format(wcvLevel, wcvIp, wcvPid, wcvReqId, wcvElapsed, wcvType, wcvDetail, col0=3, col1=16, col2=9,col3=9, col4=9, col5=9, col6=35)
  ##### print ("|%3s|%16s|%9s|%9s|%9s|%9s}|%35s|") % (wcvLevel, wcvIp, wcvPid, wcvReqId, wcvElapsed, wcvType, wcvDetail)

##
## Print header for output
##
def printHeader(wcvIp, wcvPid, wcvReqId):
  if WCV_DEBUG:
    print "In function printHeader wcvPid:", wcvPid
    print "In function printHeader wcvIp:", wcvIp
    print "In function printHeader wcvReqId:", wcvReqId
    
  print ("Request metric data for parent ip=%s, parent pid=%s, parent request id =%s\n") % (wcvIp, wcvPid, wcvReqId)  
  printFormattedLine("Lvl", "IP", "PID", "ReqId", "elapsed", "Type", "Detail")

##
## Prints a formatted output line
##
def printLine(wcvLevel, wcvIp, wcvPid, wcvReqId, wcvElapsed, wcvType, wcvDetail ):
  if WCV_DEBUG:
    print "In function printLine wcvLevel:", wcvLevel
    print "In function printLine wcvPid:", wcvPid
    print "In function printLine wcvIp:", wcvIp
    print "In function printLine wcvReqId:", wcvReqId
    print "In function printLine wcvElapsed:", wcvElapsed
    print "In function printLine wcvType:", wcvType
    print "In function printLine wcvDetail:", wcvDetail
    
  printFormattedLine(wcvLevel, wcvIp, wcvPid, wcvReqId, wcvElapsed, wcvType, wcvDetail)  
##
## Retrieve the current IP from the output record
##
def getCurrentValue (record, key, termChar):
  if WCV_DEBUG:
    print "In function getCurrentValue for key:", key
    print "In function getCurrentValue for termChar:", termChar

  curVal = ""
  regExPattern = getBaseCurrentRegExPattern()
  regExPattern += key + "=(.*?)" + termChar
  curVal = re.sub(regExPattern, r"\1", record).replace("\n", "")
 
  if WCV_DEBUG:
    print "Returning:", curVal
  return curVal

##
## Usage of the script
##
def printUsage (scriptName):
        print "Usage:", scriptName, "--help (this information) | (--ip <parent_ipAddress> --pid <parent_processId> --reqid <parent_requestId> --file <fileName> )"

def checkParm (opts, scriptName):
        if WCV_DEBUG:
                print "In function checkParm with parameter opts=", opts
                print "In function checkParm with parameter scriptName=", scriptName
        
        ip = pid = reqid = file = ""
        
        for option, value in opts:
                print "option=" + option
                if option in ("-?", "--help"):
                        printUsage (scriptName)
                        sys.exit(0)
                elif (option == "--ip"):
                        if (value == ""):
                               raise wcvParamException, 'ip address to follow missing'
                        else:
                               ip = value
                elif (option == "--file"):
                        if (value == ""):
                                raise wcvParamException, 'file name missing'
                        else:
                                file = os.path.normpath(value)
                elif option == "--reqid":
                        if (value == ""):
                                raise wcvParamException, 'request id to follow must be specified'
                        else:
                                reqid = value
                elif option == "--pid":
                        if (value == ""):
                                raise wcvParamException, 'process id to follow must be specified'
                        else:
                                pid = value
                else:
                        raise wcvParamException, 'Invalid option:', option
        ##
        ## Check for template File name
        ##
        if (not os.path.isfile(file)):
          raise wcvParamException, 'filename provided to follow request metric data does not exist'
        ##
        ## Can we open the file for read?
        ##
        try:
                inFile = open(file, "rU")
                inFile.close()
        except IOError:
          raise wcvParamException, '--file can not be read. Check file authorities'
        ##
        ## parent pid must be specified
        ##
        if (pid == ""):
          raise wcvParamException, '--pid must be specified'
        ##
        ## parent request-id must be specified
        ##
        if (reqid == ""):
          raise wcvParamException, '--reqid must be specified'
                
        return 0                        
##
## Compiles the proxy configuration file based on the template file and processing the
## "#!/include <file>" directives
##
def printRequestMetricTreeFromList(wcvIndex, wcvLevel, wcvPid, wcvIp, wcvReqId):
  global WCV_FILE_DATA
  if WCV_DEBUG:
          print "Entering printRequestMetricTreeFromList using wcvIndex=", wcvIndex
          print "Entering printRequestMetricTreeFromList using wcvLevel=", wcvLevel
          print "Entering printRequestMetricTreeFromList using ", str(len(WCV_FILE_DATA)), "data records"
          print "Entering printRequestMetricTreeFromList using wcvPid=", wcvPid
          print "Entering printRequestMetricTreeFromList using wcvIp=", wcvIp
          print "Entering printRequestMetricTreeFromList using wcvReqId=", wcvReqId

  regExPattern = getParentRegExPattern(wcvPid, wcvIp, wcvReqId)
  regExObject=re.compile(regExPattern)

  while (wcvIndex >= 0):
    ##
    ## Read thru the file containing request metric data until the first record is found
    ##
    if regExObject.match(WCV_FILE_DATA[wcvIndex]):
      if WCV_DEBUG:
        print "Matching record found:", WCV_FILE_DATA[wcvIndex]
      
      curIp = getCurrentValue(WCV_FILE_DATA[wcvIndex], "ip", ",.*")
      curPid = getCurrentValue(WCV_FILE_DATA[wcvIndex], "pid", ",.*")
      curReqId = getCurrentValue(WCV_FILE_DATA[wcvIndex], "reqid", ",.*")
      curType = getCurrentValue(WCV_FILE_DATA[wcvIndex], "type", "\ .*")
      curDetail = getCurrentValue(WCV_FILE_DATA[wcvIndex], "detail", "\ .*")
      curElapsed = getCurrentValue(WCV_FILE_DATA[wcvIndex], "elapsed", "")
      
      printLine(str(wcvLevel), curIp, curPid, curReqId, curElapsed, curType, curDetail )
      ##
      ## Recursion ...
      ##
      printRequestMetricTreeFromList(wcvIndex - 1, wcvLevel+1, curPid, curIp, curReqId)

    ##
    ## decrease index
    wcvIndex = wcvIndex - 1
      
##
## Reads the file with the data and triggers processing
##
def printRequestMetricTree(wcvFile, wcvPid, wcvIp, wcvReqId):
  if WCV_DEBUG:
          print "Entering printRequestMetricTree using wcvFile=", wcvFile
          print "Entering printRequestMetricTree using wcvPid=", wcvPid
          print "Entering printRequestMetricTree using wcvIp=", wcvIp
          print "Entering printRequestMetricTree using wcvReqId=", wcvReqId

  global WCV_FILE_DATA
  try:
    inFile = open(wcvFile, "rU")

    WCV_FILE_DATA = inFile.readlines()

    inFile.close()
  except IOError:
    raise wcvParamException, 'I/O exception raised while processing the input file'

  printRequestMetricTreeFromList (len(WCV_FILE_DATA) - 1, 0, wcvPid, wcvIp, wcvReqId)
##
## Main
##
def main():
        ##
        ## General prologue
        ##
        WCV_SCRIPTNAME = sys.argv[0]
        WCV_DEBUG = wcvSetDebugSwitch()
        if WCV_DEBUG:
                print "Script name=", WCV_SCRIPTNAME
                print "WCV_DEBUG=", WCV_DEBUG
        ##
        ## Split options
        ##
        sysArgv = sys.argv
        if WCV_DEBUG:
                print "DEBUG: sys.argv=", sys.argv
                print "DEBUG: sysArgv=", sysArgv

        try:
                opts, args = getopt.gnu_getopt(sysArgv, "?n:", ["ip=", "pid=", "file=", "reqid="])
        except getopt.GetoptError, err:
                printUsage(WCV_SCRIPTNAME)
                print ">> Called exception: " + str(err)
                sys.exit(2)

        if WCV_DEBUG:
                print "DEBUG: opts after getopt.getopt =", opts
                print "DEBUG: args after getopt.getopt =", args
        ##
        ## Check the parameters being passed
        ##
        try:
                checkParm(opts, WCV_SCRIPTNAME)
        except (wcvParamException, wcvException), err:
                print ">> Caught exception: " + str(err) + " by checkParm"
                return 2

        ##
        ## First check if "help" is requested
        ##
        if wcvCheckHelp (opts):
                printUsage(WCV_SCRIPTNAME)
                return 0
        ##
        ## processing of the command. Set the input parameters. Defaut them as ".*"
        ##                      
        wcvFile = wcvSetFile(opts)
        wcvPid = wcvSetPid(opts)
        wcvIp = wcvSetIp(opts)
        wcvReqId = wcvSetReqId(opts)
        
        
        if WCV_DEBUG:
                print "wcvFile =",  wcvFile
                print "wcvPid =", wcvPid
                print "wcvIp =", wcvIp
                print "wcvReqId =", wcvReqId

        printHeader(wcvIp, wcvPid, wcvReqId)
        printRequestMetricTree(wcvFile, wcvPid, wcvIp, wcvReqId)

        return 0

        ###################### end of main ###########################
##
## Some globals ...
##
WCV_SCRIPTNAME = "requestmetrics"
WCV_DEBUG = wcvSetDebugSwitch()
##
## Using global to store file data as this can be quite big ... call by value would
## increate memory requrirements
##
WCV_FILE_DATA=[]
        
if __name__ == "__main__":
    main()
