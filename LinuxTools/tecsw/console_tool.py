#!/usr/bin/env python
import os
import sys
import fs
#--------------------
BLACK = 30
RED = 31
GREEN = 32
YELLOW = 33
BLUE = 34
MAGENTA = 35
CYAN = 36
WHITE = 37
#--------------------
DEFAULT = 0
LIGHT = 1
UNDERLINE = 4
BLINK = 5
#--------------------

TextColors = [BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE]
TextStyles = [DEFAULT, LIGHT, UNDERLINE, BLINK]

#--------------------
def GetTerminalSize():
    env = os.environ
    def ioctl_GWINSZ(fd):
        try:
            import fcntl, termios, struct, os
            cr = struct.unpack('hh', fcntl.ioctl(fd, termios.TIOCGWINSZ,
        '1234'))
        except:
            return
        return cr
    cr = ioctl_GWINSZ(0) or ioctl_GWINSZ(1) or ioctl_GWINSZ(2)
    if not cr:
        try:
            fd = os.open(os.ctermid(), os.O_RDONLY)
            cr = ioctl_GWINSZ(fd)
            os.close(fd)
        except:
            pass
    if not cr:
        cr = (env.get('LINES', 25), env.get('COLUMNS', 80))
    return int(cr[1]), int(cr[0])
#--------------------

def Clear():
    sys.stdin.flush()
    
    if fs.IsPosix():
        os.system('clear')
    else:
        os.system('cls')

#--------------------

def ColorText(msg, style=DEFAULT, forecolor = WHITE, backcolor = BLACK):
    if len(msg) == 0:
        return ""
    if not fs.IsPosix():
        return msg
    
    if TextColors.index(forecolor) < 0 :
        forecolor = WHITE
    if TextColors.index(backcolor) < 0 :
        backcolor = BLACK
    if TextStyles.index(style) < 0 :
        style = DEFAULT

    res = '\033[%d;%d;%dm%s\033[0m' % (style, forecolor, backcolor + 10, msg)
    return res

#--------------------    
    
if __name__ == '__main__':
    print ColorText('test')
    print GetTerminalSize()
