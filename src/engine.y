%{
  #include <cstdio>
  #include <iostream>
  #include "table.cc"

  // Declare stuff from Flex that Bison needs to know about:
  extern int yylex();
  extern int yyparse();

 
  void yyerror(const char *s);
%}

%union {
    int intVal;
    double doubleVal;
    char stringVal[32];
}

%token <intVal> SQLINT
%token <doubleVal> SQLDOUBLE
%token <stringVal> SQLSTRING QSTRING
%token EXIT INSERT CREATE SHOW USE DATABASE DATABASES TABLE TABLES SELECT FROM WHERE AS AND INTO VALUES
%token SEMICOLON COMMA OPEN CLOSE GREAT LESS EQUAL NOTEQUAL NEWLINE
%token CHANGE PROMPT
%token TYPEINT TYPEDOUBLE TYPESTRING

%%

goal:
    commands
    | error {
        numberOfColumns = 0;
        numberOfCompares = 0;
        yyparse();
    }
    ;
commands:
    command {
        std::cout << MY_PROMPT;
    }
    | commands command {
        std::cout << MY_PROMPT;
    }
    ;
command:
    CREATE DATABASE SQLSTRING SEMICOLON {
        databaseHeader::createDatabase($3);
    }
    | SHOW DATABASES SEMICOLON {
        databaseHeader::printDatabases();
    }
    | USE DATABASE SQLSTRING SEMICOLON {
        tableHeader::initialize($3);
    }
    | CREATE TABLE SQLSTRING OPEN createList CLOSE SEMICOLON {
        tableHeader::createTable($3);
        tableHeader::addColumns($3, currentColumns, currentSizes, numberOfColumns);
        numberOfColumns = 0;
    }
    | INSERT INTO SQLSTRING OPEN columnList CLOSE VALUES OPEN byteList CLOSE SEMICOLON  {
        table *tb = tableHeader::findTable($3);
        if (tb) {
            if (numberOfColumns != numberOfCompares) {
                yyerror ("Number of columns don't match number of Values!");
            } 
            else {
                createFenceposts(tb);
                addRow(tb, whereCompares, currentColumnNames);
                createEndFenceposts(tb);
            }
        }
        else {
            yyerror ("Can't find table!");
        }

        numberOfColumns = 0;
        numberOfCompares = 0;
    }
    | SHOW TABLES SEMICOLON {
        tableHeader::printTables();
    }
    | SELECT columnList FROM SQLSTRING whereClause SEMICOLON {
        table *tb = tableHeader::findTable($4);
        int check = 1;
        if (tb) {
            int rows = tb->tableInfo->R;

            // Expand *
            if (strcmp(currentColumns[0], "*") == 0) {
                numberOfColumns = tb->tableInfo->N;
                columnInfo *head = tb->tableInfo->columns;
                    for (int i = 0; i < numberOfColumns; i++) {  
                        strcpy(currentColumns[i], head->name);
                        strcpy(currentColumnNames[i], head->name);
                        head = (head + 1);
                    }

            }

            //Check for all column names are valid
            unsigned char *output[numberOfColumns][rows]; 
            for (int i = 0; i < numberOfColumns; i++) {
                if (!findColumn(tb, currentColumns[i])) {
                    check = 0;
                }
            }

            //Only query if column names are valid
            if (check) {
                std::cerr << "|";
                for (int i = 0; i < numberOfColumns; i ++) {
                    std::cerr << currentColumnNames[i] << "|";
                    searchRow(tb, currentColumns[i], output[i], rows);
                }
                std::cout << "\n\n";
                for (int i = 0; i < rows; i++) {
                    int goThrough = 1;
                    for (int y = 0; y < numberOfCompares; y++) {//Where Clause
                        for (int x = 0; x < numberOfColumns; x++ ) { 
                        
                            if (strcmp(compareColumns[y], currentColumns[x]) == 0) {
                                if ((getColumnSize(tb, currentColumns[x]) == ROWINT_SIZE) || (getColumnSize(tb, currentColumns[x]) == ROWDOUBLE_SIZE)) {
                                    TempInt *jk = new TempInt;
                                    memcpy(jk->bytes, output[x][i], ROWINT_SIZE);
                                    double tool = jk->integer;
                                    if (getColumnSize(tb, currentColumns[x]) == ROWDOUBLE_SIZE) {
                                        delete jk;
                                        TempDouble *jk = new TempDouble;
                                        memcpy(jk->bytes, output[x][i], ROWDOUBLE_SIZE);
                                        tool = jk->integer;

                                    }
                                    TempDouble *temp = new TempDouble;
                                    temp = (TempDouble *)whereCompares[y];
                                    if (EEQUAL == operatorType[y]) {
                                        if  (temp->integer != tool) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    else if (EGREAT == operatorType[y]) {
                                        if  (temp->integer > tool) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    else if (ELESS == operatorType[y]) {
                                        if  (temp->integer < tool) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    else if (ENOTEQUAL == operatorType[y]) {
                                        if  (temp->integer == tool) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    delete jk;
                                }
                                else if (getColumnSize(tb, currentColumns[x]) == ROWSTRING_SIZE) {
                                    TempString *jk = new TempString;
                                    memcpy(jk->bytes, output[x][i], ROWSTRING_SIZE);

                                    TempString *temp = new TempString;
                                    temp = (TempString *)whereCompares[y];
                                    if (EEQUAL == operatorType[y]) {
                                        if  (strcmp(temp->string, jk->string) != 0) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    else if (EGREAT == operatorType[y]) {
                                        if  (strcmp(temp->string, jk->string) > 0) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    else if (ELESS == operatorType[y]) {
                                        if  (strcmp(temp->string, jk->string) < 0) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    else if (ENOTEQUAL == operatorType[y]) {
                                        if  (strcmp(temp->string, jk->string) == 0) {
                                            goThrough = 0;
                                            break;
                                        }
                                    }
                                    delete jk;
                                }
                            }

                        }
                    }
                    if (goThrough) {
                        std::cerr << "|";
                        for (int x = 0; x < numberOfColumns; x++) {
                            if (getColumnSize(tb, currentColumns[x]) == ROWINT_SIZE) {
                                TempInt *jk = new TempInt;
                                memcpy(jk->bytes, output[x][i], ROWINT_SIZE);
                                std::cout << jk->integer << "|";
                                delete jk;
                            }
                            else if (getColumnSize(tb, currentColumns[x]) == ROWDOUBLE_SIZE) {
                                TempDouble *jk = new TempDouble;
                                memcpy(jk->bytes, output[x][i], ROWDOUBLE_SIZE);
                                std::cout << jk->integer << "|";
                                delete jk;
                            }
                            else if (getColumnSize(tb, currentColumns[x]) == ROWSTRING_SIZE) {
                                TempString *jk = new TempString;
                                memcpy(jk->bytes, output[x][i], ROWSTRING_SIZE);
                                std::cout << jk->string << "|";
                                delete jk;
                            }
                            
                        }
                        std::cout << "\n";
                    }
                    
                }
            } else {
                std::cerr << "One or more column names dont exist" << "\n";
            }
        }
        else {
            yyerror ("Can't find table!");
        }
        numberOfColumns = 0;
        numberOfCompares = 0;
        
    }
    | CHANGE PROMPT QSTRING SEMICOLON {
        MY_PROMPT = $3;
    }
    | EXIT SEMICOLON {
        std::cout << "Exiting..." << "\n";
        exit(1);
    }
    | SEMICOLON
    ;
byteList:
    byte
    | byteList COMMA byte
    ;
byte:
    QSTRING {
        TempString *store = getTempString($1);
        whereCompares[numberOfCompares] = store->bytes;
        numberOfCompares += 1;
    }
    | SQLINT {
        TempInt *store = getTempInt($1);
        whereCompares[numberOfCompares] = store->bytes;
        numberOfCompares += 1;
    }
    | SQLDOUBLE {
        TempDouble *store = getTempDouble($1);
        whereCompares[numberOfCompares] = store->bytes;
        numberOfCompares += 1;
    }
    ;
columnList:
    column
    | columnList COMMA column
    ;
column:
    | SQLSTRING {
        addColumn($1, 0);
        strcpy(currentColumnNames[numberOfColumns - 1], $1);
    }
    | SQLSTRING AS SQLSTRING {
        addColumn($1, 0);
        strcpy(currentColumnNames[numberOfColumns - 1], $3);
    }
    ;
createList:
    create
    | createList COMMA create
    ;
create:
    | SQLSTRING TYPEINT {
        addColumn($1, 4);
    }
    | SQLSTRING TYPEDOUBLE {
        addColumn($1, 8);
    }
    | SQLSTRING TYPESTRING {
        addColumn($1, 32);
    }
    ;
operator:
    GREAT {
        operatorType[numberOfCompares] = EGREAT;
    }
    | LESS {
        operatorType[numberOfCompares] = ELESS;
    }
    | EQUAL {
        operatorType[numberOfCompares] = EEQUAL;
    }
    | NOTEQUAL {
        operatorType[numberOfCompares] = ENOTEQUAL;
    }
    ;
whereClause:
    WHERE whereList
    |
    ;

whereList:
    where
    | whereList AND where
    ;
where:
    SQLSTRING operator QSTRING {
        TempString *store = getTempString($3);
        whereCompares[numberOfCompares] = store->bytes;
        strcpy(compareColumns[numberOfCompares],$1);
        numberOfCompares += 1;
    }
    | SQLSTRING operator SQLINT {
        TempDouble *store = getTempDouble($3);
        whereCompares[numberOfCompares] = store->bytes;
        strcpy(compareColumns[numberOfCompares],$1);
        numberOfCompares += 1;
    }
    | SQLSTRING operator SQLDOUBLE {
        TempDouble *store = getTempDouble($3);
        whereCompares[numberOfCompares] = store->bytes;
        strcpy(compareColumns[numberOfCompares],$1);
        numberOfCompares += 1;
    }
    ;

%%
void yyerror(const char *s) {
    fprintf(stderr, "%s\n", s);
    //exit(1);
}
int main() {
    databaseHeader::initialize();
    testDatabase(0);
    testTable(0);
    testRow();
    
    if (heapCheck())
        printHeapLayout();


    freeMem(heapSize);
    std::cout << MY_PROMPT;
    yyparse();
}
