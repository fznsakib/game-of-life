// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width
#define  ALIVECELL 255

typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel cOut
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend cOut)
{
  int res;
  uchar line[ IMWD ];

  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error opening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel cOut
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      cOut <: line[x];
      printf( "-%4.1d ", line[ x ] ); //show image values
    }
    printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}


////////////////////////////////////////////////////////////////////////////////////////
//
// Functions to find neighbours and decide dead/alive
//
/////////////////////////////////////////////////////////////////////////////////////////

int countNeighbours(uchar board[IMHT][IMWD], int x, int y){
    int neighbourCount = 0;

    for (int i = -1; i < 2; i ++){
        for (int j = -1; j < 2; j ++){
            if (!((i == 0) && (j == 0))){
                if (board[(x + i + IMWD) % IMWD][(y + j + IMHT) % IMHT] == ALIVECELL){
                    neighbourCount++;
                }
            }
        }
    }
    //printf("neighbourCount: %d ", neighbourCount);
    return neighbourCount;
}

int aliveOrDead(int neighbourCount, int currentCell){
    if (neighbourCount < 2) return 0;
    else if (neighbourCount == 2 || neighbourCount == 3) return ALIVECELL;
    else if (neighbourCount > 3) return 0;
    else if ((currentCell == 0) && (neighbourCount == 3)) return ALIVECELL;
    else return currentCell;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Function to pack 8 bytes into one 8-bit value and vice-versa
//
/////////////////////////////////////////////////////////////////////////////////////////

int ultimatePacker69(uchar inputByte[8]){
    int binaryRep = 0;
    int shift = 7;

    for (int i = 0; i < 8; i++){
        if (inputByte[i] == 255) (binaryRep = binaryRep | 1 << (shift - i));
    }
    return binaryRep;
}

uchar* alias ultimateUnpacker(int inputInt){
    uchar dataArray[IMWD];
    int shift = 7;
    for (int i = 0; i < 8; i++){
        dataArray[i] = inputInt & 1 << (shift - i);
    }
    return dataArray;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////

void distributor(chanend cIn, chanend cOut, chanend cControl, chanend cWorker)
{
  uchar val;
  uchar board[IMHT][IMWD];

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  cControl :> int value;

  //Read in val from data in and initialise board
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
        cIn :> val;                    //read the pixel value
        board[y][x] = val;
        cWorker <: val;
        cWorker :> val;
      }
    }

  //Take val from worker then send to data out
  printf( "Processing...\n" );
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line

        val = board[y][x];

        //printf("VAL BEFORE: %d ", val);

        cWorker <: val;                //send pixel to worker for updated pixel
        cWorker :> val;                //get back manipulated pixel

        //printf("VAL AFTER: %d ", val);

        cOut <: val;                   //output manipulated pixel
    }
  }
  printf( "\nOne processing round completed...\n" );
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker functions being fed from distributor, each worker is working on a different
// part of the image
//
/////////////////////////////////////////////////////////////////////////////////////////

void worker(chanend cWorker){
    unsigned char currentCell;
    unsigned char updatedCell;
    unsigned int aliveNeighbours = 0;
    unsigned char board[IMHT][IMWD];
    unsigned char newBoard[IMHT][IMWD];

    //populate input board
    for (int y = 0; y < IMHT; y++){
        for (int x = 0; x < IMWD; x++){
            cWorker :> currentCell;
            board[y][x] = currentCell;
            cWorker <: currentCell;
        }
    }

    printf("here\n");

    // get currentCell from distributor, manipulate and insert into newBoard
    for (int y = 0; y < IMHT; y++){
        for (int x = 0; x < IMWD; x++){
            cWorker :> currentCell;
            aliveNeighbours = countNeighbours(board, y, x);
            printf("ALIVE NEIGHBOURS = %d", aliveNeighbours);
            updatedCell = aliveOrDead(aliveNeighbours, currentCell);
            newBoard[y][x] = updatedCell;
            cWorker <: updatedCell;
        }
    }

    // go through newBoard and send back to distributor
    /*for (int y = 0; y < IMHT; y++){
        for (int x = 0; x < IMWD; x++){
            updatedCell = newBoard[y][x];
            cWorker <: updatedCell;
        }
    }*/
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel cIn to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend cIn)
{
  int res;
  uchar line[ IMWD ];

  //Open PGM file
  printf( "DataOutStream: Start...\n" );
  res = _openoutpgm( outfname, IMWD, IMHT );
  if( res ) {
    printf( "DataOutStream: Error opening %s\n.", outfname );
    return;
  }

  //Compile each line of the image and write the image line-by-line
  for( int y = 0; y < IMHT; y++ ) {
    for( int x = 0; x < IMWD; x++ ) {
      cIn :> line[ x ];
      printf( "-%4.1d ", line[ x ] );
    }
    _writeoutline( line, IMWD );
    printf( "DataOutStream: Line written...\n" );
  }

  //Close the PGM image
  _closeoutpgm();
  printf( "DataOutStream: Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

i2c_master_if i2c[1];               //interface to orientation

char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here
chan cInIO, cOutIO, cControl, cWorker;    //extend your channel definitions here

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);  //server thread providing orientation data
    orientation(i2c[0],cControl);        //client thread reading orientation data
    DataInStream(infname, cInIO);          //thread to read in a PGM image
    DataOutStream(outfname, cOutIO);       //thread to write out a PGM image
    distributor(cInIO, cOutIO, cControl, cWorker);  //thread to coordinate work on image
    worker(cWorker);
  }

  return 0;
}
