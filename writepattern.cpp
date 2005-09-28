                        /*** /

This file is part of Golly, a Game of Life Simulator.
Copyright (C) 2005 Andrew Trevorrow and Tomas Rokicki.

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
#include "writepattern.h"
#include "lifealgo.h"
#include "util.h"          // for *progress calls
#include <cstdio>
#include <cstdlib>
#include <cstring>

#ifdef __WXMAC__
#define BUFFSIZE 4096      // 4K is best for Mac OS X
#else
#define BUFFSIZE 8192      // 8K is best for Windows and other platforms???
#endif

char outbuff[BUFFSIZE];
int outpos;
unsigned int currsize;     // current file size (for showing in progress dialog)
// using buffered putchar instead of fputc is about 20% faster on Mac OS X
void putchar(char ch, FILE *f) {
   if (outpos == BUFFSIZE) {
      fwrite(outbuff, 1, BUFFSIZE, f);
      outpos = 0;
      currsize += BUFFSIZE;
   }
   outbuff[outpos] = ch;
   outpos++;
}

// output of RLE pattern data is channelled thru here to make it easier to
// ensure all lines have <= 70 characters
void AddRun (FILE *f,
             char ch,
             unsigned int *run,        // in and out
             unsigned int *linelen)    // ditto
{
   unsigned int i, numlen;
   char numstr[32];

   if ( *run > 1 ) {
      sprintf(numstr, "%u", *run);
      numlen = strlen(numstr);
   } else {
      numlen = 0;                      // no run count shown if 1
   }
   if ( *linelen + numlen + 1 > 70 ) {
      putchar('\n', f);
      *linelen = 0;
   }
   i = 0;
   while (i < numlen) {
      putchar(numstr[i], f);
      i++;
   }
   putchar(ch, f);
   *linelen += numlen + 1;
   *run = 0;                           // reset run count
}

// write current pattern to file using RLE format
const char *writerle(FILE *f, lifealgo &imp, int top, int left, int bottom, int right)
{
   if ( imp.isEmpty() || top > bottom || left > right ) {
      // empty pattern
      fprintf(f, "x = 0, y = 0, rule = %s\n!\n", imp.getrule());
   } else {
      // do header line
      unsigned int wd = right - left + 1;
      unsigned int ht = bottom - top + 1;
      sprintf(outbuff, "x = %u, y = %u, rule = %s\n", wd, ht, imp.getrule());
      outpos = strlen(outbuff);

      // do RLE data
      unsigned int linelen = 0;
      unsigned int brun = 0;
      unsigned int orun = 0;
      unsigned int dollrun = 0;
      char lastchar;
      int cx, cy;
      
      // for showing accurate progress we need to add pattern height to pop count
      // in case this is a huge pattern with many blank rows
      double maxcount = imp.getPopulation().todouble() + ht;
      double accumcount = 0;
      int currcount = 0;

      for ( cy=top; cy<=bottom; cy++ ) {
         // set lastchar to anything except 'o' or 'b'
         lastchar = 0;
         currcount++;
         for ( cx=left; cx<=right; cx++ ) {
            int skip = imp.nextcell(cx, cy);
            if (skip + cx > right)
               skip = -1;           // pretend we found no more live cells
            if (skip > 0) {
               // have exactly "skip" dead cells here
               if (lastchar == 'b') {
                  brun += skip;
               } else {
                  if (orun > 0) {
                     // output current run of live cells
                     AddRun(f, 'o', &orun, &linelen);
                  }
                  lastchar = 'b';
                  brun = skip;
               }
            }
            if (skip >= 0) {
               // found next live cell in this row
               cx += skip;
               if (lastchar == 'o') {
                  orun++;
               } else {
                  if (dollrun > 0) {
                     // output current run of $ chars
                     AddRun(f, '$', &dollrun, &linelen);
                  }
                  if (brun > 0) {
                     // output current run of dead cells
                     AddRun(f, 'b', &brun, &linelen);
                  }
                  lastchar = 'o';
                  orun = 1;
               }
               currcount++;
            } else {
               cx = right + 1;  // done this row
            }
            if (currcount > 1024) {
               char msg[128];
               accumcount += currcount;
               currcount = 0;
               sprintf(msg, "File size: %.2g MB", double(currsize) / 1048576.0);
               if (lifeabortprogress(accumcount / maxcount, msg)) break;
            }
         }
         // end of current row
         if (isaborted()) break;
         if (lastchar == 'b') {
            // forget dead cells at end of row
            brun = 0;
         } else if (lastchar == 'o') {
            // output current run of live cells
            AddRun(f, 'o', &orun, &linelen);
         }
         dollrun++;
      }
      
      // terminate RLE data
      dollrun = 1;
      AddRun(f, '!', &dollrun, &linelen);
      putchar('\n', f);
      
      // flush outbuff
      fwrite(outbuff, 1, outpos, f);
   }
   return 0;
}

const char *writelife105(FILE *, lifealgo &)
{
   return "Not yet implemented!!!";
}

const char *writemacrocell(FILE *f, lifealgo &imp)
{
   if (imp.hyperCapable())
      return imp.writeNativeFormat(f);
   return "Not yet implemented.";
}

const char *writepattern(const char *filename, lifealgo &imp, pattern_format format,
                         int top, int left, int bottom, int right)
{
   FILE *f;
   f = fopen(filename, "w");
   if (f == 0) return "Can't create pattern file!";

   currsize = 0;
   lifebeginprogress("Writing pattern file");

   const char *errmsg;
   switch (format) {
      case RLE_format:
         errmsg = writerle(f, imp, top, left, bottom, right);
         break;

      case L105_format:
         // Life 1.05 format ignores given edges???
         errmsg = writelife105(f, imp);
         break;

      case MC_format:
         // macrocell format ignores given edges
         errmsg = writemacrocell(f, imp);
         break;

      default:
         errmsg = "Unsupported pattern format!";
   }
   
   lifeendprogress();
   fclose(f);
   if (isaborted())
      return "File contains truncated pattern.";
   else
      return errmsg;
}
