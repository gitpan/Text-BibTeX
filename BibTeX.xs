/* ------------------------------------------------------------------------
@NAME       : BibTeX.xs
@INPUT      : 
@OUTPUT     : 
@RETURNS    : 
@DESCRIPTION: Glue between my `btparse' library and the Perl module
              Text::BibTeX.  Provides the following functions to Perl:
                 Text::BibTeX::constant
                 Text::BibTeX::initialize
                 Text::BibTeX::cleanup
                 Text::BibTeX::Entry::parse_s
                 Text::BibTeX::Entry::parse
@GLOBALS    : 
@CALLS      : 
@CREATED    : Jan/Feb 1997, Greg Ward
@MODIFIED   : 
@VERSION    : $Id: BibTeX.xs,v 1.13 1997/10/03 04:01:47 greg Exp $
-------------------------------------------------------------------------- */
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <btparse.h>
#ifdef __cplusplus
}
#endif

#define BT_DEBUG 0

#if BT_DEBUG
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
   int   ok = FALSE;

   DBG_ACTION (printf ("constant: name=%s\n", name));

   if (! (name[0] == 'B' && name[1] == 'T')) /* should not happen! */
      croak ("Illegal constant name \"%s\"", name);

   switch (name[2])
   {
      case 'E':                         /* entry metatypes */
         if (strEQ (name, "BTE_UNKNOWN")) { *arg = BTE_UNKNOWN; ok = TRUE; }
         if (strEQ (name, "BTE_REGULAR")) { *arg = BTE_REGULAR; ok = TRUE; }
         if (strEQ (name, "BTE_COMMENT")) { *arg = BTE_COMMENT; ok = TRUE; }
         if (strEQ (name, "BTE_PREAMBLE")) { *arg = BTE_PREAMBLE; ok = TRUE; }
         if (strEQ (name, "BTE_MACRODEF")) { *arg = BTE_MACRODEF; ok = TRUE; }
         break;
      case 'A':                         /* AST nodetypes (not all of them) */
         if (strEQ (name, "BTAST_STRING")) { *arg = BTAST_STRING; ok = TRUE; }
         if (strEQ (name, "BTAST_NUMBER")) { *arg = BTAST_NUMBER; ok = TRUE; }
         if (strEQ (name, "BTAST_MACRO")) { *arg = BTAST_MACRO; ok = TRUE; }
         break;
      default:
         break;
   }

   return ok;
}


static void
convert_assigned_entry (AST *top, HV *entry)
{
   AV *    flist;                 /* the field list -- put into entry */
   HV *    values;                /* the field values -- put into entry */
   HV *    lines;                 /* line numbers of entry and its fields */
   AST *   field;
   char *  field_name;
   AST *   item;
   char *  item_text;
   int     prev_line;

   /*
    * Start the line number hash.  It will contain (num_fields)+2 elements;
    * one for each field (keyed on the field name), and the `start' and
    * `stop' lines for the entry as a whole.  (Currently, the `stop' line
    * number is the same as the line number of the last field.  This isn't
    * strictly correct, but by the time we get our hands on the AST, that
    * closing brace or parenthesis is long lost -- so this is the best we
    * get.  I just want to put this redundant line number in in case some
    * day I get ambitious and keep track of its true value.)
    */

   lines = newHV ();
   hv_store (lines, "START", 5, newSViv (top->line), 0);

   /* 
    * Now loop over all fields in the entry.   As we loop, we build 
    * three structures: the list of field names, the hash relating
    * field names to (fully expanded) values, and the list of line 
    * numbers.
    */
   
   DBG_ACTION (printf ("  creating field list, value hash\n"));
   flist = newAV ();
   values = newHV ();

   DBG_ACTION (printf ("  getting fields and values\n"));
   field = bt_next_field (top, NULL, &field_name);
   while (field)
   {
      AST *  value;
      bt_nodetype_t 
             nodetype;
      char * field_value;
      SV *   sv_field_name;
      SV *   sv_field_value;

      if (!field_name)                  /* this shouldn't happen -- but if */
         continue;                      /* it does, skipping the field seems */
                                        /* reasonable to me */

      /* Get the field name and value as SVs */

      value = bt_next_value (field, NULL, &nodetype, &field_value);
      if (value &&
          (! (nodetype == BTAST_STRING || nodetype == BTAST_NUMBER) ||
           bt_next_value (field, value, NULL, NULL) != NULL))
      {
         croak ("BibTeX.xs: internal error in entry post-processing--value "
                "for field %s is not a simple string or number", field_name);
      }

      DBG_ACTION (printf ("  field=%s, value=\"%s\"\n", 
                          field_name, field_value));
      sv_field_name = newSVpv (field_name, 0);
      sv_field_value = field_value ? newSVpv (field_value, 0) : &sv_undef;


      /* 
       * Push the field name onto the field list, add the field value to
       * the values hash, and add the line number onto the line number
       * hash.
       */
      av_push (flist, sv_field_name);
      hv_store (values, field_name, strlen (field_name), sv_field_value, 0);
      hv_store (lines, field_name, strlen (field_name),
                newSViv (field->line), 0);
      prev_line = field->line;          /* so we can duplicate last line no. */

      field = bt_next_field (top, field, &field_name);
      DBG_ACTION (printf ("  stored field/value; next will be %s\n",
                          field_name));
   }


   /* 
    * Duplicate the last element of `lines' (kludge until we keep track of
    * the true end-of-entry line number).
    */
   hv_store (lines, "STOP", 4, newSViv (prev_line), 0);


   /* Put refs to field list, value hash, and line list into the main hash */

   DBG_ACTION (printf ("  got all fields; storing list/hash refs\n"));
   hv_store (entry, "fields", 6, newRV ((SV *) flist), 0);
   hv_store (entry, "values", 6, newRV ((SV *) values), 0);
   hv_store (entry, "lines", 5, newRV ((SV *) lines), 0);

} /* convert_assigned_entry () */


static void
convert_value_entry (AST *top, HV *entry)
{
   HV *    lines;                 /* line numbers of entry and its fields */
   AST *   item,
       *   prev_item;
   int     last_line;
   char *  value;
   SV *    sv_value;

   /* 
    * Start the line number hash.  For "value" entries, it's a bit simpler --
    * just a `start' and `stop' line number.  Again, the `stop' line is
    * inaccurate; it's just the line number of the last value in the
    * entry.
    */
   lines = newHV ();
   hv_store (lines, "START", 5, newSViv (top->line), 0);

   /* Walk the list of values to find the last one (for its line number) */
   item = NULL;
   while (item = bt_next_value (top, item, NULL, NULL))
      prev_item = item;
   last_line = prev_item->line;
   hv_store (lines, "STOP", 4, newSViv (last_line), 0);

   /* Store the line number hash in the entry hash */
   hv_store (entry, "lines", 5, newRV ((SV *) lines), 0);

   /* And get the value of the entry as a single string (fully processed) */
   value = bt_get_text (top);
   sv_value = value ? newSVpv (value, 0) : &sv_undef;
   hv_store (entry, "value", 5, sv_value, 0);

} /* convert_value_entry () */


static void 
ast_to_hash (SV *entry_ref, AST *top, boolean parse_status)
{
   char *  type;
   char *  key;
   HV *    entry;                 /* the main hash -- build and return */

   DBG_ACTION (printf ("ast_to_hash: entry\n"));

   /* printf ("checking that entry_ref is a ref and a hash ref\n"); */
   if (! (SvROK (entry_ref) && (SvTYPE (SvRV (entry_ref)) == SVt_PVHV)))
      croak ("entry_ref must be a hash ref");
   entry = (HV *) SvRV (entry_ref);

   /* 
    * Clear out all hash values that might not be replaced in this
    * conversion (in case the user parses into an existing
    * Text::BibTeX::Entry object).  (We don't blow the hash away with
    * hv_clear() in case higher-up code has put interesting stuff into it.)
    */

   hv_delete (entry, "key", 3, G_DISCARD);
   hv_delete (entry, "fields", 6, G_DISCARD);
   hv_delete (entry, "lines", 5, G_DISCARD);
   hv_delete (entry, "values", 6, G_DISCARD);
   hv_delete (entry, "value", 5, G_DISCARD);


   /* 
    * Start filling in the hash; all entries have a type and metatype,
    * and we'll do the key here (even though it's not in all entries)
    * for good measure.
    */

   type = bt_entry_type (top);
   key = bt_entry_key (top);
   DBG_ACTION (printf ("  inserting type (%s), metatype (%d)\n",
                       type ? type : "*none*", bt_entry_metatype (top)));
   DBG_ACTION (printf ("        ... key (%s) status (%d)\n",
                       key ? key : "*none*", parse_status));

   if (!type)
      croak ("entry has no type");
   hv_store (entry, "type", 4, newSVpv (type, 0), 0);
   hv_store (entry, "metatype", 8, newSViv (bt_entry_metatype (top)), 0);

   if (key)
      hv_store (entry, "key", 3, newSVpv (key, 0), 0);

   hv_store (entry, "status", 6, newSViv ((IV) parse_status), 0);


   switch (bt_entry_metatype (top))
   {
      case BTE_MACRODEF:
      case BTE_REGULAR:
         convert_assigned_entry (top, entry);
         break;

      case BTE_COMMENT:
      case BTE_PREAMBLE:
         convert_value_entry (top, entry);
         break;

      default:                          /* this should never happen! */
         croak ("unknown entry type \"%s\"\n", bt_entry_type (top));
   }


   /* And finally, free up the AST */

   bt_free_ast (top);

/*   hv_store (entry, "ast", 3, newSViv ((IV) top), 0); */

   DBG_ACTION (printf ("ast_to_hash: exit\n"));
}  /* ast_to_hash () */


static SV *
convert_stringlist (char **list, int num_strings)
{
   int    i;
   AV *   perl_list;
   SV *   sv_string;

   perl_list = newAV ();
   for (i = 0; i < num_strings; i++)
   {
      sv_string = newSVpv (list[i], 0);
      av_push (perl_list, sv_string);
   }

   return newRV ((SV *) perl_list);

} /* convert_stringlist() */


static void
store_stringlist (HV *hash, char *key, char **list, int num_strings)
{
   SV *  listref;

   if (list)
   {
      listref = convert_stringlist (list, num_strings);
      hv_store (hash, key, strlen (key), listref, 0);
   }

} /* store_stringlist() */


MODULE = Text::BibTeX           PACKAGE = Text::BibTeX

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
        ushort  options = 0;
        boolean status;
        AST *   top;

        CODE:

        top = bt_parse_entry (file, filename, options, &status);
#if BT_DEBUG >= 2
        dump_ast ("BibTeX.xs:parse: AST from bt_parse_entry():\n", top);
#endif

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
        ushort  options = 0;
        boolean status;
        AST *   top;

        CODE:

        top = bt_parse_entry_s (text, NULL, 1, options, &status);

        if (!top)                  /* no entry found -- return false to perl */
        {
           XSRETURN_NO;
        }

        ast_to_hash (entry_ref, top, status);
        XSRETURN_YES;              /* OK -- return true to perl */


MODULE = Text::BibTeX           PACKAGE = Text::BibTeX          PREFIX = bt_


void
bt_split_list (string, delim, filename=NULL, line=0, description=NULL)
# bt_split_list (string, delim, filename, line, description)

    char *   string
    char *   delim
    char *   filename
    int      line
    char *   description

    PREINIT:
       bt_stringlist *
             names;
       int   i;
       SV *  sv_name;

    PPCODE:
       names = bt_split_list (string, delim, filename, line, description);

       EXTEND (sp, names->num_items);
       for (i = 0; i < names->num_items; i++)
       {
          if (names->items[i] == NULL)
             sv_name = &sv_undef;
          else
             sv_name = sv_2mortal (newSVpv (names->items[i], 0));

          PUSHs (sv_name);
       }

       bt_free_list (names);


SV *
bt_split_name (name, filename=NULL, line=0, name_num=-1)

    char *  name
    char *  filename
    int     line
    int     name_num

    PREINIT:
       bt_name * name_split;
       int       i;
       SV *      sv_first;
       SV *      sv_von;
       SV *      sv_last;
       SV *      sv_jr;
       HV *      name_hash;

    CODE:
       name_split = bt_split_name (name, filename, line, name_num);
       name_hash = newHV ();

       store_stringlist (name_hash, "first", 
                         name_split->first, name_split->n_first);
       store_stringlist (name_hash, "von", 
                         name_split->von, name_split->n_von);
       store_stringlist (name_hash, "last", 
                         name_split->last, name_split->n_last);
       store_stringlist (name_hash, "jr", 
                         name_split->jr, name_split->n_jr);
 
       RETVAL = newRV ((SV *) name_hash);

    OUTPUT:
       RETVAL
