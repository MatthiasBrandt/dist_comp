'''
Created on 12.05.2012

@author: Matti
'''

from numpy import *
from faktor.dsp.common.find_sections import *
from matplotlib.pyplot import *
#import IPython

def apply_threshold(vec_data, threshold):
    idx_above_threshold = nonzero(vec_data > threshold)[0]
    
    if len(idx_above_threshold) == 0:
        return []
        
    list_regions = find_sections(idx_above_threshold)
    
    N_regions = len(list_regions)
    
    vec_idx = zeros((N_regions, 1))
    
    for a in range(N_regions):
        idx_start = list_regions[a]['idx_start']
        idx_end = list_regions[a]['idx_end']
        if idx_start == idx_end:
            temp_array = vec_data[idx_start]
        else:
            temp_array = vec_data[idx_start:idx_end]
            
        temp_1 = argmax(temp_array)
        vec_idx[a] = list_regions[a]['idx_start'] + temp_1 
        
    return vec_idx


if __name__ == '__main__':
    temp_data = random.rand(30, 1)
#    temp_data = array([0, 0.1, 0.2 , 1, 0.4 ,.3])
    threshold = 0.5
    #ioff()
    plot(temp_data)
#    draw()
    #show(True)
    #ioff()
    
    
    vec_idx = apply_threshold(temp_data, threshold)
    print(vec_idx)
    
    
    plot(vec_idx, temp_data[list(vec_idx[:,0])], 'ro')
    legend(['data', 'above threshold'])
    show()