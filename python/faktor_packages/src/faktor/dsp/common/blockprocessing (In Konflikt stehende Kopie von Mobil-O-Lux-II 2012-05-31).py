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
    
    def __init__(self, L_block, L_feed, L_x, fs):
        self.L_block = L_block
        self.L_feed = L_feed
        self.L_x = L_x
        self.fs = fs
        self.N_blocks = int(numpy.floor( (L_x - (L_block-L_feed))/L_feed))
        self.vec_t = [x/fs for x in range(L_x)]
    
    def N_blocks(self):
        return self.N_blocks
    
    def vec_t(self):
        return self.vec_t
    
    def idx_block(self, p):
        idx_start = p * self.L_feed
        idx_end = p* self.L_feed + L_block
        return range(idx_start, idx_end)

if __name__ == '__main__':
    vec_x = numpy.random.randn(100, 1)
    
    L_block = 8
    L_feed = 4
    fs = 1
    
    bp = blockprocessing(L_block, L_feed, len(vec_x), fs)