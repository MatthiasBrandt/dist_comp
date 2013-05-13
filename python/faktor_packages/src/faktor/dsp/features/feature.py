# -*- coding: utf-8 -*-
"""
Created on Fri May 25 18:41:08 2012

@author: matheo
"""

from faktor.dsp.common.blockprocessing import *
import numpy

class feature:
    # class attributes
    L_block = []
    L_feed = []
    
    def __init__(self, L_block, L_feed):
        self.L_block = L_block
        self.L_feed = L_feed
        self.blockprocessing = blockprocessing(L_block, L_feed, 0, 1)
        
    def initialize(self, dict_parameters):
        pass
    
    def process(self):
        pass
    
    def set_writing_method(self, method):
        if lower(method) == 'memory':
            pass
        elif lower(method) == 'disk':
            pass
        else:
            raise('this writing method is unknown')
    
    

if __name__ == '__main__':    
    # generate some example data vector
    L_data = 100
    vec_data = numpy.random.rand(L_data, 1)
    vec_data = numpy.mat(range(L_data)).transpose()
    
    L_block = 10
    L_feed = 2
    
    my_feature = feature(L_block, L_feed)