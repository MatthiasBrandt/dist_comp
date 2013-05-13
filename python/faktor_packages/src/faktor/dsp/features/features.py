# -*- coding: utf-8 -*-
"""
Created on Fri May 25 18:41:08 2012

@author: matheo
"""

import numpy

class feature:
    # class attributes
    L_block = []
    L_feed = []
    
    def __init__(self, L_block, L_feed):
        self.L_block = L_block
        self.L_feed = L_feed
    

if __name__ == '__main__':    
    # generate some example data vector
    L_data = 100
    vec_data = numpy.random.rand(L_data, 1)
    vec_data = numpy.mat(range(L_data)).transpose()
    
    L_block = 10
    L_feed = 2