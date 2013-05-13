# -*- coding: utf-8 -*-
"""
Created on Fri May 25 18:57:34 2012

@author: matheo
"""

import numpy

class blockprocessing:
    L_block = []
    L_feed = []
    L_x = 0
    N_blocks = 0
    
    def __init__(self, L_block, L_feed, L_x):
        self.L_block = L_block
        self.L_feed = L_feed
        self.L_x = L_x
        self.N_blocks = int(floor( (L_x - (L_block-L_feed))/L_feed))

if __name__ == '__main__':
    vec_x = numpy.random.randn(100, 1)
    
    L_block = 8
    L_feed = 4
    
    bp = blockprocessing(L_block, L_feed, len(vec_x))