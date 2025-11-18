#!/usr/bin/env python
import os
import sys
import time
import serial
import re
import fs

class DebugPort():

    __se = None
    __PROMPT = '^EEB[0-1]0(~| )>$'
    __INVALIDCOMMAND = 'Invalid Command. Use help command for CLI Command Help.'
    __PASSWORDREQUEST = 'Password is empty. Please set a password.'
    __CurrentConsole = -1
    __CurrentRemote = False
    __Name = ''
    __LogFile = None
    
    #-----------------------------------------------------------------------------
    
    def __init__(self, portName, baudRate = 115200, wTO = None, rTO = 2, logFile = None):
        try:
            self.__Name = portName
            self.__se = serial.Serial(portName, baudRate, timeout = rTO, writeTimeout = wTO)
            self.__LogFile = logFile
        except ValueError as ve:
            raise StandardError(str(ve))
        except serial.SerialException as se:
            raise StandardError(str(se))
            
    #-----------------------------------------------------------------------------
    
    def __del__(self):
        try:
            self.__se.close()
        except:
            return
        
    #-----------------------------------------------------------------------------
    
    def GetName(self):
        return self.__Name
    
    #-----------------------------------------------------------------------------
    
    def __ShowCurrentConsole(self):
        print 'Current Console: %d' % (self.__CurrentConsole)
        print 'Current Remote = %s' % (self.__CurrentRemote)
        
    #-----------------------------------------------------------------------------
        
    def ChangeConsole(self, console):
        if not console in range(0,2):
            return
        if self.__CurrentConsole < 0:
            self.Send('')
            self.Recv()
        if self.__CurrentConsole == console:
            return
        if self.__CurrentRemote == True:
            self.Send('exit')
        else:
            self.Send('remote %d' % console)
        self.Recv()
    
    #-----------------------------------------------------------------------------    
         
    def Send(self, cmd):
        self.__se.flushInput()
        self.__se.flushOutput()
        #print cmd
        
        if self.__LogFile is not None:
            fs.FileWriteLines(['\t--->', cmd, '\t==SEND END=='], self.__LogFile, True)
            
        self.__se.write('%s\r' % cmd)
        time.sleep(0.1)
    
    #-----------------------------------------------------------------------------
    
    def SendLines(self, cmdlines):
        if not isinstance(cmdlines, list):
            print 'Not List'
            return
        cmd = ''
        
        if self.__LogFile is not None:
            fs.FileWriteLines(['\t--->'], self.__LogFile, True)
            fs.FileWriteLines(cmdlines, self.__LogFile, True)
            fs.FileWriteLines(['\t==SEND END=='], self.__LogFile, True)
        
        for line in cmdlines:
            if len(cmd) == 0:
                cmd = line
            else:
                cmd = '%s\r\n\n\r%s' % (cmd, line)
        #self.Send(cmd)
        self.__se.write('\n\r%s\r\n' % cmd)
        time.sleep(0.1)
    
    #-----------------------------------------------------------------------------
  
    def Recv(self, count = 0):
        buff = self.__se.readlines()
        if self.__LogFile is not None:
            fs.FileWriteLines(['\t<---'], self.__LogFile, True)
            fs.FileWriteLines(buff, self.__LogFile, True)
            fs.FileWriteLines(['\t==READ END=='], self.__LogFile, True)
        #print buff
        res = []
        for line in buff:
            line = line.strip()
            if len(line) == 0:
                continue
            if line == self.__PASSWORDREQUEST:
                continue
            if line == self.__INVALIDCOMMAND:
                continue
            if re.search(self.__PROMPT, line) != None:
                self.__CurrentRemote = ('~' in line)
                self.__CurrentConsole = (int)(line[3])
                break
            res.append(line)
            
        if count <= 0:
            return res
        return res[0:count-1]
        
    #-----------------------------------------------------------------------------

#----------------------------------------------------
