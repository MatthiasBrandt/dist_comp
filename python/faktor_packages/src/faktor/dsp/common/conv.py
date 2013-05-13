# -*- coding: utf-8 -*-
"""
Created on Thu Oct 18 21:20:03 2012

@author: matheo
"""

import numpy

def conv(vec_x_1, vec_x_2):
    """ one-dimensional convolution
    
    blablabla help
    """
    
    # determine the length of both vectors
    L_x_1 = numpy.size(vec_x_1, 0)
    L_x_2 = numpy.size(vec_x_2, 0)
    
    # calculate the length of the output vector
    L_y = L_x_1 + L_x_2 - 1
    
    # allocate memory for the output vector
    vec_y = numpy.zeros((L_y, 1))
    
    print "los:"
    
    for k in range(L_y):
        for n in range(k+1):
            if k-n < 0:
                continue
            if k >= L_x_1:
                first_fac = 1
            else:
                first_fac = vec_x_1[k]
            print k, n
            vec_y[k]=vec_y[k] + first_fac * vec_x_2[k-n]
            
    return vec_y
    
if __name__ == "__main__":
    vec_x_1 = numpy.array((1, 1, 1))
    vec_x_2 = numpy.array((1, 1, 1))
    
    print conv(vec_x_1, vec_x_2)