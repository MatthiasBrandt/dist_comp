# -*- coding: utf-8 -*-
"""
Created on Wed May 16 10:35:45 2012

@author: Matti
"""

from find_start_and_end_of_hit import *
import scipy.io as matlab_io
import unittest

class TestMatlabComparison(unittest.TestCase):

    def setUp(self):
        dict_matlab = {}

        idx_segment = 6

        matlab_io.loadmat('matlab_results.mat', mdict=dict_matlab, struct_as_record=True)
        
        self.idx_start = dict_matlab['idx_offset_start']
        self.idx_end = dict_matlab['idx_offset_end']

        #list_idx_start = [for x in range(23): dict_matlab['st_segments'][0][0][x]]
        #self.list_idx_start = dict_matlab['st_segments'][0]['idx_start'][idx_segment]
        #self.list_idx_end = dict_matlab['st_segments'][0]['idx_end'][idx_segment]

        #self.vec_x = dict_matlab['st_segments'][0]['x'][idx_segment]
        
        self.vec_x = dict_matlab['vec_x_area']

        self.fs = dict_matlab['fs']

    #knownValues = (dict_matlab['st_segments'][0][0][dict_matlab['idx']-1])

    def testMatlabComparison(self):
        (idx_start, idx_end) = find_start_and_end_of_hit(self.vec_x, self.fs)
        self.assertEqual(self.idx_start, idx_start)
        self.assertEqual(self.idx_end, idx_end)

    def testChoice(self):
        pass

if __name__ == '__main__':
    unittest.main()