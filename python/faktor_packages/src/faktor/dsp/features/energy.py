# -*- coding: utf-8 -*-
"""
Created on Tue May 29 09:50:08 2012

@author: matheo
"""

from faktor.dsp.features import *

class energy(feature):
    def __init__(self):
        feature.__init__(self)

if __name__ == '__main__':
    my_energy = energy()