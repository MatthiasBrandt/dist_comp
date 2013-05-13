# -*- coding: utf-8 -*-
"""
Created on Fri May 18 20:55:37 2012

@author: Matti
"""

import numpy as np
from faktor.dsp.common.sound import *

def add_beep(x, vec_t, fs):
#    vec_k = [c * fs for c in vec_t]
    vec_k = vec_t * fs
    
    N_t = len(vec_t)
    
    # generate a beep signal
    x_beep = beep(1000, 50./1000, fs)
    L_x_beep = len(x_beep)

    y_beep = normalize(x)
    
    L_x = len(x)
    
    for a in range(N_t):
        if vec_k[a] + L_x_beep - 1 < L_x:
            print('a = %.0f' % a)
            print('vec_k[a] = %.0f' % vec_k[a])
            cur_idx_start = np.int(vec_k[a][0])
            y_beep[cur_idx_start:cur_idx_start+L_x_beep] = \
            y_beep[cur_idx_start:cur_idx_start+L_x_beep] + \
            x_beep

    return y_beep

def beep(f, T, fs):
    Omega = 2 * np.pi * f / fs
    
    L = np.int(np.floor(T * fs))
    
    vec_k = range(L)
    
    x_beep = [np.sin(Omega * c) for c in range(L)]
    
    return x_beep

if __name__ == '__main__':
    f = 1000
    T = 0.1
    fs = 8000
    
    x_beep = beep(f, T, fs)
    
    x_beep_long =10 * x_beep
    
    y_beep_long = add_beep(x_beep_long, [3], fs)