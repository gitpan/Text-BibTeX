/* ------------------------------------------------------------------------
@NAME       : BibTeX.xs
@INPUT      : 
@OUTPUT     : 
@RETURNS    : 
@DESCRIPTION: Glue between my `btparse' library and the Perl module
              Text::BibTeX.  Provides the following functions to Perl:
                 parse_entry
                 orig_val
@GLOBALS    : 
@CALLS      : 
@CREATED    : Jan/Feb 1997, Greg Ward
@MODIFIED   : 
@VERSION    : $Id: BibTeX.xs,v 1.2 1997/03/08 18:09:14 greg Exp $
-------------------------------------------------------------------------- */
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "btparse/btparse.h"
#ifdef __cplusplus
}
#endif

#define DEBUG 0

#if DEBUG
# define DBG_ACTION(x) x
#else
# define DBG_ACTION(x)
#endif


static char *nodetype_names[] = 
{
   "entry", "macrodef", "text", "key", "field", "string", "number", "macro"
};


static int
not_here(s)
char *s;
{
    croak("%s not implemented on this architecture", s);
    return -1;
}


static int
constant(name, arg)
char *   name;
IV *     arg;
{

/* printf ("constant: name=%s\n", name); */

   if (strEQ (name, "BT_STRING")) { *arg = AST_STRING; return TRUE; }
   if (strEQ (name, "BT_MACRO"))  { *arg = AST_MACRO; return TRUE; }
   if (strEQ (name, "BT_NUMBER")) { *arg = AST_NUMBER; return TRUE; }

   return FALSE;
}


static void 
ast_to_hash (SV *entry_ref, AST *top, uchar parse_status)
{
   char *  type;
   char *  key;
   HV *    entry;                 /* the main hash -- build and return */
   AV *    flist;                 /* the field list -- put into entry */
   HV *    values;                /* the field values -- put into entry */
   AST *   field;
   char *  field_name;
   AST *   item;
   char *  item_text;

   DBG_ACTION (printf ("ast_to_hash: entry\n"));

   /* printf ("checking that entry_ref is a ref and a hash ref\n"); */
   if (! (SvROK (entry_ref) && (SvTYPE (SvRV (entry_ref)) == SVt_PVHV)))
      croak ("entry_ref must be a hash ref");
   entry = (HV *) SvRV (entry_ref);

   DBG_ACTION (printf ("  inserting type, key, status\n"));
   type = bt_get_type (top, NULL);
   if (!type)
      croak ("entry has no type");
   hv_store (entry, "type", 4, newSVpv (type, 0), 0);

   key = bt_get_key (top);
   if (key)
      hv_store (entry, "key", 3, newSVpv (key, 0), 0);
   else
      hv_store (entry, "key", 3, &sv_undef, 0);
   hv_store (entry, "status", 6, newSViv ((IV) parse_status), 0);

   /* 
    * Now loop over all fields in the entry.   As we loop, we build 
    * two structures: the list of field names, and the hash relating
    * field names to (fully expanded) values. 
    */
   
   DBG_ACTION (printf ("  creating field list, value hash\n"));
   flist = newAV ();
   values = newHV ();

   DBG_ACTION (printf ("  getting fields and values\n"));
   field = bt_first_field (top, &field_name, &item);
   while (field)
   {
      SV *   sv_field_name;
      char * field_value;
      SV *   sv_field_value;

      /* Get the field name and value as SVs */

      sv_field_name = newSVpv (field_name, 0);
      field_value = bt_value (field);
      sv_field_value = newSVpv (field_value, 0);

      DBG_ACTION (printf ("  field=%s, value=\"%s\"\n", 
                          field_name, field_value));

      /* Push the field name onto the field list, and add the field value
       * to the values hash.
       */
      av_push (flist, sv_field_name);
      (void) hv_store (values, field_name, strlen (field_name),
                       sv_field_value, 0);

      field = bt_next_field (field, &field_name, &item);
      DBG_ACTION (printf ("  stored field/value; next will be %s\n",
                          field_name));
   }


   /* Put refs to field list and value hash into the main hash */

   DBG_ACTION (printf ("  got all fields; storing list/hash refs\n"));
   hv_store (entry, "fields", 6, newRV ((SV *) flist), 0);
   hv_store (entry, "values", 6, newRV ((SV *) values), 0);
   hv_store (entry, "ast", 3, newSViv ((IV) top), 0);

   DBG_ACTION (printf ("ast_to_hash: exit\n"));
}


MODULE = Text::BibTeX   	PACKAGE = Text::BibTeX

PROTOTYPES: ENABLE

SV *
constant(name)
char *   name
        CODE:
	IV i;
	if (constant(name, &i))
	    ST(0) = sv_2mortal(newSViv(i));
	else
	    ST(0) = &sv_undef;

void
initialize()
        CODE:
        bt_initialize ();


void
cleanup()
        CODE:
        bt_cleanup ();


MODULE = Text::BibTeX   	PACKAGE = Text::BibTeX::Entry

int
parse (entry_ref, filename, file)
SV *    entry_ref;
char *  filename;
FILE *  file;

        PREINIT:
        bt_options_t
                options = { 0, 0, 0, 0, 0 };
        uchar   status;
        AST *   top;

        CODE:

        bt_set_filename (filename);
        status = bt_parse_entry (file, &options, &top);

        if (!top)                  /* at EOF -- return false to perl */
        {
           XSRETURN_NO;
        }

        ast_to_hash (entry_ref, top, status);
        XSRETURN_YES;              /* OK -- return true to perl */


int
parse_s (entry_ref, text)
SV *    entry_ref;
char *  text;

        PREINIT:
        bt_options_t
                options = { 0, 0, 0, 0, 0 };
        uchar   status;
        AST *   top;

        CODE:

        status = bt_parse_entry_s (text, &options, 1, &top);

        if (!top)                  /* no entry found -- return false to perl */
        {
           XSRETURN_NO;
        }

        ast_to_hash (entry_ref, top, status);
        XSRETURN_YES;              /* OK -- return true to perl */


void
orig_val (entry_ref, field_name)
SV *      entry_ref;
char *    field_name;
        PREINIT:
        HV *    entry;
        AST *   entry_top;              /* top of AST for whole entry */
        AST *   field;                  /* AST for desired field */
        char *  cur_name;               /* name of current field while searching */
        AST *   item;                   /* AST for current item */
        nodetype_t item_type;
        char *  item_text;              /* text from item */
        
        PPCODE:

        entry = (HV *) SvRV (entry_ref);
        entry_top = (AST *) SvIV (*(hv_fetch (entry, "ast", 3, 0)));


        /* First, traverse the entry's field list till we find the named one */
        printf ("entry_top = %08p (type=%s, text=%s)\n",
                entry_top,
                nodetype_names [(int) entry_top->nodetype],
                entry_top->text);

        field = bt_first_field (entry_top, &cur_name, &item);
        while (field && strcmp (cur_name, field_name) != 0)
        {
           field = bt_next_field (field, &cur_name, &item);
        }
        if (!field)                     /* didn't find named field */
           return;                      /* -- return undef to perl */


        /* OK, we have the desired field -- item list starts with `item' */
        
        item = bt_first_item (item, &item_type, &item_text);
        while (item)
        {
           SV *   sv_type_code;         /* these two could probably be made */
           SV *   sv_text;              /* mortal -- just live long enough */
                                        /* to be copied into sv_list */
           SV *   sv_list[2];
           AV *   cur_value;            /* perl list representing one item */
           SV *   ref_value;            /* ref to cur_value */

           printf ("  item = %08p (type=%s, text=%s)\n",
                   item,
                   nodetype_names [(int) item->nodetype],
                   item->text);

           sv_type_code = newSViv (item_type);
/*
           switch (item_type)
           {
              case AST_STRING: type_code[0] = 's'; break;
              case AST_NUMBER: type_code[0] = 'n'; break;
              case AST_MACRO:  type_code[0] = 'm'; break;
              default:         
                 fprintf (stderr, "Unexpected item type %d\n",
                          (int) item_type);
                 return;
           }
           type_code[1] = (char) 0;
           sv_type_code = newSVpv (type_code, 1);
*/
           sv_text = newSVpv (item_text, 0);
           sv_list[0] = sv_type_code;
           sv_list[1] = sv_text;

           cur_value = av_make (2, sv_list);
           ref_value = newRV ((SV *) cur_value);
           XPUSHs (ref_value);

           item = bt_next_item (item, &item_type, &item_text);
        }
