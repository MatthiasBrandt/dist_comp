# -*- coding: utf-8 -*-
"""
Created on Fri May 18 22:47:01 2012

@author: Matti
"""

import pygame
import numpy

def sound(x, fs):
    pygame.mixer.init(frequency=fs, size=-16, channels=1, buffer=4096)
    sound = pygame.sndarray.make_sound(numpy.int16(x))
    pygame.mixer.Sound(sound)
    sound.play()
    
    return None
    
def soundsc(x, fs):
    x_normalized = normalize(x) * 2**15
    sound(x_normalized, fs)
    
    return None
    
def normalize(x):
    return x / max(abs(x))