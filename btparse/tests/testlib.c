/* ------------------------------------------------------------------------
@NAME       : testlib.c
@INPUT      : 
@OUTPUT     : 
@RETURNS    : 
@DESCRIPTION: Code common to all btparse test programs.
@GLOBALS    : 
@CALLS      : 
@CALLERS    : 
@CREATED    : 1997/09/26, Greg Ward
@MODIFIED   : 
@VERSION    : $Id: testlib.c 7283 2009-05-05 18:07:47Z ambs $
-------------------------------------------------------------------------- */

#include "bt_config.h"
#include <stdlib.h>
#include <stdio.h>
#include "testlib.h"
#include "my_dmalloc.h"


FILE *open_file (char *basename, char *dirname, char *filename)
{
   FILE * file;

   sprintf (filename, "%s/%s", dirname, basename);
   file = fopen (filename, "r");
   if (file == NULL)
   {
      perror (filename);
      exit (1);
   }
   return file;
}      


void set_all_stringopts (btshort options)
{
   bt_set_stringopts (BTE_REGULAR, options);
   bt_set_stringopts (BTE_MACRODEF, options);
   bt_set_stringopts (BTE_COMMENT, options);
   bt_set_stringopts (BTE_PREAMBLE, options);
}
