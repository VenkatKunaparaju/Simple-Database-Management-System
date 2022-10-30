//Contains main method to start the exection of the database
//Make memory requests to OS through sbrk() and send to corresponding class that needs memory
//Maintain location of heap and next available space to allocate
//Has a vector<std::string> to keep track of the layout and order of the heap (string reperesents the name of the object)


//contains struct for database header which has linked list of database objects

#include <iostream>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <vector>

#include "database.hh"


#define DB_HEADER_SIZE sizeof(databaseHeader)
#define DB_OBJECT_SIZE sizeof(database)
#define TABLE_HEADER_SIZE sizeof(tableHeader)
#define TABLE_OBJECT_SIZE sizeof(table)
#define FENCEPOST_SIZE sizeof(fencePost)

int heapSize; //Current size of heap
int heapUsed; //Amount of heap used
char * heapOffset; //Next open spot on the heap
char * base; //Start of heap

char *dbHeaderString = "Database Header";
char *dbString = "Database: ";
std::vector<char *> heapLayout; //Keeps track of the layout of the heap

char * requestMem(int); //Request more memory 
void freeMem(int size); //Free requested memory

struct database {
    char name[MAXSTRINGLEN]; //Name is 32 bytes max
    //std::string name; //Uses Heap to store string
    database *next; //Not circular
    tableHeader *tableHeader; //TableHeader for current database

};

struct databaseHeader {
    int countDatabases; //Counts number of databases
    database *databases; //Points to database
    static void initialize(); //Intialize dbheader
    static void addDatabase(database *); //Add database to dbheader
    static database * findDatabase(std::string); //Find database in dbheader
    static int createDatabase(std::string); //Creates database
};

static databaseHeader *dbHead; //Current databaseheader





