'''
Created on 13.05.2012

@author: Matti
'''

# yields the same results as my matlab implememtation

import numpy
import scipy.io as matlab_io

def maxfilt1d(mat_data, order):
    N_pre_post_samples = (order-1)/2
    
    N_columns = numpy.shape(mat_data)[1]
    N_rows = numpy.shape(mat_data)[0]
    
    mat_output = numpy.zeros((N_rows, N_columns))
    
    for a in range(N_pre_post_samples, N_rows-N_pre_post_samples):
        print(a)
        mat_output[ a,:] = numpy.max(mat_data[a-N_pre_post_samples:a+N_pre_post_samples+1,:], axis=0)
        
    matlab_io.savemat('e:\\dropbox\\applesoup\\knietrommler\\v2\\python_export_maxfilt.mat', {'mat_data':mat_data, 'mat_output':mat_output})
        
    return mat_output

if __name__ == '__main__':
    if False:
        temp_vec = numpy.random.normal(0, 1, (200, 100))
    else:
        mat_content = matlab_io.loadmat('e:\\dropbox\\applesoup\\knietrommler\\v2\\python_export_maxfilt.mat')
        temp_vec = mat_content['mat_data']
    
    
    mat_filtered = maxfilt1d(temp_vec, 5)
    
    print(mat_filtered)