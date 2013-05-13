# -*- coding: utf-8 -*-
"""
Created on Mon May 14 10:19:13 2012

@author: Matti
"""
import scipy as sp
import scipy.signal as sgn
import numpy as np
import scikits.talkbox as talkbox
import pdb
import math
import matplotlib.pyplot as plt

def find_start_and_end_of_hit(vec_x, fs, vec_idx_transients):

    idx_start = []
    idx_end = []
    
    L_x = len(vec_x)
    
    # ___ some user parameters___
    T_window = 5 # sec
    L_window = int(math.floor(T_window * fs))
    if sp.remainder(L_window, 2) == 1:
        L_window = L_window + 1
        
    L_half_window = L_window / 2
            
    for cur_idx_transient in vec_idx_transients:
        idx_start = int(cur_idx_transient)- L_half_window
        idx_end = int(cur_idx_transient) + L_half_window
        
        if idx_start < 0: idx_start = 0
        if idx_end > L_x: idx_end = L_x
        
        print("idx_start: {}".format(idx_start) )
        print("idx_end: {}".format(idx_end))
        
        #pdb.set_trace()        
        
        cur_vec_x = vec_x[idx_start:idx_end+1]
    
        vec_envelope = np.abs(sgn.hilbert(vec_x, axis=0))
        
        plt.figure(2)
        plt.plot(cur_vec_x)
        plt.hold(True)
        plt.plot(vec_envelope)
        plt.legend(['input signal', 'hilbert envelope'])
        plt.show()
        
        # calculate a threshold
        #if b_debug
        #    tempfig('transient start search');
        #    plot([x vec_envelope]);
        #end
        
        # whiten the signal via lpc
    #    vec_a = [1, 2, 3] # lpc(x,32)
        (vec_a, vec_prediction_error, vec_k) = talkbox.lpc(vec_x, 32, axis=0)   
        vec_prediction_error = sgn.lfilter(vec_a, 1, vec_x, axis=0)
#        print(vec_prediction_error)

        plt.figure(3)
        plt.plot(vec_prediction_error)
        plt.title('prediction error')
        plt.show()
        #vec_signal_whitened = scipy.filter([0 -a(2:end)], 1, x);
        #vec_signal_diff = x- vec_signal_whitened;
        
        L_vec_x = len(vec_x)
        
        idx_mid = (L_vec_x-1) / 2;
        if sp.mod(idx_mid, 1) > 0:
            idx_mid = sp.floor(idx_mid)
        
        vec_prediction_error_power = vec_prediction_error**2
        
        threshold = 0.9 * np.max(vec_prediction_error_power)
        
        
        
        #idx_temp_to_the_left = idx_mid - find(vec_prediction_error_power(idx_mid:-1:1) > threshold, 1, 'first') + 1;
        idx_temp_to_the_left = idx_mid - sp.nonzero(vec_prediction_error_power[idx_mid:0:-1] > threshold)[0] + 1
        #idx_temp_to_the_right = find(vec_prediction_error_power(idx_mid:end) > threshold, 1, 'first') + idx_mid - 1;
        idx_temp_to_the_right = idx_mid+ sp.nonzero(vec_prediction_error_power[idx_mid-1:L_vec_x] > threshold)[0]
        
        if len(idx_temp_to_the_left) == 0:
            idx_start = idx_temp_to_the_right[0]
            
        elif len(idx_temp_to_the_right) == 0:
            idx_start = idx_temp_to_the_left[0]
            
        else:
            # which one is closer?
            if abs(idx_temp_to_the_left[0] - idx_mid) > abs(idx_temp_to_the_right[0] - idx_mid):
                idx_start = idx_temp_to_the_right[0]
            else:
                idx_start = idx_temp_to_the_left[0]
            
            #todo: think about this
        idx_start_decay = idx_start
        idx_start_transient = idx_start
    #
    #if b_debug
    #    tempfig('transient start search');
    #    hold on; plot(idx_start, vec_envelope(idx_start), 'Marker', 'o', 'MarkerFaceColor', 'r');
    #    plot(vec_signal_whitened, 'g');
    #    hold off;
    #    tempfig('prediction error');
    #    plot(vec_prediction_error_power);
    #    hold on;
    #    line([1 length(vec_prediction_error_power)], repmat(threshold, 1, 2), 'Color', 'r', 'LineWidth', 2); hold off;
    #end
    
        # filter that thing
        order_filter_smooth = 300.
        vec_b_filter_smooth = 1 / order_filter_smooth * sp.ones(order_filter_smooth,)
        vec_a_filter_smooth = [1]
        
        #disp(vec_b_filter_smooth)
    #vec_b_smooth = 1/order_smoothing_filter * ones(order_smoothing_filter, 1);
    #vec_a_smooth = 1;
    #x_envelope_smoothed = filtfilt(vec_b_smooth, vec_a_smooth, x_envelope);
        vec_envelope_smoothed = sgn.filtfilt(vec_b_filter_smooth, vec_a_filter_smooth, vec_envelope, padtype=None)
    #tempfig('selected waveform');
    #% subplot(211);
    #hold on, plot((0:length(x)-1) / fs, x_envelope_smoothed, 'r'); hold off;
    #
        # try to find the beginning of the decay phase
        temp_max = np.max(vec_envelope_smoothed, axis=0)
    #    disp(temp_max)
    #temp_max = max(x_envelope_smoothed);
    #tempfig('selected waveform'); hold on;
    #% subplot(211);
    #plot((idx_start_decay-1) / fs, temp_max, 'Marker', 'o', 'MarkerSize', 15, 'Color', 'g');
    #
    #% tempfig('selected waveform'); hold on;
    #% subplot(212);
    #% plot((0:length(x)-2) / fs, diff((x_envelope_smoothed)), 'r'); hold off;
    #
    #tempfig('envelope histogram');
    #hist(x_envelope_smoothed, 100);
    #
        # find the end of the decay phase
        threshold = np.percentile(vec_envelope_smoothed[idx_start_decay:L_vec_x], 30)
    #threshold = quantile(x_envelope_smoothed(idx_start_decay:end), 0.3);
    #idx_end_decay = find(x_envelope_smoothed(idx_start_decay:end) <= threshold, 1, 'first') + idx_start_decay-1 ;
        idx_end_decay = sp.nonzero(vec_envelope_smoothed[idx_start_decay:L_vec_x] <= threshold)[0][0] + idx_start_decay
    #tempfig('selected waveform'); hold on;
    #% subplot(211);
    #plot((idx_end_decay-1) / fs, x_envelope_smoothed(idx_end_decay), 'Marker', 'o', 'MarkerSize', 15, 'Color', 'g');
    #
    #
    #% now model the decay
    #% (to estimate the decay time)
    #if true
    #    val_start = (x_envelope_smoothed(idx_start_decay));
    #    val_end = (x_envelope_smoothed(idx_end_decay));
    #    decay_constant = 1*( log(val_end) - log(val_start) ) / (idx_end_decay - idx_start_decay);
    #else
    #    val_start = x_envelope_smoothed(idx_start_decay);
    #    
    #end
    #    
    #    % plot the model
    #    x_model = (val_start) * exp(1*decay_constant * (0:(idx_end_decay - idx_start_decay))');
    #    tempfig('selected waveform'); hold on;
    #    plot((idx_start_decay:idx_end_decay) / fs, x_model, 'k');
    #    
    #    tau_decay_ms = -1 / (decay_constant * fs) * 1000
    #    
    
        idx_end_transient = idx_end_decay
        
        print('idx_start_transient: {}'.format(idx_start_transient))
        print('idx_end_transient: {}'.format(idx_end_transient))
    
    return (idx_start_transient, idx_end_transient)

if __name__ == '__main__':
    vec_x = sp.random.randn(100, 1)
    fs = 8000
    
    vec_idx_start, vec_idx_end = find_start_and_end_of_hit(vec_x, fs)