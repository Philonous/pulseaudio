{-
    Copyright 2016 Markus Ongyerth

    This file is part of pulseaudio-hs.

    Monky is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Monky is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with pulseaudio-hs.  If not, see <http://www.gnu.org/licenses/>.
-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-|
Module      : Data.Time
Description : provides the time type used by this package and a few functions on it
Maintianer  : ongy
Stability   : experimental

-- Portability : Linux (Not quite sure if headers are specific, might be POSIX)

Pulseaudio uses struct timeval for time. Since the time package on hackage does not
export the internal functions, this module exports a type and functions for that
type.
-}
module Data.Time
    ( PATime
    , getTime
    , addSeconds
    , addNSeconds
    , addTimes
    , getDiff
    , timeToUS
    , timeFromUS
    , dummyTime

    )
where


-- PATime is defined in here, for better hiding :)
import Data.Time.Internal
import Data.Word (Word)

import Foreign.Ptr
import Foreign.Storable
import Foreign.C.Types
import Foreign.Marshal.Alloc

#include <time.h>

foreign import ccall unsafe "clock_gettime" clock_gettime :: CInt -> Ptr PATime -> IO CInt


-- We don't take an clockid argument for now, this is PA use, not general time
-- library
-- |Get the current system time in real time (wallclock)
getTime :: IO PATime
getTime = alloca $ \ptr -> do
    ret <- clock_gettime #{const CLOCK_REALTIME} ptr
    if ret /= 0
       then error "This should not happen, PAs getTime failed"
       else peek ptr

-- |Add seconds to a 'PATime'
addSeconds :: Integral a => a -> PATime -> PATime
addSeconds x (PATime s n) = (PATime (s + fromIntegral x) n)

-- |Add nanoseconds to a 'PATime'
addNSeconds :: Integral a => a -> PATime -> PATime
addNSeconds x (PATime s n) =
    let new = n + fromIntegral x
        cap = 1000 * 1000 * 1000
        over = if new > cap
                  then 1
                  else 0
        capped = new `mod` cap
    in PATime (s + over) capped

-- |Add two 'PATime's together
addTimes :: PATime -> PATime -> PATime
addTimes (PATime s n) = addSeconds s . addNSeconds n

-- |Get the difference between to times.
getDiff :: PATime -> PATime -> PATime
getDiff l@(PATime ls ln) r@(PATime rs rn) = if l < r
    then error "PAs getDiff only works if the first argument is greater"
    else let new = ln -rn
             cap = 1000 * 1000 * 1000
             over = if new < 0
                     then 1
                     else 0
             capped = new `mod` cap
         in PATime (ls - rs - over) capped

-- |Convert from Microseconds to 'PATime'
timeFromUS :: Word -> PATime
timeFromUS x = let cap = 1000 * 1000 in
    PATime (x `div` cap) $ fromIntegral (x `mod` cap * 1000)

-- |Convert a 'PATime' to Microseconds
timeToUS :: PATime -> Word
timeToUS (PATime s ns) =
    s * 1000 * 1000 + fromIntegral ns `div` 1000

-- |A dummy time value, do not use to calculate, only if guaranteed to be
-- ignored
dummyTime :: PATime
dummyTime = PATime 0 0
