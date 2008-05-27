                        /*** /

This file is part of Golly, a Game of Life Simulator.
Copyright (C) 2008 Andrew Trevorrow and Tomas Rokicki.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

 Web site:  http://sourceforge.net/projects/golly
 Authors:   rokicki@gmail.com  andrew@trevorrow.com

                        / ***/
/**
 *   Encapsulate a class capable of rendering a life universe.
 *   Note that we only use fill rectangle calls and blitbit calls
 *   (no setpixel).  Coordinates are in the same coordinate
 *   system as the viewport min/max values.
 *
 *   Also note that the render is responsible for deciding how
 *   to scale bits up as necessary, whether using the graphics
 *   hardware or the CPU.  Blits will only be called with
 *   reasonable bitmaps (32x32 or larger, probably) so the
 *   overhead should not be horrible.  Also, the bitmap must
 *   have zeros for all pixels to the left and right of those
 *   requested to be rendered (just for simplicity).
 *
 *   Bitmap width is in 32-bit *words*.  Assumes 32-bit ints.
 *
 *   If clipping is needed, it's the responsibility of these
 *   routines, *not* the caller (although the caller should make
 *   every effort to not call these routines with out of bound
 *   values).
 */
#ifndef LIFERENDER_H
#define LIFERENDER_H
class liferender {
public:
   liferender() {}
   virtual ~liferender() ;

   // killrect is only ever used to draw background (ie. dead cells)
   virtual void killrect(int x, int y, int w, int h) = 0 ;

   /*
    *   If bmscale > 1 it must be a power of two, and the x/y/w/h
    *   values are still in terms of the viewport (that is, they
    *   are already multiplied appropriately).
    */
   virtual void blit(int x, int y, int w, int h, int *bm, int bmscale=1) = 0 ;

   // AKT !!!???
   // pixblit is used to draw a pixel map which contains w x h x 3 bytes;
   // ie. each pixel has 3 r,g,b values
   virtual void pixblit(int x, int y, int w, int h, char* pm, int pmscale) = 0 ;
} ;
#endif
