#!/usr/bin/env python
import sys
import os
cwd = os.path.dirname(os.path.abspath(__file__))
if not cwd in sys.path:
    sys.path.append(cwd)
print 'Package [tecsw] Loaded...'
__all__ = ['config_handler', 'console_tool', 'debugport']
