# -*- coding: utf-8 -*-
"""
Created on Wed May 16 10:35:45 2012

@author: Matti
"""

import find_start_and_end_of_hit
import unittest
import scipy.io as matlab_io

class MatlabComparison(unittest.TestCase):
    dict_matlab = {}
    matlab_io.loadmat('matlab_results.mat', mdict=dict_matlab)
    
    #list_idx_start = [for x in range(23): dict_matlab['st_segments'][0][0][x]]
    list_idx_start = dict_matlab['st_segments'][0][0][0]
    list_idx_end = dict_matlab['st_segments'][0][0][1]
    
    vec_x = dict_matlab['st_segments'][0][0][2]
    
    #knownValues = (dict_matlab['st_segments'][0][0][dict_matlab['idx']-1])
    
    print('bla')
    
    def TestMatlabComparison(self):
        print('bla1')
        #(idx_start, idx_end) = find_start_and_end_of_hit(self.vec_x)
        #self.assertEqual(self.list_idx_start, idx_start)
        #self.assertEqual(self.list_idx_end, idx_end)
        print('bla2')

if __name__ == '__main_':
    unittest.main()