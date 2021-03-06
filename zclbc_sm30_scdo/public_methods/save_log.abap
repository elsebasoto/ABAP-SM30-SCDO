**************************************************************************
*   Method attributes.                                                   *
**************************************************************************
Instantiation: Public
**************************************************************************

METHOD save_log.
*----------------------------------------------------------------------*
* Técnico:      Panzini, Sebastián
* Fecha:        13.02.2020
* Descripción:  Se modifica metodo para poder permitir ejecutar un
*               objeto SCDO con mas de una tabla parametrizada
*----------------------------------------------------------------------*

  DATA: ol_line               TYPE REF TO data,
        ol_old_data           TYPE REF TO data,
        ol_data               TYPE REF TO data.             "add by sp001

  DATA: tl_function_import    TYPE abap_func_parmbind_tab,
        tl_tcdob              TYPE STANDARD TABLE OF tcdob. "add by sp001

  DATA: wl_function_import    TYPE LINE OF abap_func_parmbind_tab,
        wl_tcdob              TYPE tcdob.                   "add by sp001

  DATA: vl_key                TYPE LINE OF cf_t_fzwert,
        vl_objectid           TYPE cdhdr-objectid,
        vl_function_name      TYPE rs38l-name,
        vl_length             TYPE i,
        vl_offset             TYPE i.

  FIELD-SYMBOLS: <fsl_table>  TYPE ANY TABLE,
                 <fsl_line>   TYPE ANY,
                 <fsl_new>    TYPE ANY,
                 <fsl_old>    TYPE ANY,
                 <fsl_action> TYPE ANY,
                 <fsl_key>    TYPE ANY,
                 <fsl_structure> TYPE ANY.                   "add by sp001


* Get the function name
  vl_function_name = me->get_function_name( ).

  ASSIGN me->o_total_table->* TO <fsl_table>.

  CREATE DATA ol_line LIKE LINE OF <fsl_table>.
  ASSIGN ol_line->* TO <fsl_line>.

  CREATE DATA ol_old_data TYPE (me->v_viewname).
  ASSIGN ol_old_data->* TO <fsl_old>.

  LOOP AT <fsl_table> INTO <fsl_line>.

    CLEAR: tl_function_import,
           vl_objectid.

    ASSIGN COMPONENT 'ACTION' OF STRUCTURE <fsl_line> TO <fsl_action>.

    ASSIGN <fsl_line> TO <fsl_new> CASTING TYPE (me->v_viewname).

    IF <fsl_action> CA 'UD'.

      CLEAR <fsl_old>.

      CALL METHOD me->read_data_table
        EXPORTING
          im_input  = <fsl_new>
        IMPORTING
          ex_output = <fsl_old>.

    ENDIF.

*   The Object ID is the key table concatenated
    wl_function_import-name = 'OBJECTID'.
    wl_function_import-kind = abap_func_exporting.

    CLEAR: vl_offset.

    LOOP AT me->t_key INTO vl_key.

      UNASSIGN <fsl_key>.

      ASSIGN COMPONENT vl_key OF STRUCTURE <fsl_line> TO <fsl_key>.

      DESCRIBE FIELD <fsl_key> LENGTH vl_length IN CHARACTER MODE.

      vl_objectid+vl_offset(vl_length) = <fsl_key>.

      ADD vl_length TO vl_offset.

    ENDLOOP.

    GET REFERENCE OF vl_objectid INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

*   Transaction Code is not hardcoded because if use a Z transaction as shortcut this data will be lost.

    CLEAR wl_function_import.
    wl_function_import-name = 'TCODE'.
    wl_function_import-kind = abap_func_exporting.
    GET REFERENCE OF sy-tcode INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

*   System hour & date and User Name.
    CLEAR wl_function_import.
    wl_function_import-name = 'UTIME'.
    wl_function_import-kind = abap_func_exporting.
    GET REFERENCE OF sy-uzeit INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

    CLEAR wl_function_import.
    wl_function_import-name = 'UDATE'.
    wl_function_import-kind = abap_func_exporting.
    GET REFERENCE OF sy-datum INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

    CLEAR wl_function_import.
    wl_function_import-name = 'USERNAME'.
    wl_function_import-kind = abap_func_exporting.
    GET REFERENCE OF sy-uname INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

*   User action (Change, Insert, Delete)
    CLEAR wl_function_import.
    wl_function_import-name = 'OBJECT_CHANGE_INDICATOR'.
    wl_function_import-kind = abap_func_exporting.

    CASE <fsl_action>.
      WHEN 'N'.
        GET REFERENCE OF me->c_insert_action INTO wl_function_import-value.
      WHEN 'U'.
        GET REFERENCE OF me->c_update_action INTO wl_function_import-value.
      WHEN 'D'.
        GET REFERENCE OF me->c_delete_action INTO wl_function_import-value.
    ENDCASE.

    INSERT wl_function_import INTO TABLE tl_function_import.

    CONCATENATE 'UPD_'
                me->v_viewname
    INTO wl_function_import-name.

    INSERT wl_function_import INTO TABLE tl_function_import.

*   New values
    CLEAR: wl_function_import.

    CONCATENATE 'N_'
                me->v_viewname
    INTO wl_function_import-name.

    wl_function_import-kind = abap_func_exporting.
    GET REFERENCE OF <fsl_new> INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

*   Old values if was update or delete
    CLEAR: wl_function_import.

    CONCATENATE 'O_'
                me->v_viewname
    INTO wl_function_import-name.

    wl_function_import-kind = abap_func_exporting.
    GET REFERENCE OF <fsl_old> INTO wl_function_import-value.
    INSERT wl_function_import INTO TABLE tl_function_import.

*** BEGIN SP001
*" Se consulta si el objeto SCDO tiene mas de una tabla asignada.
    SELECT object tabname
      INTO TABLE tl_tcdob
      FROM tcdob
      WHERE object EQ me->v_object
        AND tabname NE me->v_viewname.
    IF sy-subrc EQ 0 AND NOT tl_tcdob[] IS INITIAL.
*" Se recorren las tablas y se cargan a la interfaz de la función
      LOOP AT tl_tcdob INTO wl_tcdob.
        CLEAR: ol_data.
        CREATE DATA ol_data TYPE (wl_tcdob-tabname).
        ASSIGN ol_data->* TO <fsl_structure>.

*" New values
        CLEAR: wl_function_import.
        CONCATENATE 'N_'
                    wl_tcdob-tabname
        INTO wl_function_import-name.
        wl_function_import-kind = abap_func_exporting.
        GET REFERENCE OF <fsl_structure> INTO wl_function_import-value.
        INSERT wl_function_import INTO TABLE tl_function_import.

*" Old values
        CLEAR: wl_function_import.
        CONCATENATE 'O_'
                    wl_tcdob-tabname
        INTO wl_function_import-name.
        wl_function_import-kind = abap_func_exporting.
        GET REFERENCE OF <fsl_structure> INTO wl_function_import-value.
        INSERT wl_function_import INTO TABLE tl_function_import.
      ENDLOOP.
    ENDIF.
*** END SP001

*   Call the function.
    CALL FUNCTION vl_function_name
      PARAMETER-TABLE
        tl_function_import.

  ENDLOOP.

ENDMETHOD.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2020. Sap Release 700
