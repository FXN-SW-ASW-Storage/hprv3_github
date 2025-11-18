#!/usr/bin/env python
import os
import sys
import fs
#=======================================================================
class ConfigHandler:

    __FileName = ''
    __Delimiter = '='
    __Comment = '#'
    __DataTable = dict()

    #---------------------------------------
    
    def __init__(self, filename, delimiter = '=', comment = '#'):
        self.__FileName = filename
        self.__Delimiter = delimiter
        self.__Comment = comment
        self.__ParseValues()

    #---------------------------------------

    def __Save(self):
        buff = []
        for key in sorted(self.__DataTable.keys()):
            buff.append('%s=%s' % (key, self.__DataTable[key]))
        fs.FileWriteLines(buff, self.__FileName)
        '''
        buff = []      
        for keyvalue in self.__DataTable.items():
            buff.append('%s=%s' % (keyvalue[0], keyvalue[1]))
        fs.FileWriteLines(buff, self.__FileName)
        '''
    #---------------------------------------
        
    def __ParseValues(self):
        self.__DataTable.clear()
        if not fs.IsFileExists(self.__FileName):
            #print 'File Not Found: \"%s\"' % self.__FileName
            return []
        for line in fs.FileReadLines(self.__FileName):
            if line.startswith(self.__Comment): continue
            if not self.__Delimiter in line: continue
            keyvalue = line.split(self.__Delimiter)
            key, value = keyvalue[0].strip(), keyvalue[1].strip()
            if len(key) == 0: continue
            #print '[%s]=%s' % (key, value) 
            self.__DataTable[key] = value

    #---------------------------------------
            
    def GetValue(self, key):
        return self.__DataTable[key]

    #---------------------------------------
            
    def GetValueDef(self, key, defval):
        try:
            return self.GetValue(key)
        except:
            self.SetValue(key, defval)
            return defval
    #---------------------------------------

    def SetValue(self, key, value):
        if type(value) is not str:
            strvalue = str(value)
        else:
            strvalue = value
        self.__DataTable[key] = strvalue
        self.__Save()
        
    #---------------------------------------

    def SetValueByQuery(self, key):
        value = raw_input('%s:' % key)
        self.SetValue(key, value)
        
    #---------------------------------------
    
    def Print(self):
        print 'File Name: %s' % self.__FileName
        for key in self.__DataTable:
            print '%s = %s' % (key, self.__DataTable[key])
            
    #---------------------------------------
    
    def Dump(self):
        res = dict()
        for key in self.__DataTable:
           res[key] = self.__DataTable[key]
    
    #---------------------------------------
        
#========================================================================
if __name__ == '__main__':
    ch = ConfigHandler('D:\\test.txt', '=')
    ch.SetValue('value1', 123)
    ch.SetValue('value2', 'abc')
    print ch.GetValue('value1')
    print ch.GetValue('value2')
    print ch.GetValueDef('value3', 'ABC')
    
    
