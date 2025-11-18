#!/usr/bin/env python
import os
import sys

#-----------------------------------------------------------------------

def IsPosix():
    return os.name == 'posix'
    
#-----------------------------------------------------------------------

def IsFileExists(fileName):
    return os.path.isfile(fileName)

#-----------------------------------------------------------------------

def FileReadLines(fileName):
    try:
        with open(fileName, 'r') as f:
            return f.readlines()
    except:
        return []
    
#-----------------------------------------------------------------------

def FileWriteLines(data, fileName, writeAppend = False):
    mode = 'w'
    if writeAppend:
        mode = 'a'
    try:
        with open(fileName, mode) as f:
            for line in data:
                line = line.strip()
                if len(line) == 0:
                    continue
                f.write('%s%s' % (line, os.linesep))
    except:
        return False
    return True
    
#-----------------------------------------------------------------------

def IsFolderExists(pathName):
    return os.path.exists(pathName) and not os.path.isfile(pathName)

#-----------------------------------------------------------------------

def CreateFolder(pathName):
    if IsFolderExists(pathName): 
        return True
    try:
        os.makedirs(pathName)
    except:
        return False
    return IsFolderExists(pathName)
    
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------

#-----------------------------------------------------------------------

#-----------------------------------------------------------------------

#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
    
  
