import sys
import subprocess as sp
import os
import time

def cli_run(cmd):
    """function to run shell commands"""
    with sp.Popen(cmd, shell=True, stdout=sp.PIPE, stderr=sp.PIPE) as sout:
        return sout.stdout.read().decode("utf-8")

dump_page_range = {"0x00", "0x01", "0x02", "0x03", "0x10", "0x11", "0x13", "0x14", "0x20", "0x21", "0x22", "0x23", "0x24", "0x25", "0x26", "0x27", "0x28", "0x29", "0x2a", "0x2b", "0x2c", "0x2d", "0x2e", "0x2f", "0x30"}

dump_page_start = 159
dump_page_end = 176

def dump():
    #for page in sorted(dump_page_range):
    for page in range(dump_page_start, dump_page_end, 1):
        cmd = f"i2cset -y -f 53 0x50 0x7f {page}"
        print(cmd)
        os.system(cmd)
        #print(cli_run(cmd))
        time.sleep(1)
        
        if page == "0x00":
            cmd = f"i2ctransfer -y -f 53 w1@0x50 0 r256"
        else:
            cmd = "i2ctransfer -y -f 53 w1@0x50 128 r128 | awk \'{for(i=1;i<=NF;i++){printf $i\" \"; if(i%8==0){print \"\"}}}\'"
            #cmd = f"i2ctransfer -y -f 53 w1@0x50 128 r128"
        
        print(cmd)
        os.system(cmd)
        
        print("-----------------------")
        #print(cmd)
        #print(cli_run(cmd))

if __name__ == "__main__":
    dump()
    sys.exit(0)
