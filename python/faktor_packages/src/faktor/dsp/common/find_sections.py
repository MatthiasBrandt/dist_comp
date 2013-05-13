'''
Created on 12.05.2012

@author: Matti
'''

import numpy

def find_sections(vec_idx, L_min = 0):
    vec_diff_idx = numpy.diff(vec_idx, n=1, axis=0)
    
    idx_section_borders = numpy.hstack((numpy.nonzero(vec_diff_idx > 1)[0], len(vec_idx)-1))
    #idx_section_borders.
    
    list_sections = []
    
    cur_idx = 0
    for a in range(len(idx_section_borders)):
        cur_start = vec_idx[cur_idx]
        cur_end = vec_idx[idx_section_borders[a]]
        cur_len = idx_section_borders[a] - cur_idx + 1
        list_sections.append({'idx_start':cur_start, \
                              'idx_end':cur_end, \
                              'len' : cur_len})
        cur_idx = idx_section_borders[a]+1
    
    
    
    return list_sections
    
if __name__ == '__main__':
    vec_test = numpy.array([1, 2, 3, 4, 6, 7, 8, 9, 12, 13, 14, 15])
    print(find_sections(vec_test))