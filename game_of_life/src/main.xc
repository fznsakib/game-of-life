// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width
#define  WORKERHT 10              //worker image height
#define  ALIVECELL 255            //alive cell byte
#define  MAX_ROUNDS               //maximum rounds to be executed

typedef unsigned char uchar;      //using uchar as shorthand

on tile[0] : port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0] : port p_sda = XS1_PORT_1F;

on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs

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

char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here


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
      //printf("HERE: %d ", line[x]);
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



/////////////////////////////////////////////////////////////////////////////////////////
//
// Function to pack 8 bytes into one 8-bit value and vice-versa
//
/////////////////////////////////////////////////////////////////////////////////////////

uint8_t bytePacker(uchar inputByte){
    int binaryRep = 0;
    int shift = 7;

    for (int i = 0; i < 8; i++){
        i = 0;
    }
    return binaryRep;
}

uchar* alias byteUnpacker(int inputInt){
    uchar dataArray[IMWD];
    int shift = 7;
    for (int i = 0; i < 8; i++){
        dataArray[i] = inputInt & 1 << (shift - i);
    }
    return dataArray;
}


/////////////////////////////////////////////////////////////////////////////////////////
//
//
// Function for listening to xMOS interface
//
//
/////////////////////////////////////////////////////////////////////////////////////////

//DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromVisualiser) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    fromVisualiser :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}

void buttonListener(in port b, chanend cButton1, chanend cButton2) {
  int r;
  while (1) {
      b when pinseq(15)  :> r;    // check that no button is pressed
      b when pinsneq(15) :> r;    // check if some buttons are pressed

      if (r == 13){               // if button 1 is pressed
          cButton1 <: r;
          break;
      }
  }

  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed

    if (r == 14){               // if button 2 is pressed
          cButton2 <: r;
          cButton2 :> r;
    }
  }
}

void visualiser(chanend toLEDs, chanend fromDistributor, chanend fromDataOut) {
  int pattern = 0;
  int round = 0;            //alternate between green and flashing green
  int exporting = 0;
  int paused = 0;

  while (1) {
    select{
        case fromDistributor :> round:
            break;
        case fromDataOut :> exporting:
            break;
    }
    if (paused == 1) pattern = (round % 2) + 8;
    else if (exporting == 1) pattern = (round % 2) + 2;
    else pattern = (round % 2) + 4;
    toLEDs <: pattern;
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////

int flip(int n) {
    if (n==1) return 0;
    else return 1;
}


void distributor(chanend cIn, chanend cOut, chanend cControl, chanend cButton1, chanend cVisualiser, chanend cWorker1, chanend cWorker2)
{
  uchar val = 0;
  uchar board[IMHT][IMWD];
  uchar workerBoard1[WORKERHT][IMWD];
  uchar workerBoard2[WORKERHT][IMWD];

  int round = 0;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Button 1...\n" );
  cButton1 :> int value;
  cVisualiser <: 1;

  //Read in val from data in and initialise board
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line

      cIn :> val;                    //read the pixel value

      board[y][x] = val;             //initialise board with values
      }
  }

  for( int y = 0; y < WORKERHT; y++ ) {   //initialise workerBoard 1
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
          workerBoard1[y][x] = 0;
          workerBoard2[y][x] = 0;
      }
  }

  //Initialise workerBoard insides
  for( int y = 0; y < WORKERHT - 2; y++ ) {   //initialise workerBoard 1
    for( int x = 0; x < IMWD; x++ ) {     //go through each pixel per line
      workerBoard1[y + 1][x] = board[y][x];
      workerBoard2[y + 1][x] = board[(y + (IMHT / 2))][x];
    }
  }

  //Initialise workerBoard top/bottom
  for( int y = 0; y < 2; y++ ) {   //initialise workerBoard 1
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
        workerBoard1[y * (WORKERHT - 1)][x] = board[((y/2) * (IMHT)) + y][x];
        workerBoard2[y * (WORKERHT - 1)][x] = board[(flip(y)) * ((IMHT/2) - 1)][x];
      }
  }

  //Testing workerBoards
  /*
  printf("ORIGINAL WORKERBOARD 1\n");
  for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
        printf("%4.1d ", workerBoard1[y][x]);
    }
    printf("\n");
  }

  printf("ORIGINAL WORKERBOARD 2\n");
  for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
          printf("%4.1d ", workerBoard2[y][x]);
      }
      printf("\n");
    }
  */

  //Take val from worker then send to data out
  printf( "Processing...\n" );


  // Initiate board in worker functions
  for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
        cWorker1 <: workerBoard1[y][x];
        cWorker1 :> val;

        cWorker2 <: workerBoard2[y][x];
        cWorker2 :> val;
      }
  }

  // send work to each worker
  for( int worker1y = 0; worker1y < WORKERHT; worker1y++ ) {   //go through all lines
      for( int worker1x = 0; worker1x < IMWD; worker1x++ ) {
          cWorker1 <: val;                      //send permission to worker to update cell
          cWorker1 :> val;                      //receive updated cell

          //ignoring extra rows from worker board
          if ((worker1y != 0 && worker1y != (WORKERHT-1))){
              board[worker1y - 1][worker1x] = val;
          }
      }
  }

    for( int worker2y = 0; worker2y < WORKERHT; worker2y++ ) {   //go through all lines
        for( int worker2x = 0; worker2x < IMWD; worker2x++ ) {
            cWorker2 <: val;                //send permission to worker to update cell
            cWorker2 :> val;                //receive updated cell

            if ((worker2y != 0 && worker2y != (WORKERHT-1))){
                board[worker2y + (WORKERHT - 3)][worker2x] = val;
            }
        }
    }

    round++;
    cVisualiser <: round;

    //output final board to console
    for (int y = 0; y < IMHT; y++){
        for (int x = 0; x < IMWD; x++){
            val = board[y][x];
            cOut <: val;
        }
    }

    printf( "\nOne processing round completed...\n" );
  }


////////////////////////////////////////////////////////////////////////////////////////
//
// Functions to find neighbours and decide dead/alive
//
/////////////////////////////////////////////////////////////////////////////////////////

int countNeighbours(uchar board[WORKERHT][IMWD], int y, int x){
    int neighbourCount = 0;

    for (int i = -1; i < 2; i ++){
        for (int j = -1; j < 2; j ++){
            if (!((i == 0) && (j == 0))){
                //Use mod to make sure board tiles are continuous
                if (board[(y + j + WORKERHT) % WORKERHT][(x + i + IMWD) % IMWD] == ALIVECELL){
                    neighbourCount++;
                }
            }
        }
    }
    return neighbourCount;
}

// Apply rules of game of life on each cell, depending on their neighbour counts
int aliveOrDead(int neighbourCount, int currentCell){
    if (currentCell == ALIVECELL && neighbourCount < 2) return 0;
    else if (currentCell == ALIVECELL && (neighbourCount == 2 || neighbourCount == 3)) return ALIVECELL;
    else if (currentCell == ALIVECELL && neighbourCount > 3) return 0;
    else if ((currentCell == 0) && (neighbourCount == 3)) return ALIVECELL;
    else return currentCell;
}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker functions being fed from distributor, each worker is working on a different
// part of the image
//
/////////////////////////////////////////////////////////////////////////////////////////

void worker(int index, chanend cWorker){
    unsigned char currentCell;
    unsigned char updatedCell;
    unsigned int aliveNeighbours = 0;
    unsigned char board[WORKERHT][IMWD];
    unsigned char newBoard[WORKERHT][IMWD];

    // look for tilt pause here
    // cControl :> int value;

    //initialise newBoard with 0s
    for (int y = 0; y < WORKERHT; y++){
        for (int x = 0; x < IMWD; x++){
            board[y][x] = 0;
            newBoard[y][x] = 0;
        }
    }

    //populate input board
    for (int y = 0; y < WORKERHT; y++){
        for (int x = 0; x < IMWD; x++){
            cWorker :> currentCell;
            board[y][x] = currentCell;
            cWorker <: currentCell;
        }
    }

    // get currentCell from distributor, manipulate and insert into newBoard
    for (int y = 0; y < WORKERHT; y++){
        for (int x = 0; x < IMWD; x++){
            aliveNeighbours = countNeighbours(board, y, x);
            newBoard[y][x] = aliveNeighbours;     //newBoard contains number of alive neighbours for each cell
        }
    }

    //use newBoard full of neighbourCounts to convert into updated cell status
    for (int y = 0; y < WORKERHT; y++){
        for (int x = 0; x < IMWD; x++){
            cWorker :> currentCell;
            currentCell = board[y][x];
            updatedCell = aliveOrDead(newBoard[y][x], currentCell);
            newBoard[y][x] = updatedCell;
            cWorker <: updatedCell;
        }
    }
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel cIn to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend cIn, chanend cButton2, chanend toVisualiser)
{
  int res;
  uchar line[ IMWD ];
  // Start export on press of button 2
  cButton2 :> int value;
  // send 1 to export to turn on blue LED
  toVisualiser <: 1;


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
  // send 0 back to export to turn off blue LED
  toVisualiser <: 0;
  // complete while loop in buttonListener
  cButton2 <: 1;
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

chan cInIO, cOutIO, cControl, cLEDs;    //extend your channel definitions here
chan cWorker[2], cButton[2];
chan cDistributorToVisualiser, cDataOutToVisualiser;

par {
    on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);  //server thread providing orientation data
    on tile[0]: orientation(i2c[0],cControl);        //client thread reading orientation data
    on tile[1]: DataInStream(infname, cInIO);          //thread to read in a PGM image
    on tile[1]: DataOutStream(outfname, cOutIO, cButton[1], cDataOutToVisualiser);       //thread to write out a PGM image
    on tile[1]: distributor(cInIO, cOutIO, cControl, cButton[0], cDistributorToVisualiser, cWorker[0], cWorker[1]);  //thread to coordinate work on image
    on tile[1]: worker(0, cWorker[0]);
    on tile[1]: worker(1, cWorker[1]);
    on tile[0]: buttonListener(buttons, cButton[0], cButton[1]);
    on tile[0]: showLEDs(leds, cLEDs);
    on tile[0]: visualiser(cLEDs, cDistributorToVisualiser, cDataOutToVisualiser);
  }

  return 0;
}
