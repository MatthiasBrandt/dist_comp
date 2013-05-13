'''
Created on 12.05.2012

@author: Matti
'''
# performs a transient detection by analysing the group delay
# implemented after "Transient Detection with Absolute Discrete Group Delay" by V. Gnann and M. Spiertz

import math
import numpy
import matplotlib.pyplot as plot
import scipy.ndimage as ndimage
import scipy
import numpy.fft as fft
from faktor.dsp.common import apply_threshold
#import bottleneck as bn
#import faktor.dsp.common.maxfilt1d as maxfilt



def principal_argument(mat_phase):
#    print(numpy.mod(mat_phase + math.pi, -2*math.pi) + math.pi)
    return numpy.mod(mat_phase + math.pi, -2*math.pi) + math.pi


def discrete_group_delay(mat_phase):
    print(principal_argument(numpy.diff(mat_phase, n=1, axis=0)))
    return principal_argument(numpy.diff(mat_phase, n=1, axis=0))

def average_absolute_discrete_group_delay(mat_phase):
#    print(mat_phase)
    dgd = discrete_group_delay(mat_phase)
    
    temp = ndimage.maximum_filter1d(numpy.abs(dgd), 5, axis=0, output=None, mode="constant", cval=0.0, origin=2)
#    temp = bn.move_max(numpy.abs(dgd), 5, axis=0)
#    temp = maxfilt.maxfilt1d(numpy.abs(dgd), 5) # meine implementierung
#    print(temp)
#    scipy.io.savemat('e:\\dropbox\\applesoup\\knietrommler\\v2\\python_export_dgd.mat', {'dgd':dgd, 'maxfilt_output':temp})
    return numpy.mean(temp, axis=0)

def find_transients(x):
    L_block = 1024/2
    L_feed = L_block / 4
    L_DFT = L_block
    
    L_x = len(x)
    
    N_bins = L_DFT/2+1
    
    N_blocks = int(math.floor( (L_x - (L_block-L_feed)) / L_feed ))

    # the spectral analysis window
    #vec_window = numpy.hanning(L_block)
    vec_window = scipy.signal.windows.chebwin(L_block, 100)

    # initialize an empty matrix that will be filled with the spectrogram
    mat_spectrogram = numpy.empty([N_bins, N_blocks], 'complex')

    # compute the spectrogram
    for p in range(N_blocks):
        idx_start = p * L_feed
        idx_end = p * L_feed + L_block
        
        x_p = x[idx_start:idx_end]
        
        # spectrum
        X_p = fft.rfft(x_p * vec_window, L_DFT, 0)
        
        mat_phase = numpy.angle(mat_spectrogram)
            
        mat_spectrogram[:, p] = X_p
        
    threshold = 2.8
    aadg = average_absolute_discrete_group_delay(mat_phase)
    plot.plot(aadg)
    plot.title('aadg')
    plot.show()
    idx_transients = apply_threshold.apply_threshold(-aadg, -threshold)
    
    idx_transients = idx_transients * L_feed
    
    return idx_transients

if __name__ == '__main__':
    print('teste diese funktion')
    test_array = numpy.random.uniform(low=0, high=numpy.pi, size=[257, 100])
    aadg = average_absolute_discrete_group_delay(test_array)
    
    #plot.plot(aadg)
    #plot.show()
    
    idx_transients = find_transients(test_array)
   
    print(aadg)
    
    print(idx_transients)